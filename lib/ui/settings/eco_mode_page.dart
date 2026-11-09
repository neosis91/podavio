import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../settings/settings_controller.dart';
import '../widgets/brand.dart';
import '../widgets/list_metrics.dart';

class EcoModePage extends ConsumerWidget {
  const EcoModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settingsProvider.select((settings) => settings.ecoMode),
    );
    final idle = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Eco mode'))),
      body: ListView(
        padding: underChrome(context, const EdgeInsets.only(bottom: 32)),
        children: [
          SwitchListTile(
            secondary: EcoIcon(color: enabled ? podavioGreen : idle),
            title: Text(context.tr('Eco mode')),
            value: enabled,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setEcoMode(value),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              context.tr(
                'Eco mode limits network requests. Covers already saved or cached stay visible. New covers are not downloaded: the name appears in white on a square colored from the podcast name. In small lists a leaf sits in the center. Dark theme and pure black turn on and stay on. Automatic cover downloads stop, and the player no longer fetches a cover only to tint the screen.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
