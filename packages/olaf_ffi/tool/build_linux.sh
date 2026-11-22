#!/bin/sh
# Shared library used by `flutter test` on Linux. The app itself builds
# the same sources through CMake (Linux, Windows, Android) or the podspec.
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/linux
gcc -shared -fPIC -O3 -std=gnu11 -D_GNU_SOURCE -DNDEBUG \
  -fvisibility=hidden \
  -I src -I src/third_party/olaf \
  -o build/linux/libolaf_ffi.so \
  src/olaf_podavio.c \
  src/third_party/olaf/pffft.c \
  src/third_party/olaf/olaf_config.c \
  src/third_party/olaf/olaf_fft.c \
  src/third_party/olaf/olaf_ep_extractor.c \
  src/third_party/olaf/olaf_fp_extractor.c \
  src/third_party/olaf/olaf_max_filter_perceptual_van_herk.c \
  -lm
