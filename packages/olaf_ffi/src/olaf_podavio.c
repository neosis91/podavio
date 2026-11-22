/* Podavio binding for Olaf.
 *
 * Olaf: Overly Lightweight Acoustic Fingerprinting
 * Copyright (C) 2019-2025 Joren Six
 * https://github.com/JorenSix/Olaf
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Streaming wrapper around Olaf's extractor. The FFT, the perceptual
 * max filter, the event-point pairing and the hash are Olaf's.
 */

#include "olaf_podavio.h"

#include <stdlib.h>
#include <string.h>

#include "olaf_config.h"
#include "olaf_ep_extractor.h"
#include "olaf_fft.h"
#include "olaf_fp_extractor.h"

enum {
  kBlock = 1024,
  kStep = 128,
  kOverlap = kBlock - kStep,
  kSlice = 4096,
  kMaxPrints = 100000,
  /* First three minutes at 16 kHz. Same window as the short-sound search. */
  kMaxOutputSamples = 180 * 16000
};

struct OlafExtractor {
  Olaf_Config *config;
  Olaf_FFT *fft;
  Olaf_EP_Extractor *events;
  Olaf_FP_Extractor *fingerprints;
  float block[kBlock];
  float spectrum[kBlock];
  float step[kStep];
  int step_fill;
  int primed;
  int block_index;
  int from_rate;
  int64_t produced;
  int64_t src_base;
  float prev;
  int have_prev;
  int finished;
  struct extracted_event_points *last_points;
  float *scratch;
  int scratch_cap;
  OlafPrint *prints;
  int print_count;
  int print_cap;
};

static void store_prints(OlafExtractor *ex, struct extracted_fingerprints *fps) {
  if (fps == NULL) return;
  for (size_t i = 0; i < fps->fingerprintIndex; i++) {
    struct fingerprint fp = fps->fingerprints[i];
    if (fp.timeIndex1 < 0) continue;
    if (ex->print_count >= kMaxPrints) return;
    if (ex->print_count == ex->print_cap) {
      int cap = ex->print_cap == 0 ? 256 : ex->print_cap * 2;
      if (cap > kMaxPrints) cap = kMaxPrints;
      OlafPrint *grown = (OlafPrint *)realloc(ex->prints, (size_t)cap * sizeof(OlafPrint));
      if (grown == NULL) return;
      ex->prints = grown;
      ex->print_cap = cap;
    }
    ex->prints[ex->print_count].hash = olaf_fp_extractor_hash(fp);
    ex->prints[ex->print_count].t1 = (uint32_t)fp.timeIndex1;
    ex->print_count++;
  }
  fps->fingerprintIndex = 0;
}

static void process_frame(OlafExtractor *ex) {
  memcpy(ex->spectrum, ex->block, sizeof(ex->block));
  olaf_fft_forward(ex->fft, ex->spectrum);
  ex->last_points =
      olaf_ep_extractor_extract(ex->events, ex->spectrum, ex->block_index);
  if (ex->last_points != NULL &&
      ex->last_points->eventPointIndex > ex->config->eventPointThreshold) {
    struct extracted_fingerprints *fps = olaf_fp_extractor_extract(
        ex->fingerprints, ex->last_points, ex->block_index);
    store_prints(ex, fps);
  }
  ex->block_index++;
}

static void consume_step(OlafExtractor *ex) {
  memmove(ex->block, ex->block + kStep, kOverlap * sizeof(float));
  memcpy(ex->block + kOverlap, ex->step, kStep * sizeof(float));
  ex->step_fill = 0;
  /* Olaf's reader discards the first hop: it only primes the overlap. */
  if (!ex->primed) {
    ex->primed = 1;
    return;
  }
  process_frame(ex);
}

static void emit_sample(OlafExtractor *ex, float sample) {
  if (ex->produced >= kMaxOutputSamples) return;
  ex->step[ex->step_fill++] = sample;
  ex->produced++;
  if (ex->step_fill == kStep) consume_step(ex);
}

static void feed_slice(OlafExtractor *ex, const int16_t *samples, int count) {
  if (count > ex->scratch_cap) {
    float *grown = (float *)realloc(ex->scratch, (size_t)count * sizeof(float));
    if (grown == NULL) return;
    ex->scratch = grown;
    ex->scratch_cap = count;
  }
  for (int i = 0; i < count; i++) {
    ex->scratch[i] = (float)samples[i] / 32768.0f;
  }
  const double step = (double)ex->from_rate / 16000.0;
  const int64_t src_base = ex->src_base;
  while (ex->produced < kMaxOutputSamples) {
    const double pos = (double)ex->produced * step;
    const int64_t i0 = (int64_t)pos;
    if (i0 + 1 >= src_base + count) break;
    float left;
    float right;
    if (i0 < src_base) {
      left = ex->prev;
      right = ex->scratch[0];
    } else {
      const int64_t local = i0 - src_base;
      left = ex->scratch[local];
      right = ex->scratch[local + 1];
    }
    const float frac = (float)(pos - (double)i0);
    emit_sample(ex, left + (right - left) * frac);
  }
  if (count > 0) {
    ex->prev = ex->scratch[count - 1];
    ex->have_prev = 1;
  }
  ex->src_base += count;
}

OlafExtractor *olaf_extractor_new(int event_points_per_fingerprint) {
  OlafExtractor *ex = (OlafExtractor *)calloc(1, sizeof(OlafExtractor));
  if (ex == NULL) return NULL;
  ex->config = olaf_config_default();
  if (ex->config == NULL) {
    free(ex);
    return NULL;
  }
  /* Pairs survive a re-encode. Triplets stay available for a clean file.
   * Sample rate, FFT size, hop and the perceptual max filter stay Olaf's. */
  if (event_points_per_fingerprint == 3) {
    ex->config->numberOfEPsPerFP = 3;
  } else {
    ex->config->numberOfEPsPerFP = 2;
  }
  /* The batch cap only drops fingerprints. Keep the ones Olaf would emit. */
  ex->config->maxFingerprints = 4096;
  ex->config->verbose = false;
  ex->fft = olaf_fft_new(ex->config);
  ex->events = olaf_ep_extractor_new(ex->config);
  ex->fingerprints = olaf_fp_extractor_new(ex->config);
  if (ex->fft == NULL || ex->events == NULL || ex->fingerprints == NULL) {
    olaf_extractor_free(ex);
    return NULL;
  }
  return ex;
}

void olaf_extractor_free(OlafExtractor *extractor) {
  if (extractor == NULL) return;
  if (extractor->fingerprints != NULL) {
    olaf_fp_extractor_destroy(extractor->fingerprints);
  }
  if (extractor->events != NULL) olaf_ep_extractor_destroy(extractor->events);
  if (extractor->fft != NULL) olaf_fft_destroy(extractor->fft);
  if (extractor->config != NULL) olaf_config_destroy(extractor->config);
  free(extractor->scratch);
  free(extractor->prints);
  free(extractor);
}

int olaf_extractor_push(
    OlafExtractor *extractor,
    const int16_t *samples,
    int count,
    int from_rate) {
  if (extractor == NULL || extractor->finished) return -1;
  if (count <= 0 || samples == NULL) return 0;
  if (extractor->from_rate == 0) {
    if (from_rate <= 0) return -1;
    extractor->from_rate = from_rate;
  }
  for (int offset = 0; offset < count; offset += kSlice) {
    int n = count - offset;
    if (n > kSlice) n = kSlice;
    feed_slice(extractor, samples + offset, n);
    if (extractor->produced >= kMaxOutputSamples) break;
  }
  return 0;
}

int olaf_extractor_finish(OlafExtractor *extractor) {
  if (extractor == NULL) return -1;
  if (extractor->finished) return extractor->print_count;
  extractor->finished = 1;
  /* A short final hop is not transformed. Remaining event points are
   * combined once, as Olaf's stream processor does after the read loop. */
  struct extracted_event_points *points = extractor->last_points;
  if (points != NULL && points->eventPointIndex > 0) {
    struct extracted_fingerprints *fps = olaf_fp_extractor_extract(
        extractor->fingerprints, points, extractor->block_index);
    store_prints(extractor, fps);
  }
  return extractor->print_count;
}

int olaf_extractor_count(const OlafExtractor *extractor) {
  if (extractor == NULL) return 0;
  return extractor->print_count;
}

void olaf_extractor_copy(
    const OlafExtractor *extractor, OlafPrint *out, int count) {
  if (extractor == NULL || out == NULL || count <= 0) return;
  int n = count < extractor->print_count ? count : extractor->print_count;
  memcpy(out, extractor->prints, (size_t)n * sizeof(OlafPrint));
}
