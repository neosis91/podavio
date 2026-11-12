import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/audio_effects.dart';
import '../widgets/app_bottom_sheet.dart';

Future<void> showAudioEffectsSheet(BuildContext context) {
  return showAppModalBottomSheet<void>(
    context: context,
    theme: themeAboveCover(context),
    showDragHandle: true,
    builder: (context) => const _AudioEffectsSheet(),
  );
}

class _AudioEffectsSheet extends ConsumerWidget {
  const _AudioEffectsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(audioEffectsProvider);
    final notifier = ref.read(audioEffectsProvider.notifier);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Effets audios',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _EffectGroup(
                children: [
                  _EffectSwitch(
                    label: 'Amplification',
                    value: effects.amplify,
                    onChanged: notifier.setAmplify,
                  ),
                  _EffectSwitch(
                    label: 'Stabilisateur de volume',
                    value: effects.stabilizeVolume,
                    onChanged: notifier.setStabilizeVolume,
                  ),
                  _EffectSwitch(
                    label: 'Audio mono',
                    value: effects.mono,
                    onChanged: notifier.setMono,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _EffectGroup(
                children: [
                  _EffectSwitch(
                    label: 'Suppression des silences',
                    value: effects.skipSilence,
                    onChanged: notifier.setSkipSilence,
                  ),
                  if (effects.skipSilence)
                    _SilenceStrengthRow(
                      strength: effects.silenceStrength,
                      onSelected: notifier.setSilenceStrength,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffectGroup extends StatelessWidget {
  const _EffectGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, thickness: 1, color: line));
      rows.add(children[i]);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

class _EffectSwitch extends StatelessWidget {
  const _EffectSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SilenceStrengthRow extends StatelessWidget {
  const _SilenceStrengthRow({required this.strength, required this.onSelected});

  final SilenceStrength strength;
  final ValueChanged<SilenceStrength> onSelected;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return PopupMenuButton<SilenceStrength>(
      initialValue: strength,
      onSelected: onSelected,
      itemBuilder: (context) {
        return [
          for (final level in SilenceStrength.values)
            PopupMenuItem(value: level, child: Text(level.label)),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const Expanded(child: Text('Efficacité')),
              Text(strength.label, style: TextStyle(color: muted)),
              Icon(Icons.arrow_drop_down, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
