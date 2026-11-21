import 'package:flutter_test/flutter_test.dart';

/// Même limites que `AudioDecodePlugin.kt` : 8 lectures vides, 200 attentes
/// après la fin d’entrée, 500 si la fin n’est jamais signalée, et un délai.
class _Drain {
  _Drain({required this.deadlineMs});

  final int deadlineMs;
  var idle = 0;
  var emptyReads = 0;
  var inputDone = false;
  var outputDone = false;
  var failed = false;
  var elapsedMs = 0;

  /// Un tour : entrée puis sortie. `input` vaut -1 (fin), 0 (vide),
  /// ou une taille. `outputEos` est le drapeau de fin du codec.
  void step({int? input, bool output = false, bool outputEos = false}) {
    elapsedMs += 10;
    if (elapsedMs >= deadlineMs) {
      failed = true;
      outputDone = true;
      return;
    }
    var progressed = false;
    if (!inputDone && input != null) {
      if (input == 0) emptyReads += 1;
      if (input > 0) emptyReads = 0;
      if (input < 0 || emptyReads >= 8) {
        inputDone = true;
      }
      progressed = true;
    }
    if (output || outputEos) {
      progressed = true;
      if (outputEos) outputDone = true;
    }
    if (progressed) {
      idle = 0;
    } else {
      idle += 1;
      if (inputDone && idle > 200) outputDone = true;
      if (!inputDone && idle > 500) {
        failed = true;
        outputDone = true;
      }
    }
  }
}

void main() {
  test('end of stream that never arrives stops after the input is done', () {
    final drain = _Drain(deadlineMs: 60 * 1000);
    drain.step(input: -1);
    var turns = 0;
    while (!drain.outputDone && turns < 10000) {
      drain.step();
      turns++;
    }
    expect(drain.outputDone, isTrue);
    expect(drain.failed, isFalse);
    expect(turns, 201);
  });

  test('try again forever, with no end of input, does not spin', () {
    final drain = _Drain(deadlineMs: 60 * 1000);
    var turns = 0;
    while (!drain.outputDone && turns < 10000) {
      drain.step();
      turns++;
    }
    expect(drain.failed, isTrue);
    expect(turns, 501);
  });

  test('repeated empty samples are treated as the end of the file', () {
    final drain = _Drain(deadlineMs: 60 * 1000);
    for (var i = 0; i < 8; i++) {
      drain.step(input: 0);
    }
    expect(drain.inputDone, isTrue);
    var turns = 0;
    while (!drain.outputDone && turns < 10000) {
      drain.step();
      turns++;
    }
    expect(drain.outputDone, isTrue);
    expect(turns, lessThan(1000));
  });

  test('a deadline stops the loop even when buffers keep arriving', () {
    final drain = _Drain(deadlineMs: 50);
    var turns = 0;
    while (!drain.outputDone && turns < 10000) {
      drain.step(input: 32, output: true);
      turns++;
    }
    expect(drain.failed, isTrue);
    expect(turns, lessThan(20));
  });
}
