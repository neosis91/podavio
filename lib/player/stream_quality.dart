import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../data/http_auth.dart';

/// « 154 kbps · 48 kHz » : les chiffres du flux en cours, comme la ligne
/// qualité du grand lecteur SimpMusic. Un chiffre absent est omis. `null`
/// quand aucun des deux n’est connu.
String? streamQualityLabel({int? bitrateBps, int? sampleRateHz}) {
  final parts = <String>[];
  if (bitrateBps != null && bitrateBps > 0) {
    parts.add('${(bitrateBps / 1000).round()} kbps');
  }
  if (sampleRateHz != null && sampleRateHz > 0) {
    parts.add(_khzLabel(sampleRateHz));
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// 48000 → « 48 kHz », 44100 → « 44.1 kHz ».
String _khzLabel(int sampleRateHz) {
  final tenths = (sampleRateHz + 50) ~/ 100;
  if (tenths % 10 == 0) return '${tenths ~/ 10} kHz';
  return '${tenths ~/ 10}.${tenths % 10} kHz';
}

/// Lit l’en-tête du flux (fichier local ou début HTTP) et en tire le libellé.
Future<String?> loadStreamQualityLabel({
  required Uri uri,
  Map<String, String>? headers,
  Duration? duration,
}) async {
  final prefix = await _readPrefix(uri, headers);
  if (prefix == null) return null;
  final parsed = _qualityFromAudioPrefix(
    prefix.bytes,
    contentLength: prefix.contentLength,
    duration: duration,
  );
  return streamQualityLabel(
    bitrateBps: parsed.bitrateBps,
    sampleRateHz: parsed.sampleRateHz,
  );
}

class _AudioQuality {
  const _AudioQuality({this.bitrateBps, this.sampleRateHz});

  final int? bitrateBps;
  final int? sampleRateHz;
}

/// Même libellé, à partir des premiers octets du fichier.
String? streamQualityLabelFromPrefix(
  Uint8List bytes, {
  int? contentLength,
  Duration? duration,
}) {
  final parsed = _qualityFromAudioPrefix(
    bytes,
    contentLength: contentLength,
    duration: duration,
  );
  return streamQualityLabel(
    bitrateBps: parsed.bitrateBps,
    sampleRateHz: parsed.sampleRateHz,
  );
}

/// Débit et fréquence lus dans les premiers octets. Le débit moyen
/// (taille / durée) ne sert que si l’en-tête n’en donne pas, comme un MP3 VBR.
_AudioQuality _qualityFromAudioPrefix(
  Uint8List bytes, {
  int? contentLength,
  Duration? duration,
}) {
  final head = bytes.length < 32 ? bytes : Uint8List.sublistView(bytes, 0, 32);
  final looksLikeMp4 = _indexOf(head, const [0x66, 0x74, 0x79, 0x70]) >= 0;
  final mp4 = looksLikeMp4 ? _mp4Quality(bytes) : null;
  final mp3 = mp4 == null ? _mp3Quality(bytes) : null;
  final opusRate = mp3 == null && mp4 == null ? _opusSampleRate(bytes) : null;
  final header = mp3 ?? mp4;
  var bitrate = header?.bitrateBps;
  final sampleRate = header?.sampleRateHz ?? opusRate;
  if (bitrate == null || bitrate <= 0) {
    bitrate = _averageBitrate(contentLength, duration);
  }
  return _AudioQuality(
    bitrateBps: bitrate != null && bitrate > 0 ? bitrate : null,
    sampleRateHz: sampleRate != null && sampleRate > 0 ? sampleRate : null,
  );
}

int? _averageBitrate(int? contentLength, Duration? duration) {
  if (contentLength == null || contentLength <= 0) return null;
  final milliseconds = duration?.inMilliseconds ?? 0;
  if (milliseconds <= 0) return null;
  return (contentLength * 8 * 1000 / milliseconds).round();
}

const _prefixLength = 262144;

class _Prefix {
  const _Prefix(this.bytes, this.contentLength);

  final Uint8List bytes;
  final int? contentLength;
}

Future<_Prefix?> _readPrefix(Uri uri, Map<String, String>? headers) async {
  if (uri.scheme == 'file') {
    final file = File(uri.toFilePath());
    if (!file.existsSync()) return null;
    final length = await file.length();
    final opened = await file.open();
    try {
      final count = length < _prefixLength ? length : _prefixLength;
      final bytes = await opened.read(count);
      return _Prefix(bytes, length);
    } finally {
      await opened.close();
    }
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;

  final client = http.Client();
  try {
    final request = http.Request('GET', uri);
    request.headers.addAll(headers ?? const {});
    request.headers['Range'] = 'bytes=0-${_prefixLength - 1}';
    final response = await sendKeepingAuthorization(
      client,
      request,
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200 && response.statusCode != 206) {
      return null;
    }
    final bytes = await _take(response.stream, _prefixLength);
    return _Prefix(bytes, _declaredLength(response));
  } on TimeoutException {
    return null;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

int? _declaredLength(http.StreamedResponse response) {
  final range = response.headers['content-range'];
  if (range != null) {
    final slash = range.lastIndexOf('/');
    if (slash >= 0) {
      final total = int.tryParse(range.substring(slash + 1).trim());
      if (total != null && total > 0) return total;
    }
  }
  if (response.statusCode == 200) {
    return int.tryParse(response.headers['content-length'] ?? '');
  }
  return null;
}

Future<Uint8List> _take(Stream<List<int>> stream, int max) async {
  final builder = BytesBuilder(copy: false);
  try {
    await for (final chunk in stream) {
      builder.add(chunk);
      if (builder.length >= max) break;
    }
  } catch (_) {
    // Le serveur coupe quand on s’arrête avant la fin du fichier.
  }
  final data = builder.takeBytes();
  if (data.length <= max) return data;
  return Uint8List.sublistView(data, 0, max);
}

_AudioQuality? _mp3Quality(Uint8List bytes) {
  var offset = 0;
  if (bytes.length >= 10 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33) {
    final size = _synchsafe(bytes, 6);
    offset = 10 + size;
    if ((bytes[5] & 0x10) != 0) offset += 10;
  }
  while (offset + 3 < bytes.length) {
    if (bytes[offset] != 0xFF || (bytes[offset + 1] & 0xE0) != 0xE0) {
      offset++;
      continue;
    }
    final version = (bytes[offset + 1] >> 3) & 0x3;
    final layer = (bytes[offset + 1] >> 1) & 0x3;
    final bitrateIndex = (bytes[offset + 2] >> 4) & 0xF;
    final sampleIndex = (bytes[offset + 2] >> 2) & 0x3;
    if (version == 1 || layer == 0 || bitrateIndex == 0 || bitrateIndex == 15) {
      offset++;
      continue;
    }
    if (sampleIndex == 3) {
      offset++;
      continue;
    }
    final kbps = _mp3BitrateKbps(version, layer, bitrateIndex);
    final sampleRate = _mp3SampleRate(version, sampleIndex);
    if (kbps == null || sampleRate == null) {
      offset++;
      continue;
    }
    final channelMode = (bytes[offset + 3] >> 6) & 0x3;
    final vbr = _hasXing(bytes, offset, version, channelMode);
    return _AudioQuality(
      bitrateBps: vbr ? null : kbps * 1000,
      sampleRateHz: sampleRate,
    );
  }
  return null;
}

int _synchsafe(Uint8List bytes, int offset) {
  return (bytes[offset] << 21) |
      (bytes[offset + 1] << 14) |
      (bytes[offset + 2] << 7) |
      bytes[offset + 3];
}

bool _hasXing(Uint8List bytes, int frame, int version, int channelMode) {
  final sideInfo = version == 3
      ? (channelMode == 3 ? 17 : 32)
      : (channelMode == 3 ? 9 : 17);
  final tag = frame + 4 + sideInfo;
  if (tag + 4 > bytes.length) return false;
  final mark = String.fromCharCodes(bytes.sublist(tag, tag + 4));
  return mark == 'Xing' || mark == 'Info';
}

const _mpeg1Layer3 = <int>[
  0,
  32,
  40,
  48,
  56,
  64,
  80,
  96,
  112,
  128,
  160,
  192,
  224,
  256,
  320,
  0,
];
const _mpeg2Layer3 = <int>[
  0,
  8,
  16,
  24,
  32,
  40,
  48,
  56,
  64,
  80,
  96,
  112,
  128,
  144,
  160,
  0,
];
const _mpeg1Layer1 = <int>[
  0,
  32,
  64,
  96,
  128,
  160,
  192,
  224,
  256,
  288,
  320,
  352,
  384,
  416,
  448,
  0,
];
const _mpeg1Layer2 = <int>[
  0,
  32,
  48,
  56,
  64,
  80,
  96,
  112,
  128,
  160,
  192,
  224,
  256,
  320,
  384,
  0,
];

int? _mp3BitrateKbps(int version, int layer, int index) {
  final table = switch (layer) {
    3 => version == 3 ? _mpeg1Layer1 : _mpeg2Layer3,
    2 => version == 3 ? _mpeg1Layer2 : _mpeg2Layer3,
    1 => version == 3 ? _mpeg1Layer3 : _mpeg2Layer3,
    _ => null,
  };
  if (table == null || index < 0 || index >= table.length) return null;
  final value = table[index];
  return value == 0 ? null : value;
}

int? _mp3SampleRate(int version, int index) {
  const rates = <int, List<int>>{
    3: [44100, 48000, 32000],
    2: [22050, 24000, 16000],
    0: [11025, 12000, 8000],
  };
  final table = rates[version];
  if (table == null || index < 0 || index >= table.length) return null;
  return table[index];
}

_AudioQuality? _mp4Quality(Uint8List bytes) {
  final marker = [0x6D, 0x70, 0x34, 0x61]; // mp4a
  final at = _indexOf(bytes, marker);
  if (at < 0 || at + 32 > bytes.length) return null;
  final data = ByteData.sublistView(bytes);
  final sampleRate = data.getUint32(at + 28) >> 16;
  final esds = [0x65, 0x73, 0x64, 0x73];
  final esdsAt = _indexOf(bytes, esds);
  final bitrate = esdsAt < 0 ? null : _esdsAverageBitrate(bytes, esdsAt + 4);
  if (sampleRate <= 0 && (bitrate == null || bitrate <= 0)) return null;
  return _AudioQuality(
    bitrateBps: bitrate != null && bitrate > 0 ? bitrate : null,
    sampleRateHz: sampleRate > 0 ? sampleRate : null,
  );
}

int? _esdsAverageBitrate(Uint8List bytes, int start) {
  final limit = start + 64 < bytes.length ? start + 64 : bytes.length - 5;
  for (var i = start; i < limit; i++) {
    if (bytes[i] != 0x04) continue;
    var cursor = i + 1;
    if (cursor >= bytes.length) return null;
    if (bytes[cursor] & 0x80 != 0) {
      while (cursor < bytes.length && bytes[cursor] & 0x80 != 0) {
        cursor++;
      }
      cursor++;
    } else {
      cursor++;
    }
    if (cursor + 13 > bytes.length) return null;
    final bitrate = ByteData.sublistView(bytes)
        .getUint32(cursor + 1 + 1 + 3 + 4);
    if (bitrate > 0 && bitrate < 2000000) return bitrate;
  }
  return null;
}

int? _opusSampleRate(Uint8List bytes) {
  final marker = [0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64];
  final at = _indexOf(bytes, marker);
  if (at < 0 || at + 16 > bytes.length) return null;
  final rate = ByteData.sublistView(bytes).getUint32(at + 12, Endian.little);
  return rate > 0 ? rate : null;
}

int _indexOf(Uint8List bytes, List<int> needle) {
  final last = bytes.length - needle.length;
  for (var i = 0; i <= last; i++) {
    var found = true;
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        found = false;
        break;
      }
    }
    if (found) return i;
  }
  return -1;
}
