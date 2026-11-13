import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/automatic_downloads.dart';
import '../data/opml.dart';
import '../data/providers.dart';
import '../player/android_auto_bridge.dart';
import '../player/player_controller.dart';
import '../player/player_sheet_controller.dart';
import '../settings/settings_controller.dart';
import '../web_companion/web_companion_controller.dart';
import 'automatic_downloads_page.dart';
import 'discover_languages_page.dart';
import 'discover_page.dart';
import 'episode_page.dart';
import 'episodes_page.dart';
import 'history_page.dart';
import 'interface_language_page.dart';
import 'home_page.dart';
import 'library_hub_page.dart';
import 'library_pages.dart';
import 'licenses_page.dart';
import 'more_page.dart';
import 'nearby_share_page.dart';
import 'opml_import_page.dart';
import 'podcast_page.dart';
import 'podcasts_page.dart';
import 'playlists_page.dart';
import 'queue_page.dart';
import 'router.dart';
import 'settings_page.dart';
import 'shell.dart';
import 'stats_page.dart';
import 'sync_page.dart';
import 'web_companion_page.dart';
import 'activity_notices.dart';
import 'welcome_page.dart';
import 'widgets/app_bottom_sheet.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(settingsProvider.select((s) => s.onboardingComplete), (_, _) {
    refresh.value++;
  });
  ref.listen(preferredPodcastsProvider, (_, _) {
    refresh.value++;
  });
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [sheetBackObserver],
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final done = ref.read(settingsProvider).onboardingComplete;
      final podcasts = ref.read(preferredPodcastsProvider).asData?.value;
      final path = state.uri.path;
      final atWelcome = path == AppRoutes.welcome;
      final showWelcome = !done && podcasts != null && podcasts.isEmpty;
      if (showWelcome) {
        if (atWelcome || path == AppRoutes.opmlImport) return null;
        return AppRoutes.welcome;
      }
      return atWelcome && done ? AppRoutes.home : null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.activity,
            builder: (context, state) => const ActivityPage(),
          ),
          GoRoute(
            path: AppRoutes.library,
            builder: (context, state) => const LibraryPage(),
          ),
          GoRoute(
            path: AppRoutes.episodes,
            builder: (context, state) => const EpisodesPage(),
          ),
          GoRoute(
            path: AppRoutes.queue,
            builder: (context, state) => const QueuePage(),
          ),
          GoRoute(
            path: AppRoutes.playlists,
            builder: (context, state) => const PlaylistsPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) return const PlaylistsPage();
                  return PlaylistPage(playlistId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.podcasts,
            builder: (context, state) => const PodcastsPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) return const PodcastsPage();
                  return PodcastPage(podcastId: id);
                },
                routes: [
                  GoRoute(
                    path: 'about',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const PodcastsPage();
                      return PodcastAboutPage(podcastId: id);
                    },
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const PodcastsPage();
                      return PodcastSettingsPage(podcastId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (context, state) => const DiscoverPage(),
            routes: [
              GoRoute(
                path: 'more',
                builder: (context, state) => const DiscoverMorePage(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.preferences,
            builder: (context, state) => const PreferencesPage(),
          ),
          GoRoute(
            path: AppRoutes.favorites,
            builder: (context, state) => const FavoritesPage(),
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (context, state) => const HistoryPage(),
          ),
          GoRoute(
            path: AppRoutes.downloads,
            builder: (context, state) => const DownloadsPage(),
          ),
          GoRoute(
            path: AppRoutes.cache,
            builder: (context, state) => const CachePage(),
          ),
          GoRoute(
            path: AppRoutes.discoverLanguages,
            builder: (context, state) => const DiscoverLanguagesPage(),
          ),
          GoRoute(
            path: AppRoutes.languages,
            builder: (context, state) => const LanguageSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.appearance,
            builder: (context, state) => const AppearancePage(),
            routes: [
              GoRoute(
                path: 'language',
                builder: (context, state) => const InterfaceLanguagePage(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.playback,
            builder: (context, state) => const PlaybackPage(),
          ),
          GoRoute(
            path: AppRoutes.downloadSettings,
            builder: (context, state) => const DownloadSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.automaticDownloads,
            builder: (context, state) => const AutomaticDownloadsPage(),
          ),
          GoRoute(
            path: AppRoutes.network,
            builder: (context, state) => const NetworkSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.eco,
            builder: (context, state) => const EcoModePage(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.about,
            builder: (context, state) => const AboutPage(),
          ),
          GoRoute(
            path: AppRoutes.nearbyShare,
            builder: (context, state) => const NearbySharePage(),
          ),
          GoRoute(
            path: AppRoutes.licenses,
            builder: (context, state) => const LicensesPage(),
          ),
          GoRoute(
            path: AppRoutes.sync,
            builder: (context, state) => const SyncPage(),
          ),
          GoRoute(
            path: AppRoutes.webCompanion,
            builder: (context, state) => const WebCompanionPage(),
          ),
          GoRoute(
            path: AppRoutes.webCompanionScan,
            builder: (context, state) => const WebCompanionScanPage(),
          ),
          GoRoute(
            path: AppRoutes.webCompanionDevice,
            builder: (context, state) => const WebCompanionDevicePage(),
          ),
          GoRoute(
            path: AppRoutes.backupRestore,
            builder: (context, state) => const BackupRestorePage(),
          ),
          GoRoute(
            path: AppRoutes.stats,
            builder: (context, state) => const StatsPage(),
          ),
          GoRoute(
            path: AppRoutes.opmlImport,
            builder: (context, state) {
              final entries = state.extra;
              if (entries is! List<OpmlEntry>) {
                return const BackupRestorePage();
              }
              return OpmlImportPage(entries: entries);
            },
          ),
          GoRoute(
            path: '/episode/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) return const HomePage();
              return EpisodePage(episodeId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.welcome,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: AppRoutes.player,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const _PlayerExpandGate(),
      ),
    ],
  );
});

class PlaybackLifecycle extends ConsumerStatefulWidget {
  const PlaybackLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlaybackLifecycle> createState() => _PlaybackLifecycleState();
}

/// Ouvre le mini player expansible puis quitte la route `/player`.
class _PlayerExpandGate extends ConsumerStatefulWidget {
  const _PlayerExpandGate();

  @override
  ConsumerState<_PlayerExpandGate> createState() => _PlayerExpandGateState();
}

class _PlayerExpandGateState extends ConsumerState<_PlayerExpandGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openPlayer(ref);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _PlaybackLifecycleState extends ConsumerState<PlaybackLifecycle>
    with WidgetsBindingObserver {
  var _wakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(playerProvider.notifier).restoreLastEpisode());
      unawaited(ref.read(automaticDownloadRunProvider.notifier).run());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_wakelockEnabled) {
      unawaited(WakelockPlus.disable());
      _wakelockEnabled = false;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(playerProvider.notifier).persistPosition();
    }
  }

  void _syncWakelock({required bool keepOn, required bool playing}) {
    final shouldEnable = keepOn && playing;
    if (shouldEnable == _wakelockEnabled) return;
    _wakelockEnabled = shouldEnable;
    if (shouldEnable) {
      unawaited(WakelockPlus.enable());
    } else {
      unawaited(WakelockPlus.disable());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Active le pont Android Auto (browse + sync session) sur Android.
    ref.watch(androidAutoBridgeProvider);
    ref.watch(webCompanionProvider);
    final keepOn = ref.watch(
      settingsProvider.select((settings) => settings.keepScreenOn),
    );
    final playing = ref.watch(playerProvider.select((state) => state.playing));
    _syncWakelock(keepOn: keepOn, playing: playing);
    return widget.child;
  }
}
