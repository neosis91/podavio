import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../settings/settings_controller.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
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
      ),
    );
  }
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
