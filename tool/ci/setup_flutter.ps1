# Installe Flutter sous Windows (tag/branche FLUTTER_VERSION).
$ErrorActionPreference = "Stop"

$flutterVersion = if ($env:FLUTTER_VERSION) { $env:FLUTTER_VERSION } else { "stable" }
$flutterHome = if ($env:FLUTTER_HOME) { $env:FLUTTER_HOME } else { "C:\flutter-podavio" }

if (-not (Test-Path "$flutterHome\bin\flutter.bat")) {
  git clone --branch $flutterVersion --depth 1 `
    https://github.com/flutter/flutter.git $flutterHome
}

$env:PATH = "$flutterHome\bin;$env:PATH"
flutter --version
flutter config --no-analytics
flutter config --enable-windows-desktop
flutter pub get
