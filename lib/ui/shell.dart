import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/feed_refresh_controller.dart';
import '../data/online_status.dart';
import '../data/opml_import_controller.dart';
import '../data/providers.dart';
import '../sync/sync_controller.dart';
import '../l10n/l10n.dart';
import '../player/player_controller.dart';
import '../player/player_sheet_controller.dart';
import 'nav_catalog.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/expandable_player.dart';
import 'widgets/feed_refresh_banner.dart';
import 'widgets/offline_banner.dart';
import 'widgets/opml_import_banner.dart';
import 'widgets/update_prompt.dart';

/// Capsule Accueil / Abonnements / Bibliothèque, loupe à part pour Explorer.
final shellTabs = <NavPage>[
  NavPage(AppRoutes.home, 'Home', _material(Icons.home)),
  NavPage(
    AppRoutes.podcasts,
    'Subscriptions',
    ({required Color color, double size = 24}) => IconTheme(
      data: IconThemeData(color: color, size: size),
      child: SubscriptionsIcon(size: size),
    ),
  ),
  NavPage(AppRoutes.library, 'Library', _material(Icons.library_music)),
];

final _searchTab = NavPage(
  AppRoutes.discover,
  'Explore',
  _material(Icons.search),
);

NavIconBuilder _material(IconData data) {
  return ({required Color color, double size = 24}) =>
      Icon(data, color: color, size: size);
}

const _libraryRoots = <String>[
  AppRoutes.library,
  AppRoutes.episodes,
  AppRoutes.queue,
  AppRoutes.playlists,
  AppRoutes.favorites,
  AppRoutes.downloads,
  AppRoutes.stats,
  AppRoutes.preferences,
  AppRoutes.appearance,
  AppRoutes.playback,
  AppRoutes.downloadSettings,
  AppRoutes.about,
  AppRoutes.nearbyShare,
  AppRoutes.licenses,
  AppRoutes.backupRestore,
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(coverPrefetchProvider);
    ref.watch(syncStatusProvider);
    final path = GoRouterState.of(context).uri.path;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final desktop = wide && _desktopPlatform(Theme.of(context).platform);
    final padding = MediaQuery.paddingOf(context);
    final selected = _selectedTab(path);
    final hasEpisode = ref.watch(
      playerProvider.select((state) => state.hasEpisode),
    );

    void select(int index) {
      ref.read(playerSheetProvider.notifier).collapse();
      final target = index < 0 ? _searchTab.path : shellTabs[index].path;
      context.go(target);
    }

    final navigation = _NavChrome(
      selectedIndex: selected,
      onSelected: select,
      rail: wide,
      reservePlayer: hasEpisode && !wide,
      windowColor: desktop ? _desktopWindow(context) : null,
    );

    final page = _UnderChrome(child: child);

    if (!wide) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Scaffold(
            extendBody: true,
            body: page,
            bottomNavigationBar: navigation,
          ),
          ExpandablePlayer(
            bottomInset: padding.bottom + _expandedBody + _playerGap,
          ),
          const UpdatePrompt(),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final clearance = hasEpisode
        ? _contentClearanceAboveMiniPlayer(
            bottomInset: desktop ? 12 : padding.bottom + 12,
            contentInset: desktop ? _desktopInset : 0,
          )
        : 0.0;
    final content = clearance == 0
        ? page
        : MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: Padding(
              padding: EdgeInsets.only(bottom: clearance),
              child: page,
            ),
          );

    return Scaffold(
      backgroundColor: desktop ? _desktopWindow(context) : null,
      body: Row(
        children: [
          navigation,
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: desktop
                      ? const EdgeInsets.all(_desktopInset)
                      : EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(desktop ? 12 : 0),
                    child: ColoredBox(
                      color: desktop ? scheme.surfaceContainer : scheme.surface,
                      child: content,
                    ),
                  ),
                ),
                ExpandablePlayer(
                  bottomInset: desktop ? 12 : padding.bottom + 12,
                  topInset: desktop ? 0 : padding.top,
                ),
                const UpdatePrompt(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _desktopPlatform(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

Color _desktopWindow(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black
      : Colors.white;
}

class _UnderChrome extends ConsumerWidget {
  const _UnderChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(onlineStatusProvider) == false;
    final refreshing = ref.watch(feedRefreshProvider).isVisible;
    final importing = ref.watch(opmlImportProvider).isVisible;
    final page = offline || refreshing || importing
        ? MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          )
        : child;
    return Column(
      children: [
        if (offline) const OfflineBanner(),
        const FeedRefreshBanner(),
        const OpmlImportBanner(),
        Expanded(child: page),
      ],
    );
  }
}

const _barHeight = 64.0;
const _barPaddingTop = 4.0;
const _barPaddingBottom = 8.0;
const _expandedBody = _barPaddingTop + _barHeight + _barPaddingBottom;
const _indicatorSize = 56.0;
const _labelInset = 16.0;
const _tabCap = 96.0;
const _capsuleInset = 6.0;
const _searchGap = 12.0;
const _playerGap = 8.0;
const _desktopInset = 8.0;

/// Espace entre le bas du contenu et le haut du mini-lecteur.
double _contentClearanceAboveMiniPlayer({
  required double bottomInset,
  required double contentInset,
}) {
  final raw = bottomInset + miniPlayerHeight - contentInset;
  return raw < 0 ? 0 : raw;
}

int _selectedTab(String path) {
  if (_owns(path, _searchTab.path)) return -1;
  for (var i = 0; i < shellTabs.length; i++) {
    if (_owns(path, shellTabs[i].path)) return i;
  }
  return -2;
}

bool _owns(String path, String tab) {
  if (tab == AppRoutes.home) {
    return path == AppRoutes.home || path == AppRoutes.history;
  }
  if (tab == AppRoutes.podcasts || tab == AppRoutes.discover) {
    return path == tab || path.startsWith('$tab/');
  }
  if (tab == AppRoutes.library) {
    for (final root in _libraryRoots) {
      if (path == root || path.startsWith('$root/')) return true;
    }
  }
  return false;
}

class _NavChrome extends StatelessWidget {
  const _NavChrome({
    required this.selectedIndex,
    required this.onSelected,
    required this.rail,
    required this.reservePlayer,
    this.windowColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool rail;
  final bool reservePlayer;
  final Color? windowColor;

  @override
  Widget build(BuildContext context) {
    if (rail) {
      return _AppRail(
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        background: windowColor,
      );
    }
    final slot = reservePlayer ? miniPlayerHeight + _playerGap : 0.0;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: slot),
          _OpenBar(selectedIndex: selectedIndex, onSelected: onSelected),
        ],
      ),
    );
  }
}

class _AppRail extends StatelessWidget {
  const _AppRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.background,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = [...shellTabs, _searchTab];
    final selected = selectedIndex == -1
        ? pages.length - 1
        : (selectedIndex >= 0 && selectedIndex < pages.length
              ? selectedIndex
              : null);
    return NavigationRail(
      backgroundColor: background ?? scheme.surface,
      selectedIndex: selected,
      groupAlignment: 1,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (index) {
        onSelected(index == pages.length - 1 ? -1 : index);
      },
      leading: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 16),
        child: const SizedBox.square(
          dimension: 48,
          child: Center(child: PodavioIcon(size: 32)),
        ),
      ),
      trailing: const SizedBox(height: 32),
      destinations: [
        for (final page in pages)
          NavigationRailDestination(
            icon: _RailIcon(page: page),
            selectedIcon: _RailIcon(page: page),
            label: Text(context.tr(page.label)),
          ),
      ],
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({required this.page});

  final NavPage page;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color;
    if (color == null) return page.buildIcon(color: Colors.transparent);
    return page.buildIcon(color: color);
  }
}

class _OpenBar extends StatelessWidget {
  const _OpenBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        _barPaddingTop,
        16,
        _barPaddingBottom,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth - _indicatorSize - _searchGap;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TabCapsule(
                selectedIndex: selectedIndex,
                availableWidth: available,
                onSelected: onSelected,
              ),
              const SizedBox(width: _searchGap),
              _SearchButton(
                selected: selectedIndex == -1,
                onPressed: () => onSelected(-1),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabCapsule extends StatefulWidget {
  const _TabCapsule({
    required this.selectedIndex,
    required this.onSelected,
    this.availableWidth,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double? availableWidth;

  @override
  State<_TabCapsule> createState() => _TabCapsuleState();
}

class _TabCapsuleState extends State<_TabCapsule> {
  double? _drag;

  double _tabExtent(int count) {
    final available = widget.availableWidth ?? _tabCap * count;
    final raw = (available - _capsuleInset * 2) / count;
    return raw.clamp(56.0, _tabCap);
  }

  void _dragTo(double local, double extent, int count) {
    final fromStart = (local - _capsuleInset).clamp(0.0, extent * count);
    setState(() {
      _drag = (fromStart / extent - 0.5).clamp(0.0, count - 1.0);
    });
  }

  void _drop(int count) {
    final drag = _drag;
    setState(() => _drag = null);
    if (drag == null) return;
    final index = drag.round().clamp(0, count - 1);
    if (index != widget.selectedIndex) widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = shellTabs.length;
    final extent = _tabExtent(count);
    final selected = widget.selectedIndex;
    final active = _drag ?? (selected < 0 ? null : selected.toDouble());
    final along = extent * (active ?? 0);
    final length = extent * count + _capsuleInset * 2;
    final indicator = active == null
        ? null
        : AnimatedPositioned(
            duration: _drag == null
                ? const Duration(milliseconds: 320)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            left: along,
            top: (_barHeight - _indicatorSize) / 2,
            width: extent,
            height: _indicatorSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(_indicatorSize / 2),
              ),
            ),
          );

    final labelScaler = _navLabelScaler(context, extent);
    final tabs = [
      for (var i = 0; i < count; i++)
        SizedBox(
          width: extent,
          height: _barHeight,
          child: _NavButton(
            page: shellTabs[i],
            selected: (_drag?.round() ?? selected) == i,
            labelScaler: labelScaler,
            onPressed: () => widget.onSelected(i),
          ),
        ),
    ];

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(_barHeight / 2),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onHorizontalDragStart: (details) =>
            _dragTo(details.localPosition.dx, extent, count),
        onHorizontalDragUpdate: (details) =>
            _dragTo(details.localPosition.dx, extent, count),
        onHorizontalDragEnd: (_) => _drop(count),
        onHorizontalDragCancel: () => setState(() => _drag = null),
        child: SizedBox(
          width: length,
          height: _barHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _capsuleInset),
            child: Stack(
              children: [
                ?indicator,
                Row(children: tabs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.selected, required this.onPressed});

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Material(
      color: selected
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainer,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: _indicatorSize,
          child: Tooltip(
            message: context.tr(_searchTab.label),
            child: Center(
              child: _searchTab.buildIcon(color: color, selected: selected),
            ),
          ),
        ),
      ),
    );
  }
}

/// Même corps de texte pour les trois onglets, calé sur le libellé le plus long.
TextScaler _navLabelScaler(BuildContext context, double extent) {
  final style = Theme.of(context).textTheme.bodySmall;
  final fontSize = style?.fontSize ?? 12;
  final scaler = MediaQuery.textScalerOf(context);
  final maxWidth = extent - _labelInset * 2;
  var longest = 0.0;
  for (final page in shellTabs) {
    final painter = TextPainter(
      text: TextSpan(text: context.tr(page.label), style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    if (painter.width > longest) longest = painter.width;
    painter.dispose();
  }
  if (longest <= maxWidth || longest == 0) return scaler;
  return TextScaler.linear(
    scaler.scale(fontSize) / fontSize * maxWidth / longest,
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.page,
    required this.selected,
    required this.labelScaler,
    required this.onPressed,
  });

  final NavPage page;
  final bool selected;
  final TextScaler labelScaler;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          page.buildIcon(color: foreground, selected: selected),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _labelInset),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: labelScaler),
              child: Text(
                context.tr(page.label),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: foreground),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
