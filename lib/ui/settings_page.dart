import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/wallpaper_colors.dart';
import '../settings/settings_controller.dart';
import 'nav_catalog.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final wallpaperOption = defaultTargetPlatform != TargetPlatform.iOS;
    return Scaffold(
      appBar: AppBar(title: const Text('Interface utilisateur')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const ListTile(title: Text('Apparence')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Système')),
                ButtonSegment(value: ThemeMode.light, label: Text('Clair')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Sombre')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) =>
                  notifier.setThemeMode(selection.first),
            ),
          ),
          SwitchListTile(
            title: const Text('Noir pur'),
            subtitle: const Text('Fond noir en mode sombre'),
            value: settings.pureBlack,
            onChanged: notifier.setPureBlack,
          ),
          if (wallpaperOption)
            SwitchListTile(
              title: const Text('Fond d’écran'),
              subtitle: Text(_wallpaperSubtitle(ref)),
              value: settings.wallpaperColors,
              onChanged: notifier.setWallpaperColors,
            ),
          if (!wallpaperOption || !settings.wallpaperColors) ...[
            const SizedBox(height: 8),
            const ListTile(title: Text('Couleur')),
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
          const _SectionTitle('Préférences du volet'),
          ListTile(
            leading: const Icon(Icons.reorder),
            title: const Text('Ordre des pages'),
            subtitle: const Text('L’ordre utilisé par le menu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPanelOrder(context),
          ),
        ],
      ),
    );
  }
}

void _showPanelOrder(BuildContext context) {
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (context) => const _PanelOrderDialog(),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _PanelOrderDialog extends ConsumerStatefulWidget {
  const _PanelOrderDialog();

  @override
  ConsumerState<_PanelOrderDialog> createState() => _PanelOrderDialogState();
}

class _PanelOrderDialogState extends ConsumerState<_PanelOrderDialog> {
  late final List<String> _order;

  @override
  void initState() {
    super.initState();
    _order = List<String>.of(ref.read(settingsProvider).navOrder);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final dialogHeight = height - 48 > 640 ? 640.0 : height - 48;
    return Dialog(
      child: SizedBox(
        width: 420,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'Ordre des pages',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Les pages s’affichent dans cet ordre. Celles qui ne tiennent pas restent dans Plus.',
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: true,
                itemCount: _order.length,
                onReorderItem: _reorder,
                itemBuilder: (context, index) {
                  final page = navPageByPath(_order[index])!;
                  return ListTile(
                    key: ValueKey(page.path),
                    contentPadding: const EdgeInsets.only(left: 24, right: 48),
                    leading: Icon(page.icon),
                    title: Text(page.label),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final path = _order.removeAt(oldIndex);
      _order.insert(newIndex, path);
    });
    ref.read(settingsProvider.notifier).setNavOrder(_order);
  }
}

String _wallpaperSubtitle(WidgetRef ref) {
  final palette = ref.watch(wallpaperPaletteProvider);
  final enabled = ref.watch(
    settingsProvider.select((settings) => settings.wallpaperColors),
  );
  if (!enabled) {
    return 'Adapter les couleurs à celles du fond d’écran';
  }
  if (palette.isLoading) return 'Lecture du fond d’écran…';
  if (palette.hasError || palette.asData?.value == null) {
    return 'Le fond d’écran n’a pas pu être lu';
  }
  return 'Les couleurs suivent le fond d’écran';
}

class PlaybackPage extends ConsumerWidget {
  const PlaybackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Lecture')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Retour rapide'),
            subtitle: Text('${settings.skipBackSeconds} secondes'),
            trailing: DropdownButton<int>(
              value: settings.skipBackSeconds,
              items: const [5, 10, 15, 30]
                  .map(
                    (seconds) => DropdownMenuItem(
                      value: seconds,
                      child: Text('$seconds s'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) notifier.setSkipBack(value);
              },
            ),
          ),
          ListTile(
            title: const Text('Avance rapide'),
            subtitle: Text('${settings.skipForwardSeconds} secondes'),
            trailing: DropdownButton<int>(
              value: settings.skipForwardSeconds,
              items: const [10, 15, 30, 45, 60]
                  .map(
                    (seconds) => DropdownMenuItem(
                      value: seconds,
                      child: Text('$seconds s'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) notifier.setSkipForward(value);
              },
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
              accent.label,
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
