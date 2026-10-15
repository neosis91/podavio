import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:cast/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../player/player_controller.dart';

/// Cherche les Chromecast du réseau avec l’API Bonsoir actuelle.
Future<List<CastDevice>> searchCastDevices({
  Duration timeout = const Duration(seconds: 5),
}) async {
  final results = <CastDevice>[];
  final discovery = BonsoirDiscovery(type: '_googlecast._tcp');
  await discovery.initialize();
  final subscription = discovery.eventStream?.listen((event) {
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      event.service.resolve(discovery.serviceResolver);
    } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
      final service = event.service;
      final host = service.hostAddress ?? service.hostname;
      if (host == null || host.isEmpty) return;
      final attributes = service.attributes;
      final friendly = [
        attributes['md'],
        attributes['fn'],
      ].whereType<String>().where((value) => value.isNotEmpty).join(' - ');
      results.add(
        CastDevice(
          serviceName: service.name,
          name: friendly.isEmpty ? service.name : friendly,
          port: service.port,
          host: host,
          extras: attributes,
        ),
      );
    }
  });
  try {
    await discovery.start();
    await Future<void>.delayed(timeout);
  } finally {
    await subscription?.cancel();
    await discovery.stop();
  }
  final seen = <String>{};
  return [
    for (final device in results)
      if (seen.add(device.serviceName)) device,
  ];
}

/// Feuille « Sortie audio » : l’appareil local, puis les récepteurs Cast.
Future<void> showAudioOutputSheet(BuildContext context, WidgetRef ref) {
  final theme = _themeAbovePlayer(context) ?? Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Theme(data: theme, child: const _AudioOutputSheet());
    },
  );
}

ThemeData? _themeAbovePlayer(BuildContext context) {
  var seenTheme = false;
  ThemeData? outer;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is! Theme) return true;
    if (!seenTheme) {
      seenTheme = true;
      return true;
    }
    outer = widget.data;
    return false;
  });
  return outer;
}

class _AudioOutputSheet extends ConsumerStatefulWidget {
  const _AudioOutputSheet();

  @override
  ConsumerState<_AudioOutputSheet> createState() => _AudioOutputSheetState();
}

class _AudioOutputSheetState extends ConsumerState<_AudioOutputSheet> {
  List<CastDevice>? _devices;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() {
      _devices = null;
      _error = null;
    });
    try {
      final found = await searchCastDevices();
      if (!mounted) return;
      setState(() => _devices = found);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _devices = const [];
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final castName = ref.watch(
      playerProvider.select((state) => state.castDeviceName),
    );
    final localIcon = switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS => Icons.smartphone,
      _ => Icons.speaker,
    };
    final devices = _devices;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const SizedBox(width: 32, height: 4),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr('Audio output'),
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ),
                _OutputRow(
                  icon: localIcon,
                  name: context.tr('System default'),
                  status: castName == null ? context.tr('Play here') : null,
                  selected: castName == null,
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(playerProvider.notifier).playHere();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Divider(height: 1, color: scheme.outlineVariant),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 4, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cast',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (devices == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 12, 20, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _error == null
                            ? context.tr('No Cast receiver')
                            : context.tr('Cast search unavailable'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final device in devices)
                    _OutputRow(
                      icon: Icons.cast_connected,
                      name: device.name,
                      status: device.name == castName
                          ? context.tr('Play here')
                          : null,
                      selected: device.name == castName,
                      onTap: device.name == castName
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(context);
                              final error = await ref
                                  .read(playerProvider.notifier)
                                  .castTo(device);
                              if (error != null) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(error)),
                                );
                              }
                            },
                    ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.onSurface.withValues(alpha: 0.10),
                  ),
                ),
                const _VolumeRow(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Volume bas, piste fine, volume haut — la rangée sous les sorties.
class _VolumeRow extends ConsumerWidget {
  const _VolumeRow();

  static const _iconColor = 0.72;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerProvider.select((state) => state.volume));
    final color = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: _iconColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Row(
        children: [
          Icon(Icons.volume_down, size: 18, color: color),
          const SizedBox(width: _gap),
          Expanded(
            child: _ThinVolumeSlider(
              value: volume,
              onChanged: (value) {
                unawaited(ref.read(playerProvider.notifier).setVolume(value));
              },
            ),
          ),
          const SizedBox(width: _gap),
          Icon(Icons.volume_up, size: 18, color: color),
        ],
      ),
    );
  }
}

/// Piste 8,4 px, 16,8 px pendant le geste, sans curseur.
class _ThinVolumeSlider extends StatefulWidget {
  const _ThinVolumeSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_ThinVolumeSlider> createState() => _ThinVolumeSliderState();
}

class _ThinVolumeSliderState extends State<_ThinVolumeSlider>
    with SingleTickerProviderStateMixin {
  static const _rest = 8.4;
  static const _pressed = 16.8;

  late final AnimationController _inflate = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void dispose() {
    _inflate.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    _inflate.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(mass: 1, stiffness: 300, ratio: 0.5),
        _inflate.value,
        pressed ? 1 : 0,
        0,
      ),
    );
  }

  void _seek(double dx, double width) {
    if (width <= 0) return;
    widget.onChanged((dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inactive = scheme.onSurface.withValues(alpha: 0.26);
    final active = scheme.onSurface.withValues(alpha: 0.92);
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              _setPressed(true);
              _seek(details.localPosition.dx, width);
            },
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onHorizontalDragStart: (details) {
              _setPressed(true);
              _seek(details.localPosition.dx, width);
            },
            onHorizontalDragUpdate: (details) {
              _seek(details.localPosition.dx, width);
            },
            onHorizontalDragEnd: (_) => _setPressed(false),
            onHorizontalDragCancel: () => _setPressed(false),
            child: AnimatedBuilder(
              animation: _inflate,
              builder: (context, _) {
                final travel = _inflate.value.clamp(0.0, 1.2);
                final height = (_rest + (_pressed - _rest) * travel).clamp(
                  0.0,
                  18.0,
                );
                final fraction = widget.value.clamp(0.0, 1.0);
                return Align(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(height),
                    child: SizedBox(
                      height: height,
                      width: width,
                      child: ColoredBox(
                        color: inactive,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: fraction,
                            heightFactor: 1,
                            child: ColoredBox(color: active),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({
    required this.icon,
    required this.name,
    required this.selected,
    this.status,
    this.onTap,
  });

  final IconData icon;
  final String name;
  final String? status;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Icon(icon, size: 24, color: scheme.onSurface),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                    if (status != null)
                      Text(
                        status!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check, color: scheme.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}
