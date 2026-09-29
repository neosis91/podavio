#!/bin/sh
# Installe Flutter depuis github.com/flutter/flutter (tag/branche FLUTTER_VERSION).
set -eu

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_HOME="${FLUTTER_HOME:-/opt/flutter-podavio}"

if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
  git clone --branch "${FLUTTER_VERSION}" --depth 1 \
    https://github.com/flutter/flutter.git "${FLUTTER_HOME}"
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"
flutter --version
flutter config --no-analytics
flutter pub get
