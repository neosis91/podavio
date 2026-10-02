import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'models.dart';
import 'providers.dart';

enum FeedRefreshPhase { idle, running, completed }

class FeedRefreshFailure {
  const FeedRefreshFailure({
    required this.title,
    required this.feedUrl,
    required this.message,
  });

  final String title;
  final String feedUrl;
  final String message;
}

class FeedRefreshState {
  const FeedRefreshState({
    this.phase = FeedRefreshPhase.idle,
    this.done = 0,
    this.total = 0,
    this.failures = const [],
  });

  final FeedRefreshPhase phase;
  final int done;
  final int total;
  final List<FeedRefreshFailure> failures;

  bool get isRunning => phase == FeedRefreshPhase.running;
  bool get isVisible =>
      phase == FeedRefreshPhase.running || phase == FeedRefreshPhase.completed;

  int get failed => failures.length;
  int get refreshed => (done - failed).clamp(0, total);

  double? get progress => total == 0 ? null : done / total;
}

final feedRefreshProvider =
    NotifierProvider<FeedRefreshNotifier, FeedRefreshState>(
      FeedRefreshNotifier.new,
    );

class FeedRefreshNotifier extends Notifier<FeedRefreshState> {
  @override
  FeedRefreshState build() => const FeedRefreshState();

  /// Lance l'actualisation en arrière-plan.
  /// Retourne false si déjà en cours ou s'il n'y a aucun abonnement.
  Future<bool> start() async {
    if (state.isRunning) return false;
    final podcasts = (await ref.read(databaseProvider).listPodcasts())
        .where((podcast) => podcast.keepUpdated)
        .toList();
    if (podcasts.isEmpty) return false;
    if (state.isRunning) return false;
    state = FeedRefreshState(
      phase: FeedRefreshPhase.running,
      total: podcasts.length,
    );
    _run(podcasts);
    return true;
  }

  void dismiss() {
    if (state.isRunning) return;
    state = const FeedRefreshState();
  }

  Future<void> _run(List<Podcast> podcasts) async {
    final titles = {
      for (final podcast in podcasts) podcast.feedUrl: podcast.title,
    };
    final report = await ref
        .read(feedServiceProvider)
        .refreshAll(
          onProgress: (done, total, failures) {
            if (!state.isRunning) return;
            state = FeedRefreshState(
              phase: FeedRefreshPhase.running,
              done: done,
              total: total,
              failures: _mapFailures(failures, titles),
            );
          },
        );
    state = FeedRefreshState(
      phase: FeedRefreshPhase.completed,
      done: report.total,
      total: report.total,
      failures: _mapFailures(report.failures, titles),
    );
  }

  List<FeedRefreshFailure> _mapFailures(
    List<SubscribeFailure> failures,
    Map<String, String> titles,
  ) {
    return [
      for (final failure in failures)
        FeedRefreshFailure(
          title: titles[failure.feedUrl] ?? failure.feedUrl,
          feedUrl: failure.feedUrl,
          message: failure.message,
        ),
    ];
  }
}
