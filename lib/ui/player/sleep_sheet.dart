import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../player/player_controller.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/brand.dart';

Future<void> chooseSleepTimer(BuildContext context, WidgetRef ref) {
  return showAppModalBottomSheet<void>(
    context: context,
    theme: themeAboveCover(context),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _SleepSheet(),
  );
}

enum _SleepUnit { minutes, hours }

class _SleepSheet extends ConsumerStatefulWidget {
  const _SleepSheet();

  @override
  ConsumerState<_SleepSheet> createState() => _SleepSheetState();
}

class _SleepSheetState extends ConsumerState<_SleepSheet> {
  static const _presets = [5, 15, 30, 45];

  final _amount = TextEditingController(text: '30');
  var _unit = _SleepUnit.minutes;
  var _atEnd = false;
  var _atChapter = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(playerProvider);
    final remaining = state.sleepRemaining;
    if (remaining != null && remaining > Duration.zero) {
      final minutes = remaining.inMinutes.clamp(1, 24 * 60);
      _amount.text = '$minutes';
    }
    _atEnd = state.sleepAtEnd;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_amount.text.trim());

  void _pickPreset(int minutes) {
    setState(() {
      _unit = _SleepUnit.minutes;
      _amount.text = '$minutes';
      _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
    });
  }

  void _start(bool chaptersAvailable) {
    final value = _value;
    if (value == null || value <= 0) return;
    final duration = _unit == _SleepUnit.hours
        ? Duration(hours: value.clamp(1, 24))
        : Duration(minutes: value.clamp(1, 24 * 60));
    ref
        .read(playerProvider.notifier)
        .setSleep(
          duration,
          atEnd: _atEnd,
          atChapter: _atChapter && chaptersAvailable,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final episodeId = ref.watch(
      playerProvider.select((state) => state.episodeId),
    );
    final chapterCount = episodeId == null
        ? 0
        : ref.watch(chaptersProvider(episodeId)).value?.length ?? 0;
    final chaptersAvailable = chapterCount >= 2;
    final preset = _unit == _SleepUnit.minutes ? _value : null;
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outline),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTheme(
                  data: IconThemeData(color: scheme.onSurface, size: 22),
                  child: const BedtimeIcon(size: 22),
                ),
                const SizedBox(width: 8),
                Text(
                  'Timer',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Saisir la durée du timer',
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 16, color: scheme.onSurface),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: field,
                      enabledBorder: field,
                      focusedBorder: field.copyWith(
                        borderSide: BorderSide(color: accent, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      border: field,
                      enabledBorder: field,
                      focusedBorder: field.copyWith(
                        borderSide: BorderSide(color: accent, width: 1.5),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_SleepUnit>(
                        value: _unit,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: _SleepUnit.minutes,
                            child: Text('Minutes'),
                          ),
                          DropdownMenuItem(
                            value: _SleepUnit.hours,
                            child: Text('Heures'),
                          ),
                        ],
                        onChanged: (unit) {
                          if (unit == null) return;
                          setState(() => _unit = unit);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final minutes in _presets) ...[
                  Expanded(
                    child: _PresetChip(
                      label: '$minutes min',
                      selected: preset == minutes,
                      onTap: () => _pickPreset(minutes),
                    ),
                  ),
                  if (minutes != _presets.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _StopSwitch(
                    label: 'Arrêter à la fin de l’épisode',
                    value: _atEnd,
                    onChanged: (value) => setState(() => _atEnd = value),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _StopSwitch(
                    label: 'Arrêter à la fin du chapitre (si disponible)',
                    value: chaptersAvailable && _atChapter,
                    onChanged: chaptersAvailable
                        ? (value) => setState(() => _atChapter = value)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Annuler',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: scheme.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _value == null || _value! <= 0
                      ? null
                      : () => _start(chaptersAvailable),
                  child: const Text(
                    'Démarrer le minuteur',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? scheme.primary : scheme.outline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? scheme.primary : scheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _StopSwitch extends StatelessWidget {
  const _StopSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: onChanged == null
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: scheme.onPrimary,
            activeTrackColor: scheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
