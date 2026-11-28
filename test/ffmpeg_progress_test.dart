import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/pcm_decoder.dart';

void main() {
  test('un bloc récent utilise out_time_us, pas out_time_ms', () {
    final reader = FfmpegProgressReader();
    final times = reader.add(
      'bitrate=128.0kbits/s\n'
      'out_time_us=1500000\n'
      'out_time_ms=999\n'
      'out_time=00:00:09.000000\n'
      'progress=continue\n',
    );
    expect(times, [1500000]);
  });

  test('un ancien ffmpeg n’a que out_time_ms, en microsecondes', () {
    final reader = FfmpegProgressReader();
    final times = reader.add('out_time_ms=2500000\nprogress=continue\n');
    expect(times, [2500000]);
  });

  test('les fins de ligne Windows et une ligne coupée sont lues', () {
    final reader = FfmpegProgressReader();
    expect(reader.add('out_time_us=2205'), isEmpty);
    final times = reader.add('000\r\nprogress=continue\r\n');
    expect(times, [2205000]);
    expect(reader.add('out_time=00:00:03.25\r\nprogress=end'), isEmpty);
    expect(reader.flush(), [3250000]);
  });

  test('sans temps numérique, l’horloge sert de repli', () {
    final reader = FfmpegProgressReader();
    final times = reader.add(
      'out_time_us=N/A\n'
      'out_time_ms=N/A\n'
      'out_time=01:02:03.5\n'
      'progress=continue\n',
    );
    expect(times, [((1 * 60 + 2) * 60 + 3) * 1000000 + 500000]);
  });

  test('un bloc sans temps ne signale rien', () {
    final reader = FfmpegProgressReader();
    expect(
      reader.add('out_time=N/A\nprogress=continue\nprogress=end\n'),
      isEmpty,
    );
  });

  test('la durée de l’en-tête, ou son absence', () {
    expect(
      ffmpegHeaderDurationUs(
        'Input #0, mp3, from \'a.mp3\':\n'
        '  Duration: 00:25:12.34, start: 0.000000, bitrate: 128 kb/s\n',
      ),
      (25 * 60 + 12) * 1000000 + 340000,
    );
    expect(ffmpegHeaderDurationUs('Duration: N/A, bitrate: N/A\n'), isNull);
    expect(ffmpegHeaderDurationUs('rien ici'), isNull);
    final split = StringBuffer('  Duration: 00:00:');
    expect(ffmpegHeaderDurationUs(split.toString()), isNull);
    split.write('04.25, start: 0.000000\n');
    expect(ffmpegHeaderDurationUs(split.toString()), 4250000);
  });
}
