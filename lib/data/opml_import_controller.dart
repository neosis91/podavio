import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'automatic_downloads.dart';
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
  Timer? _dismissTimer;

  @override
  OpmlImportState build() {
    ref.onDispose(() => _dismissTimer?.cancel());
    return const OpmlImportState();
  }

  /// Lance l'import en arrière-plan. Retourne false si un import tourne déjà.
  bool start(List<OpmlEntry> entries) {
    if (entries.isEmpty || state.isRunning) return false;
    _dismissTimer?.cancel();
    state = OpmlImportState(
      phase: OpmlImportPhase.running,
      total: entries.length,
    );
    _run(entries);
    return true;
  }

  void dismiss() {
    if (state.isRunning) return;
    _dismissTimer?.cancel();
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
    _scheduleDismiss();
    if (ref.mounted) unawaited(runAutomaticDownloads(ref));
  }

  /// Un import réussi s’efface tout seul, comme l’ancien bandeau.
  /// Les échecs restent jusqu’à fermeture, pour être lus dans la feuille.
  void _scheduleDismiss() {
    _dismissTimer?.cancel();
    if (state.failures.isNotEmpty || state.isRunning) return;
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      if (!ref.mounted || state.isRunning || state.failures.isNotEmpty) return;
      state = const OpmlImportState();
    });
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
