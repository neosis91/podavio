import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
