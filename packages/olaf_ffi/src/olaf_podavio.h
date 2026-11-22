/* Podavio binding for Olaf.
 *
 * Olaf: Overly Lightweight Acoustic Fingerprinting
 * Copyright (C) 2019-2025 Joren Six
 * https://github.com/JorenSix/Olaf
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * The extraction below calls Olaf's own FFT, perceptual max filter,
 * event points and fingerprint hash. This header is the small FFI
 * surface added for Podavio.
 */

#ifndef OLAF_PODAVIO_H
#define OLAF_PODAVIO_H

#include <stdint.h>

#if defined(_WIN32)
#define OLAF_EXPORT __declspec(dllexport)
#else
#define OLAF_EXPORT __attribute__((visibility("default")))
#endif

typedef struct OlafExtractor OlafExtractor;

/** One landmark hash and the time of its first event point, in Olaf frames. */
typedef struct OlafPrint {
  uint64_t hash;
  uint32_t t1;
} OlafPrint;

/**
 * Create an extractor.
 *
 * [event_points_per_fingerprint] is 2 (Olaf's setting for a re-encoded
 * query) or 3 (Olaf's default for a clean recording). Any other value
 * selects 2. Audio stays at Olaf's 16 kHz, 1024-point FFT and 128-sample
 * hop. At most the first 180 s are fingerprinted.
 */
OLAF_EXPORT OlafExtractor *olaf_extractor_new(int event_points_per_fingerprint);

OLAF_EXPORT void olaf_extractor_free(OlafExtractor *extractor);

/**
 * Push mono 16-bit PCM. [from_rate] is the source sample rate (11025 in
 * Podavio). Samples are resampled to 16 kHz inside the extractor.
 * Returns 0, or -1 if [extractor] is NULL.
 */
OLAF_EXPORT int olaf_extractor_push(
    OlafExtractor *extractor,
    const int16_t *samples,
    int count,
    int from_rate);

/** Flush the last event points. Returns the number of fingerprints. */
OLAF_EXPORT int olaf_extractor_finish(OlafExtractor *extractor);

OLAF_EXPORT int olaf_extractor_count(const OlafExtractor *extractor);

/** Copy min(count, available) fingerprints into [out]. */
OLAF_EXPORT void olaf_extractor_copy(
    const OlafExtractor *extractor,
    OlafPrint *out,
    int count);

#endif
