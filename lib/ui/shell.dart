import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../settings/settings_controller.dart';
import 'nav_catalog.dart';
import 'router.dart';
import 'widgets/mini_player.dart';

final _plusButtonKey = GlobalKey();

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final padding = MediaQuery.paddingOf(context);
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final queued = ref.watch(queueCountProvider).value ?? 0;
    final order = ref.watch(
      settingsProvider.select((settings) => settings.navOrder),
    );
    final pages = [
      for (final path in order) _pageDestination(path, unread, queued),
    ];
    const plus = _Destination(
      '',
      'Plus',
      Icons.menu_outlined,
      Icons.menu,
      0,
      menu: true,
    );
    final size = MediaQuery.sizeOf(context);
    final safeHeight = size.height - padding.vertical;
    final railLayout = _layoutNav(
      pages: pages,
      plus: plus,
      rail: true,
      available: safeHeight,
    );
    final barLayout = _layoutNav(
      pages: pages,
      plus: plus,
      rail: false,
      available: size.width,
    );
    final useRail =
        wide && railLayout.visible.length >= barLayout.visible.length;
    final layout = useRail ? railLayout : barLayout;
    final destinations = layout.visible;
    final index = _indexFor(path, destinations, layout.overflow);

    void select(int selected) {
      final destination = destinations[selected];
      if (destination.menu) {
        _openPlusMenu(context, layout.overflow);
        return;
      }
      context.go(destination.path);
    }

    final content = Column(
      children: [
        Expanded(child: child),
        const MiniPlayer(),
      ],
    );

    final navigation = _NavStrip(
      destinations: destinations,
      selectedIndex: index,
      onSelected: select,
      rail: useRail,
    );

    if (useRail) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              navigation,
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(body: content, bottomNavigationBar: navigation);
  }

  int _indexFor(
    String path,
    List<_Destination> visible,
    List<_Destination> overflow,
  ) {
    for (var i = 0; i < visible.length; i++) {
      final destination = visible[i];
      if (!destination.menu && _belongs(path, destination.path)) return i;
    }
    if (overflow.any((destination) => _belongs(path, destination.path))) {
      final plus = visible.lastIndexWhere((destination) => destination.menu);
      if (plus >= 0) return plus;
    }
    return -1;
  }
}

const _barLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  height: 1.1,
);
const _railLabelStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  height: 1.2,
);
const _railItemExtent = 56.0;
const _barHeight = 80.0;

class _NavLayout {
  const _NavLayout(this.visible, this.overflow);

  final List<_Destination> visible;
  final List<_Destination> overflow;
}

_Destination _pageDestination(String path, int unread, int queued) {
  final page = navPageByPath(path)!;
  final count = switch (path) {
    AppRoutes.episodes => unread,
    AppRoutes.queue => queued,
    _ => 0,
  };
  return _Destination(
    page.path,
    page.label,
    page.icon,
    page.selectedIcon,
    count,
  );
}

_NavLayout _layoutNav({
  required List<_Destination> pages,
  required _Destination plus,
  required bool rail,
  required double available,
}) {
  if (rail) {
    final capacity = math.max(1, available ~/ _railItemExtent);
    if (pages.length <= capacity) return _NavLayout(pages, const []);
    final take = math.max(0, capacity - 1);
    return _NavLayout([...pages.take(take), plus], pages.skip(take).toList());
  }

  double total(List<_Destination> items) => items.fold(
    0,
    (sum, item) => sum + _slotWidth(item.label, _barLabelStyle),
  );

  if (total(pages) <= available) return _NavLayout(pages, const []);
  var take = pages.length;
  while (take > 0 && total([...pages.take(take), plus]) > available) {
    take--;
  }
  if (take < 4) take = math.min(4, pages.length);
  if (take + 1 == 6) take = 4;
  return _NavLayout([...pages.take(take), plus], pages.skip(take).toList());
}

double _textWidth(String label, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

double _slotWidth(String label, TextStyle style) =>
    math.max(72, _textWidth(label, style) + 12);

double _railWidth(List<_Destination> items) {
  var text = 0.0;
  for (final item in items) {
    var width = _textWidth(item.label, _railLabelStyle);
    if (item.count > 0) width += 32;
    text = math.max(text, width);
  }
  return math.min(248, math.max(196, 88 + text));
}

bool _belongs(String path, String route) {
  if (route == AppRoutes.home) return path == AppRoutes.home;
  if (route == AppRoutes.preferences) {
    return path == AppRoutes.preferences ||
        path == AppRoutes.appearance ||
        path == AppRoutes.playback;
  }
  return path == route || path.startsWith('$route/');
}

Future<void> _openPlusMenu(
  BuildContext context,
  List<_Destination> overflow,
) async {
  final path = GoRouterState.of(context).uri.path;
  final choice = await showMenu<String>(
    context: context,
    position: _plusMenuAnchor(context),
    items: [
      for (final entry in overflow)
        PopupMenuItem(
          value: entry.path,
          child: _PlusMenuRow(
            icon: entry.icon,
            label: entry.label,
            selected: _belongs(path, entry.path),
          ),
        ),
    ],
  );
  if (choice != null && context.mounted) context.go(choice);
}

RelativeRect _plusMenuAnchor(BuildContext context) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final box = _plusButtonKey.currentContext?.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize) {
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    return RelativeRect.fromRect(offset & box.size, Offset.zero & overlay.size);
  }
  final size = overlay.size;
  return RelativeRect.fromLTRB(0, size.height - _barHeight, 0, _barHeight);
}

class _NavStrip extends StatelessWidget {
  const _NavStrip({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.rail,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final buttons = [
      for (var i = 0; i < destinations.length; i++)
        _NavButton(
          key: destinations[i].menu
              ? _plusButtonKey
              : ValueKey(destinations[i].path),
          destination: destinations[i],
          selected: i == selectedIndex,
          rail: rail,
          onPressed: () => onSelected(i),
        ),
    ];
    if (rail) {
      return SizedBox(
        width: _railWidth(destinations),
        child: Material(
          color: scheme.surface,
          child: Column(children: buttons),
        ),
      );
    }
    return Material(
      color: scheme.surfaceContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: SizedBox(
              height: _barHeight,
              child: Row(
                children: [
                  for (var i = 0; i < buttons.length; i++)
                    Expanded(
                      flex: _slotWidth(
                        destinations[i].label,
                        _barLabelStyle,
                      ).round(),
                      child: buttons[i],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.destination,
    required this.selected,
    required this.rail,
    required this.onPressed,
  });

  final _Destination destination;
  final bool selected;
  final bool rail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final iconData = selected ? destination.selectedIcon : destination.icon;
    final icon = IconTheme(
      data: IconThemeData(color: foreground, size: 24),
      child: rail
          ? Icon(iconData)
          : _BadgedIcon(icon: iconData, count: destination.count),
    );
    final label = Text(
      destination.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: rail ? TextAlign.start : TextAlign.center,
      style: (rail ? _railLabelStyle : _barLabelStyle).copyWith(
        color: foreground,
      ),
    );
    final railLabel = Row(
      children: [
        Flexible(child: label),
        if (destination.count > 0) ...[
          const SizedBox(width: 8),
          Badge(
            label: Text(
              destination.count > 99 ? '99+' : '${destination.count}',
            ),
          ),
        ],
      ],
    );
    final child = rail
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? scheme.secondaryContainer : null,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: railLabel),
                  ],
                ),
              ),
            ),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? scheme.secondaryContainer : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: icon,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: label,
              ),
            ],
          );
    return SizedBox(
      height: rail ? _railItemExtent : _barHeight,
      child: InkWell(onTap: onPressed, child: child),
    );
  }
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
    this.count, {
    this.menu = false,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int count;
  final bool menu;
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
