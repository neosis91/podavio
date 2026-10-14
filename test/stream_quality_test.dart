import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/player/stream_quality.dart';

void main() {
  test('labels bitrate and sample rate like SimpMusic', () {
    expect(
      streamQualityLabel(bitrateBps: 154000, sampleRateHz: 48000),
      '154 kbps · 48 kHz',
    );
    expect(
      streamQualityLabel(bitrateBps: 128000, sampleRateHz: 44100),
      '128 kbps · 44.1 kHz',
    );
    expect(streamQualityLabel(bitrateBps: 96000), '96 kbps');
    expect(streamQualityLabel(sampleRateHz: 48000), '48 kHz');
    expect(streamQualityLabel(), isNull);
  });

  test('reads an MPEG-1 layer III frame', () {
    // FF FB 90 00 : 128 kbps, 44.1 kHz, stéréo.
    final bytes = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
    expect(streamQualityLabelFromPrefix(bytes), '128 kbps · 44.1 kHz');
  });

  test('uses file size for a VBR frame', () {
    final bytes = Uint8List(64);
    bytes[0] = 0xFF;
    bytes[1] = 0xFB;
    bytes[2] = 0x90;
    bytes[3] = 0x00;
    // Xing après 32 octets d’info latérale (MPEG-1 stéréo).
    bytes.setRange(36, 40, [0x58, 0x69, 0x6E, 0x67]);
    expect(
      streamQualityLabelFromPrefix(
        bytes,
        contentLength: 128000,
        duration: const Duration(seconds: 8),
      ),
      '128 kbps · 44.1 kHz',
    );
  });

  test('reads an mp4a sample rate', () {
    final bytes = Uint8List(64);
    bytes.setRange(4, 8, [0x66, 0x74, 0x79, 0x70]); // ftyp
    bytes.setRange(16, 20, [0x6D, 0x70, 0x34, 0x61]); // mp4a
    final data = ByteData.sublistView(bytes);
    data.setUint32(16 + 28, 48000 << 16);
    expect(streamQualityLabelFromPrefix(bytes), '48 kHz');
  });
}
