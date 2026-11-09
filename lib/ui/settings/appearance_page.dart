import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/wallpaper_colors.dart';
import '../../data/catalog_categories.dart';
import '../../data/discover_providers.dart';
import '../../l10n/l10n.dart';
import '../../settings/settings_controller.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/brand.dart';
import '../widgets/list_metrics.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final wallpaperOption = defaultTargetPlatform != TargetPlatform.iOS;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Interface'))),
      body: ListView(
        padding: underChrome(context, const EdgeInsets.only(bottom: 32)),
        children: [
          ListTile(title: Text(context.tr('Appearance'))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(context.tr('System')),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(context.tr('Light')),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(context.tr('Dark')),
                ),
              ],
              selected: {
                settings.ecoMode ? ThemeMode.dark : settings.themeMode,
              },
              onSelectionChanged: settings.ecoMode
                  ? null
                  : (selection) => notifier.setThemeMode(selection.first),
            ),
          ),
          if (settings.ecoMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                context.tr('Dark theme stays on while Eco mode is on'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          SwitchListTile(
            title: Text(context.tr('Pure black')),
            subtitle: Text(
              context.tr(
                settings.ecoMode
                    ? 'Pure black stays on while Eco mode is on'
                    : 'Black background in dark mode',
              ),
            ),
            value: settings.pureBlack || settings.ecoMode,
            onChanged: settings.ecoMode ? null : notifier.setPureBlack,
          ),
          if (wallpaperOption)
            SwitchListTile(
              title: Text(context.tr('Wallpaper')),
              subtitle: Text(_wallpaperSubtitle(context, ref)),
              value: settings.wallpaperColors,
              onChanged: notifier.setWallpaperColors,
            ),
          if (!wallpaperOption || !settings.wallpaperColors) ...[
            const SizedBox(height: 8),
            ListTile(title: Text(context.tr('Color'))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final accent in AppAccent.values)
                    _AccentChoice(
                      accent: accent,
                      selected: settings.accent == accent,
                      onTap: () => notifier.setAccent(accent),
                    ),
                ],
              ),
            ),
          ],
          SwitchListTile(
            title: Text(context.tr('Cover tint')),
            subtitle: Text(
              context.tr('The player and the top of the home follow the cover'),
            ),
            value: settings.tintFromCover,
            onChanged: notifier.setTintFromCover,
          ),
          ListTile(
            title: Text(context.tr('Shelves')),
            subtitle: Text(context.tr('Order and hide the home shelves')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showHomeShelvesSheet(context, ref),
          ),
          ListTile(
            title: Text(context.tr('Categories')),
            subtitle: Text(
              context.tr(
                'Until you choose, the home follows the most played categories this month.',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showHomeCategoriesSheet(context, ref),
          ),
        ],
      ),
    );
  }
}

String _wallpaperSubtitle(BuildContext context, WidgetRef ref) {
  final palette = ref.watch(wallpaperPaletteProvider);
  final enabled = ref.watch(
    settingsProvider.select((settings) => settings.wallpaperColors),
  );
  if (!enabled) {
    return context.tr('Match colors to the wallpaper');
  }
  if (palette.isLoading) return context.tr('Reading the wallpaper…');
  if (palette.hasError || palette.asData?.value == null) {
    return context.tr('The wallpaper could not be read');
  }
  return context.tr('Colors follow the wallpaper');
}

Future<void> _showHomeShelvesSheet(BuildContext context, WidgetRef ref) {
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _HomeShelvesSheet(),
  );
}

class _HomeShelvesSheet extends ConsumerWidget {
  const _HomeShelvesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelves = ref.watch(
      settingsProvider.select((settings) => settings.homeShelves),
    );
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    Future<void> update(HomeShelves next) {
      return notifier.setHomeShelves(next);
    }

    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              context.tr('Shelves'),
              style: theme.textTheme.titleMedium,
            ),
          ),
          onReorderItem: (oldIndex, newIndex) {
            final order = [...shelves.order];
            final moved = order.removeAt(oldIndex);
            order.insert(newIndex, moved);
            update(shelves.copyWith(order: order));
          },
          children: [
            for (final entry in shelves.order.indexed)
              _HomeShelfRow(
                key: ValueKey(entry.$2),
                id: entry.$2,
                index: entry.$1,
                visible: shelves.isOn(entry.$2),
                onChanged: (value) {
                  final id = entry.$2;
                  final enabled = {...shelves.enabled};
                  if (value) {
                    enabled.add(id);
                  } else {
                    enabled.remove(id);
                  }
                  update(shelves.copyWith(enabled: enabled));
                },
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showHomeCategoriesSheet(BuildContext context, WidgetRef ref) {
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _HomeCategoriesSheet(),
  );
}

class _HomeCategoriesSheet extends ConsumerWidget {
  const _HomeCategoriesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(displayedHomeCategoriesProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    Future<void> update(HomeCategories next) {
      return notifier.setHomeCategories(next);
    }

    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              context.tr('Categories'),
              style: theme.textTheme.titleMedium,
            ),
          ),
          onReorderItem: (oldIndex, newIndex) {
            final order = [...categories.order];
            final moved = order.removeAt(oldIndex);
            order.insert(newIndex, moved);
            update(categories.copyWith(order: order));
          },
          children: [
            for (final entry in categories.order.indexed)
              _HomeShelfRow(
                key: ValueKey(entry.$2),
                id: entry.$2,
                index: entry.$1,
                visible: categories.isOn(entry.$2),
                title: homeCategoryTitle(entry.$2),
                onChanged: (value) {
                  final id = entry.$2;
                  final enabled = {...categories.enabled};
                  if (value) {
                    enabled.add(id);
                  } else {
                    enabled.remove(id);
                  }
                  update(categories.copyWith(enabled: enabled));
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeShelfRow extends StatelessWidget {
  const _HomeShelfRow({
    super.key,
    required this.id,
    required this.index,
    required this.visible,
    required this.onChanged,
    this.title,
  });

  final String id;
  final int index;
  final bool visible;
  final ValueChanged<bool> onChanged;

  /// Clé anglaise du libellé. Sans valeur, c’est le titre d’une étagère.
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Row(
        children: [
          Tooltip(
            message: context.tr('Move'),
            child: ReorderableDragStartListener(
              index: index,
              child: const SizedBox(
                width: 48,
                height: 56,
                child: Center(child: DragIndicatorIcon()),
              ),
            ),
          ),
          Expanded(
            child: SwitchListTile(
              value: visible,
              onChanged: onChanged,
              title: Text(context.tr(title ?? homeShelfTitle(id))),
              contentPadding: const EdgeInsets.only(right: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final check = accent.seed.computeLuminance() < 0.45
        ? Colors.white
        : Colors.black;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.seed,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: selected ? Icon(Icons.check, color: check) : null,
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(accent.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
