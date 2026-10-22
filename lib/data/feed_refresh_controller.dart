import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'app_database.dart';
import 'models.dart';
import 'online_status.dart';
import 'providers.dart';
import 'status_notifications.dart';

enum FeedRefreshPhase { idle, running, completed }

enum FeedRefreshStartResult {
  started,
  alreadyRunning,
  empty,
  throttled,
  mobileData,
}

class FeedRefreshStart {
  const FeedRefreshStart._(this.result, {this.retryAfter});

  const FeedRefreshStart.started() : this._(FeedRefreshStartResult.started);

  const FeedRefreshStart.alreadyRunning()
    : this._(FeedRefreshStartResult.alreadyRunning);

  const FeedRefreshStart.empty() : this._(FeedRefreshStartResult.empty);

  const FeedRefreshStart.throttled(Duration retryAfter)
    : this._(FeedRefreshStartResult.throttled, retryAfter: retryAfter);

  const FeedRefreshStart.mobileData()
    : this._(FeedRefreshStartResult.mobileData);

  final FeedRefreshStartResult result;
  final Duration? retryAfter;

  bool get started => result == FeedRefreshStartResult.started;
}

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
  static const _lastRefreshKey = 'lastFeedRefreshAtMs';

  DateTime _lastProgressUi = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  FeedRefreshState build() => const FeedRefreshState();

  /// Lance l'actualisation en arrière-plan (respecte l’intervalle des réglages).
  Future<FeedRefreshStart> start({bool force = false}) async {
    if (state.isRunning) return const FeedRefreshStart.alreadyRunning();

    if (!ref.read(settingsProvider).allowMobileRefresh) {
      final onMobile = await ref.read(mobileDataProbeProvider)();
      if (onMobile) return const FeedRefreshStart.mobileData();
    }

    if (!force) {
      final throttled = _throttleRemaining();
      if (throttled != null) {
        return FeedRefreshStart.throttled(throttled);
      }
    }

    final podcasts = (await ref.read(databaseProvider).listPodcasts())
        .where((podcast) => podcast.keepUpdated)
        .toList();
    if (podcasts.isEmpty) return const FeedRefreshStart.empty();
    if (state.isRunning) return const FeedRefreshStart.alreadyRunning();

    await ref
        .read(sharedPreferencesProvider)
        .setInt(_lastRefreshKey, DateTime.now().millisecondsSinceEpoch);

    state = FeedRefreshState(
      phase: FeedRefreshPhase.running,
      total: podcasts.length,
    );
    _run(podcasts);
    return const FeedRefreshStart.started();
  }

  Duration? _throttleRemaining() {
    final minutes = ref.read(settingsProvider).refreshIntervalMinutes;
    if (minutes <= 0) return null;
    final lastMs = ref.read(sharedPreferencesProvider).getInt(_lastRefreshKey);
    if (lastMs == null) return null;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastMs),
    );
    final minInterval = Duration(minutes: minutes);
    if (elapsed >= minInterval) return null;
    return minInterval - elapsed;
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
          notifyNewEpisodes: ref.read(settingsProvider).notifyNewEpisodes,
          onProgress: (done, total, failures) {
            if (!state.isRunning) return;
            final now = DateTime.now();
            final isLast = done >= total;
            if (!isLast &&
                now.difference(_lastProgressUi) <
                    const Duration(milliseconds: 200)) {
              return;
            }
            _lastProgressUi = now;
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
    if (!ref.mounted || report.arrivals.isEmpty) return;
    await announceNewEpisodes(
      ref.read(statusNotificationsProvider),
      ref.read(settingsProvider),
      report.arrivals,
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

String formatRefreshRetryAfter(Duration remaining) {
  final totalSeconds = remaining.inSeconds.clamp(1, 24 * 60 * 60);
  if (totalSeconds < 60) {
    return '$totalSeconds s';
  }
  final minutes = (totalSeconds / 60).ceil();
  if (minutes < 60) {
    return minutes == 1 ? '1 min' : '$minutes min';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) {
    return hours == 1 ? '1 h' : '$hours h';
  }
  return '$hours h $rest min';
}
