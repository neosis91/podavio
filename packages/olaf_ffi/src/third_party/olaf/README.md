# Olaf

Vendored from [Joren Six, Olaf](https://github.com/JorenSix/Olaf)
(Overly Lightweight Acoustic Fingerprinting), copyright 2019-2025 Joren Six.

The sources in this directory are AGPL-3.0-or-later. See `LICENSE`.
Podavio is GPL-3.0-or-later; the AGPL and the GPL version 3 are
compatible, and this copy stays under the AGPL.

`pffft.c` and `pffft.h` are Julien Pommier's PFFFT, based on FFTPACK,
under the FFTPACK license in the file header.

`olaf_max_filter_perceptual_van_herk.c` includes Daniel Lemire's
van Herk / Gil-Werman running maximum, noted in that file as LGPL.
One change was made for MSVC, which has no variable-length arrays:
the width-103 scratch arrays are fixed at 128 elements. The filter
values are the same.

The fingerprint itself is Olaf's default: 16 kHz, 1024-point real FFT,
128-sample hop, perceptual max filter, event-point pairs or triplets,
and the 64-bit hash in `olaf_fp_extractor_hash`.
