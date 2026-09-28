import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import 'router.dart';
import 'widgets/mini_player.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final index = _indexFor(path);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final queued = ref.watch(queueCountProvider).value ?? 0;
    final destinations = [
      _Destination(AppRoutes.episodes, 'Épisodes', Icons.podcasts_outlined, Icons.podcasts, unread),
      _Destination(AppRoutes.queue, 'File', Icons.queue_music_outlined, Icons.queue_music, queued),
      const _Destination(AppRoutes.podcasts, 'Abonnements', Icons.grid_view_outlined, Icons.grid_view, 0),
      const _Destination(AppRoutes.discover, 'Explorer', Icons.explore_outlined, Icons.explore, 0),
      const _Destination(AppRoutes.more, 'Plus', Icons.menu_outlined, Icons.menu, 0),
    ];

    void select(int selected) => context.go(destinations[selected].path);

    final content = Column(
      children: [
        Expanded(child: child),
        const MiniPlayer(),
      ],
    );

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: _BadgedIcon(icon: destination.icon, count: destination.count),
                      selectedIcon: _BadgedIcon(
                        icon: destination.selectedIcon,
                        count: destination.count,
                      ),
                      label: Text(destination.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: select,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: _BadgedIcon(icon: destination.icon, count: destination.count),
              selectedIcon: _BadgedIcon(
                icon: destination.selectedIcon,
                count: destination.count,
              ),
              label: destination.label,
            ),
        ],
      ),
    );
  }

  int _indexFor(String path) {
    if (path.startsWith(AppRoutes.queue)) return 1;
    if (path.startsWith(AppRoutes.podcasts)) return 2;
    if (path.startsWith(AppRoutes.discover)) return 3;
    if (path.startsWith(AppRoutes.more) ||
        path.startsWith(AppRoutes.favorites) ||
        path.startsWith(AppRoutes.history) ||
        path.startsWith(AppRoutes.downloads) ||
        path.startsWith(AppRoutes.settings)) {
      return 4;
    }
    return 0;
  }
}

class _Destination {
  const _Destination(this.path, this.label, this.icon, this.selectedIcon, this.count);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int count;
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    );
  }
}
