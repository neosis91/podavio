import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'opml.dart';
import 'providers.dart';

enum OpmlImportPhase { idle, running, completed }

class OpmlImportFailure {
  const OpmlImportFailure({
    required this.title,
    required this.feedUrl,
    required this.message,
  });

  final String title;
  final String feedUrl;
  final String message;
}

class OpmlImportState {
  const OpmlImportState({
    this.phase = OpmlImportPhase.idle,
    this.done = 0,
    this.total = 0,
    this.failures = const [],
  });

  final OpmlImportPhase phase;
  final int done;
  final int total;
  final List<OpmlImportFailure> failures;

  bool get isRunning => phase == OpmlImportPhase.running;
  bool get isVisible =>
      phase == OpmlImportPhase.running || phase == OpmlImportPhase.completed;

  int get failed => failures.length;
  int get imported => (done - failed).clamp(0, total);

  double? get progress => total == 0 ? null : done / total;
}

final opmlImportProvider =
    NotifierProvider<OpmlImportNotifier, OpmlImportState>(
      OpmlImportNotifier.new,
    );

class OpmlImportNotifier extends Notifier<OpmlImportState> {
  @override
  OpmlImportState build() => const OpmlImportState();

  /// Lance l'import en arrière-plan. Retourne false si un import tourne déjà.
  bool start(List<OpmlEntry> entries) {
    if (entries.isEmpty || state.isRunning) return false;
    state = OpmlImportState(
      phase: OpmlImportPhase.running,
      total: entries.length,
    );
    _run(entries);
    return true;
  }

  void dismiss() {
    if (state.isRunning) return;
    state = const OpmlImportState();
  }

  Future<void> _run(List<OpmlEntry> entries) async {
    final titles = {for (final entry in entries) entry.feedUrl: entry.title};
    final report = await ref
        .read(feedServiceProvider)
        .subscribeMany(
          [for (final entry in entries) entry.feedUrl],
          onProgress: (done, total, failures) {
            if (!state.isRunning) return;
            state = OpmlImportState(
              phase: OpmlImportPhase.running,
              done: done,
              total: total,
              failures: _mapFailures(failures, titles),
            );
          },
        );
    state = OpmlImportState(
      phase: OpmlImportPhase.completed,
      done: report.total,
      total: report.total,
      failures: _mapFailures(report.failures, titles),
    );
  }

  List<OpmlImportFailure> _mapFailures(
    List<SubscribeFailure> failures,
    Map<String, String> titles,
  ) {
    return [
      for (final failure in failures)
        OpmlImportFailure(
          title: titles[failure.feedUrl] ?? failure.feedUrl,
          feedUrl: failure.feedUrl,
          message: failure.message,
        ),
    ];
  }
}
