import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_controller.dart';
import '../widgets/app_bottom_sheet.dart';

String formatPlaybackSpeed(double speed) {
  final text = speed == speed.roundToDouble()
      ? speed.toInt().toString()
      : speed.toString();
  return '$text×';
}

Future<void> choosePlaybackSpeed(BuildContext context, WidgetRef ref) {
  return showAppModalBottomSheet<void>(
    context: context,
    theme: themeAboveCover(context),
    showDragHandle: true,
    builder: (context) => const _SpeedSheet(),
  );
}

class _SpeedSheet extends ConsumerStatefulWidget {
  const _SpeedSheet();

  @override
  ConsumerState<_SpeedSheet> createState() => _SpeedSheetState();
}

class _SpeedSheetState extends ConsumerState<_SpeedSheet> {
  static const _min = 0.4;
  static const _max = 7.0;
  static const _steps = [0.01, 0.05, 0.1, 0.25, 0.5];

  late double _speed;
  double _increment = 0.01;
  var _enabled = true;

  @override
  void initState() {
    super.initState();
    _speed = _snap(ref.read(playerProvider).speed, _increment);
  }

  double _snap(double value, double step) {
    final snapped = (value / step).round() * step;
    final clamped = snapped.clamp(_min, _max);
    return double.parse(clamped.toStringAsFixed(_decimalsFor(step)));
  }

  int _decimalsFor(double step) {
    final text = step.toStringAsFixed(2);
    return text.endsWith('0') ? 1 : 2;
  }

  String _speedLabel(double speed) {
    final text = speed.toStringAsFixed(_decimalsFor(_increment));
    return '${text.replaceAll('.', ',')}X';
  }

  String _stepLabel(double step) {
    final text = step.toStringAsFixed(_decimalsFor(step));
    return '${text.replaceAll('.', ',')}×';
  }

  void _setSpeed(double value) {
    setState(() => _speed = _snap(value, _increment));
  }

  Future<void> _apply() async {
    final speed = _enabled ? _speed : 1.0;
    await ref.read(playerProvider.notifier).setSpeed(speed);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final muted = scheme.onSurfaceVariant;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.play_arrow, size: 22, color: scheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  'Vitesse de lecture',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Contrôle vitesse de lecture',
                    style: TextStyle(fontSize: 16, color: scheme.onSurface),
                  ),
                ),
                Switch(
                  value: _enabled,
                  activeThumbColor: scheme.onPrimary,
                  activeTrackColor: accent,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ],
            ),
            Opacity(
              opacity: _enabled ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !_enabled,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _StepButton(
                              icon: Icons.remove,
                              onPressed: () => _setSpeed(_speed - _increment),
                            ),
                            Expanded(
                              child: Text(
                                _speedLabel(_speed),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                            _StepButton(
                              icon: Icons.add,
                              onPressed: () => _setSpeed(_speed + _increment),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: accent,
                            inactiveTrackColor: scheme.outlineVariant,
                            thumbColor: accent,
                            overlayColor: accent.withValues(alpha: 0.15),
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            value: _speed,
                            min: _min,
                            max: _max,
                            onChanged: _setSpeed,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '0,4X',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                              Text(
                                '7,0X',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Incrément de vitesse',
                    style: TextStyle(fontSize: 16, color: scheme.onSurface),
                  ),
                ),
                PopupMenuButton<double>(
                  initialValue: _increment,
                  onSelected: (step) {
                    setState(() {
                      _increment = step;
                      _speed = _snap(_speed, step);
                    });
                  },
                  itemBuilder: (context) => [
                    for (final step in _steps)
                      PopupMenuItem(value: step, child: Text(_stepLabel(step))),
                  ],
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        _stepLabel(_increment),
                        style: TextStyle(color: muted, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
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
                      horizontal: 22,
                      vertical: 8,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _apply,
                  child: const Text(
                    'Ok',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
