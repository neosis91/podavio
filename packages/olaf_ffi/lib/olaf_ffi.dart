import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Olaf's sample rate. Source audio is resampled to this rate.
const olafSampleRate = 16000;

/// Olaf's hop, in samples at [olafSampleRate]. One frame is 8 ms.
const olafStepSamples = 128;

const olafStepMs = 8;

/// FFT size used by Olaf's default configuration.
const olafBlockSize = 1024;

/// One landmark hash and the time of its first event point.
class OlafLandmark {
  const OlafLandmark({required this.hash, required this.t1});

  final int hash;

  /// Olaf frame index. Wall time is [timeMs].
  final int t1;

  int get timeMs => t1 * olafStepMs;
}

final class _OlafPrint extends Struct {
  @Uint64()
  external int hash;

  @Uint32()
  external int t1;
}

typedef _NewNative = Pointer<Void> Function(Int32 pairs);
typedef _NewDart = Pointer<Void> Function(int pairs);
typedef _FreeNative = Void Function(Pointer<Void> extractor);
typedef _FreeDart = void Function(Pointer<Void> extractor);
typedef _LimitsNative = Void Function(
  Pointer<Void> extractor,
  Int32 maxMs,
  Int32 keepModulus,
);
typedef _LimitsDart = void Function(
  Pointer<Void> extractor,
  int maxMs,
  int keepModulus,
);
typedef _PushNative = Int32 Function(
  Pointer<Void> extractor,
  Pointer<Int16> samples,
  Int32 count,
  Int32 fromRate,
);
typedef _PushDart = int Function(
  Pointer<Void> extractor,
  Pointer<Int16> samples,
  int count,
  int fromRate,
);
typedef _FinishNative = Int32 Function(Pointer<Void> extractor);
typedef _FinishDart = int Function(Pointer<Void> extractor);
typedef _CountNative = Int32 Function(Pointer<Void> extractor);
typedef _CountDart = int Function(Pointer<Void> extractor);
typedef _CopyNative = Void Function(
  Pointer<Void> extractor,
  Pointer<_OlafPrint> out,
  Int32 count,
);
typedef _CopyDart = void Function(
  Pointer<Void> extractor,
  Pointer<_OlafPrint> out,
  int count,
);

class _Bindings {
  _Bindings(DynamicLibrary library)
    : create = library.lookupFunction<_NewNative, _NewDart>(
        'olaf_extractor_new',
      ),
      destroy = library.lookupFunction<_FreeNative, _FreeDart>(
        'olaf_extractor_free',
      ),
      limits = library.lookupFunction<_LimitsNative, _LimitsDart>(
        'olaf_extractor_set_limits',
      ),
      push = library.lookupFunction<_PushNative, _PushDart>(
        'olaf_extractor_push',
      ),
      finish = library.lookupFunction<_FinishNative, _FinishDart>(
        'olaf_extractor_finish',
      ),
      count = library.lookupFunction<_CountNative, _CountDart>(
        'olaf_extractor_count',
      ),
      copy = library.lookupFunction<_CopyNative, _CopyDart>(
        'olaf_extractor_copy',
      );

  final _NewDart create;
  final _FreeDart destroy;
  final _LimitsDart limits;
  final _PushDart push;
  final _FinishDart finish;
  final _CountDart count;
  final _CopyDart copy;
}

_Bindings? _bindings;

/// Opens the native library. Null when this platform has not built it
/// (a unit test before [ensureOlafLibrary], for example).
_Bindings? _tryBindings() {
  final cached = _bindings;
  if (cached != null) return cached;
  final library = _openLibrary();
  if (library == null) return null;
  return _bindings = _Bindings(library);
}

DynamicLibrary? _openLibrary() {
  final override = Platform.environment['OLAF_FFI_LIB'];
  final names = <String>[
    if (override != null && override.isNotEmpty) override,
    if (Platform.isLinux || Platform.isAndroid) 'libolaf_ffi.so',
    if (Platform.isMacOS || Platform.isIOS) 'olaf_ffi.framework/olaf_ffi',
    if (Platform.isWindows) 'olaf_ffi.dll',
    if (Platform.isLinux) 'packages/olaf_ffi/build/linux/libolaf_ffi.so',
  ];
  for (final name in names) {
    try {
      return DynamicLibrary.open(name);
    } catch (_) {
      continue;
    }
  }
  if (Platform.isMacOS || Platform.isIOS) {
    try {
      return DynamicLibrary.process();
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Compiles the Linux shared library when `flutter test` did not.
///
/// The application builds the same sources with CMake or the podspec.
/// Returns false when gcc is missing or the build fails.
Future<bool> ensureOlafLibrary() async {
  if (!Platform.isLinux) return _tryBindings() != null;
  if (_tryBindings() != null) return true;
  final script = File('packages/olaf_ffi/tool/build_linux.sh');
  if (!script.existsSync()) return false;
  final result = await Process.run('sh', [script.path]);
  if (result.exitCode != 0) return false;
  _bindings = null;
  return _tryBindings() != null;
}

/// Fingerprints mono 16-bit PCM with Olaf.
///
/// Call this from the analysis isolate. The native extractor keeps only
/// one FFT block and the landmark list for the first three minutes.
/// [eventPointsPerFingerprint] is 2 for a re-encode, or 3 for a clean file.
/// Null when the native library is absent.
List<OlafLandmark>? fingerprintPcm(
  Uint8List pcm, {
  required int sampleRate,
  int eventPointsPerFingerprint = 2,
}) {
  final bindings = _tryBindings();
  if (bindings == null || sampleRate <= 0) return null;
  final extractor = bindings.create(eventPointsPerFingerprint);
  if (extractor == nullptr) return null;
  try {
    final samples = pcm.lengthInBytes ~/ 2;
    if (samples <= 0) {
      bindings.finish(extractor);
      return const [];
    }
    final pointer = calloc<Int16>(samples);
    try {
      final bytes = pointer.cast<Uint8>();
      bytes.asTypedList(samples * 2).setAll(0, pcm);
      if (bindings.push(extractor, pointer, samples, sampleRate) != 0) {
        return null;
      }
    } finally {
      calloc.free(pointer);
    }
    final count = bindings.finish(extractor);
    if (count <= 0) return const [];
    final out = calloc<_OlafPrint>(count);
    try {
      bindings.copy(extractor, out, count);
      return [
        for (var i = 0; i < count; i++)
          OlafLandmark(hash: out[i].hash, t1: out[i].t1),
      ];
    } finally {
      calloc.free(out);
    }
  } finally {
    bindings.destroy(extractor);
  }
}

/// Reads a PCM file in pieces so the whole episode is not a second copy.
List<OlafLandmark>? fingerprintPcmFile(
  String path, {
  required int sampleRate,
  int maxMs = 180000,
  int keepModulus = 1,
  int eventPointsPerFingerprint = 2,
}) {
  final bindings = _tryBindings();
  if (bindings == null || sampleRate <= 0) return null;
  final extractor = bindings.create(eventPointsPerFingerprint);
  if (extractor == nullptr) return null;
  bindings.limits(extractor, maxMs, keepModulus);
  final file = File(path).openSync();
  final raw = Uint8List(8192 * 2);
  final pointer = calloc<Int16>(8192);
  final maxSamples = maxMs <= 0 ? 1 << 62 : maxMs * sampleRate ~/ 1000;
  var seen = 0;
  try {
    while (seen < maxSamples) {
      final read = file.readIntoSync(raw);
      if (read < 2) break;
      var samples = read ~/ 2;
      if (seen + samples > maxSamples) samples = maxSamples - seen;
      pointer
          .cast<Uint8>()
          .asTypedList(samples * 2)
          .setAll(0, raw.sublist(0, samples * 2));
      if (bindings.push(extractor, pointer, samples, sampleRate) != 0) {
        return null;
      }
      seen += samples;
      if (samples < read ~/ 2) break;
    }
    final count = bindings.finish(extractor);
    if (count <= 0) return const [];
    final out = calloc<_OlafPrint>(count);
    try {
      bindings.copy(extractor, out, count);
      return [
        for (var i = 0; i < count; i++)
          OlafLandmark(hash: out[i].hash, t1: out[i].t1),
      ];
    } finally {
      calloc.free(out);
    }
  } finally {
    calloc.free(pointer);
    file.closeSync();
    bindings.destroy(extractor);
  }
}
