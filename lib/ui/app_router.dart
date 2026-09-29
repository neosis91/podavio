import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'discover_page.dart';
import 'episode_page.dart';
import 'episodes_page.dart';
import 'home_page.dart';
import 'library_pages.dart';
import 'more_page.dart';
import 'player_page.dart';
import 'podcast_page.dart';
import 'podcasts_page.dart';
import 'queue_page.dart';
import 'router.dart';
import 'settings_page.dart';
import 'shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final start = ref.read(settingsProvider).navOrder.first;
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: start,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomePage(),
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
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (context, state) => const DiscoverPage(),
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
            path: AppRoutes.appearance,
            builder: (context, state) => const AppearancePage(),
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
            path: AppRoutes.about,
            builder: (context, state) => const AboutPage(),
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
        path: AppRoutes.player,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const PlayerPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        ),
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

class _PlaybackLifecycleState extends ConsumerState<PlaybackLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  Widget build(BuildContext context) => widget.child;
}
