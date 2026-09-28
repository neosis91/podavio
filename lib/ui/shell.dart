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
      const _Destination(
        AppRoutes.home,
        'Accueil',
        Icons.home_outlined,
        Icons.home,
        0,
      ),
      _Destination(
        AppRoutes.episodes,
        'Épisodes',
        Icons.podcasts_outlined,
        Icons.podcasts,
        unread,
      ),
      _Destination(
        AppRoutes.queue,
        'File',
        Icons.queue_music_outlined,
        Icons.queue_music,
        queued,
      ),
      const _Destination(
        AppRoutes.podcasts,
        'Abonnements',
        Icons.grid_view_outlined,
        Icons.grid_view,
        0,
      ),
      const _Destination(
        AppRoutes.discover,
        'Explorer',
        Icons.explore_outlined,
        Icons.explore,
        0,
      ),
      const _Destination(
        AppRoutes.preferences,
        'Plus',
        Icons.menu_outlined,
        Icons.menu,
        0,
      ),
    ];

    void select(int selected) {
      if (selected == destinations.length - 1) {
        _openPlusMenu(context, destinations.length);
        return;
      }
      context.go(destinations[selected].path);
    }

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
                      icon: _BadgedIcon(
                        icon: destination.icon,
                        count: destination.count,
                      ),
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
              icon: _BadgedIcon(
                icon: destination.icon,
                count: destination.count,
              ),
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
    if (path.startsWith(AppRoutes.episodes)) return 1;
    if (path.startsWith(AppRoutes.queue)) return 2;
    if (path.startsWith(AppRoutes.podcasts)) return 3;
    if (path.startsWith(AppRoutes.discover)) return 4;
    if (path.startsWith(AppRoutes.preferences) ||
        path.startsWith(AppRoutes.favorites) ||
        path.startsWith(AppRoutes.history) ||
        path.startsWith(AppRoutes.downloads) ||
        path.startsWith(AppRoutes.appearance) ||
        path.startsWith(AppRoutes.playback)) {
      return 5;
    }
    return 0;
  }
}

const _plusEntries = [
  _PlusEntry(AppRoutes.history, 'Historique', Icons.history),
  _PlusEntry(AppRoutes.favorites, 'Favoris', Icons.favorite_outline),
  _PlusEntry(AppRoutes.downloads, 'Téléchargements', Icons.download_outlined),
  _PlusEntry(AppRoutes.preferences, 'Préférences', Icons.tune_outlined),
];

Future<void> _openPlusMenu(BuildContext context, int destinationCount) async {
  final path = GoRouterState.of(context).uri.path;
  final wide = MediaQuery.sizeOf(context).width >= 900;
  final choice = await showMenu<String>(
    context: context,
    position: _plusMenuAnchor(context, wide, destinationCount),
    items: [
      for (final entry in _plusEntries)
        PopupMenuItem(
          value: entry.path,
          child: _PlusMenuRow(
            icon: entry.icon,
            label: entry.label,
            selected: path == entry.path,
          ),
        ),
    ],
  );
  if (choice != null && context.mounted) context.go(choice);
}

RelativeRect _plusMenuAnchor(
  BuildContext context,
  bool wide,
  int destinationCount,
) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final size = overlay.size;
  final padding = MediaQuery.paddingOf(context);
  final plusIndex = destinationCount - 1;
  if (wide) {
    const railWidth = 80.0;
    const itemHeight = 72.0;
    final top = padding.top + 12 + itemHeight * plusIndex;
    return RelativeRect.fromLTRB(
      railWidth,
      top,
      size.width - railWidth - 1,
      size.height - top - itemHeight,
    );
  }
  const barHeight = 80.0;
  final bottomInset = padding.bottom + barHeight;
  return RelativeRect.fromLTRB(
    size.width * plusIndex / destinationCount,
    size.height - bottomInset,
    0,
    bottomInset,
  );
}

class _PlusEntry {
  const _PlusEntry(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}

class _PlusMenuRow extends StatelessWidget {
  const _PlusMenuRow({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (selected) const Icon(Icons.check, size: 18),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(
    this.path,
    this.label,
    this.icon,
    this.selectedIcon,
    this.count,
  );

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
