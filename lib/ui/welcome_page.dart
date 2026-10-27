import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/automatic_downloads.dart';
import '../data/providers.dart';
import '../l10n/l10n.dart';
import '../settings/settings_controller.dart';
import 'more_page.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/messages.dart';

/// Premier écran, quand la bibliothèque est encore vide.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  var _restore = false;
  int? _setup;
  var _offline = false;

  Future<void> _leave(String path) async {
    await ref.read(settingsProvider.notifier).setOnboardingComplete(true);
    if (mounted) context.go(path);
  }

  Future<void> _restoreBackup() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final imported = await importLibraryDatabase(context, confirm: false);
    if (!imported) return;
    await container.read(settingsProvider.notifier).setOnboardingComplete(true);
    if (mounted) context.go(AppRoutes.home);
  }

  Future<void> _setAutomaticDownload(bool enabled) async {
    if (enabled) {
      try {
        await ref.read(databaseProvider).enableAutoDownloadForSubscriptions();
      } catch (error) {
        if (mounted) showMessage(context, errorText(error));
        return;
      }
    }
    await ref.read(settingsProvider.notifier).setAutomaticDownload(enabled);
    if (enabled) {
      unawaited(ref.read(automaticDownloadRunProvider.notifier).run());
    }
  }

  Future<void> _chooseOffline(bool offline) async {
    setState(() => _offline = offline);
    if (offline) {
      if (!ref.read(settingsProvider).automaticDownload) {
        await _setAutomaticDownload(true);
      }
    } else {
      await _setAutomaticDownload(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_setup != null) {
      return _SetupFlow(
        step: _setup!,
        offline: _offline,
        onBack: () => setState(() {
          if (_setup == 0) {
            _setup = null;
          } else {
            _setup = _setup! - 1;
          }
        }),
        onNext: () {
          if (_setup! < 3) {
            setState(() => _setup = _setup! + 1);
          } else {
            _leave(AppRoutes.home);
          }
        },
        onImport: () => importOpmlFile(context, ref),
        onOffline: _chooseOffline,
        onAutomatic: _setAutomaticDownload,
      );
    }
    if (_restore) {
      return _RestoreBackupPage(
        onBack: () => setState(() => _restore = false),
        onNext: () => _leave(AppRoutes.home),
        onRestore: _restoreBackup,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final title = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 220,
            child: _WelcomeWaves(flip: false),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 180,
            child: _WelcomeWaves(flip: true),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Column(
                children: [
                  const Spacer(),
                  const PodavioLogo(width: 220),
                  const SizedBox(height: 36),
                  Text(
                    context.tr('Welcome to Podavio'),
                    textAlign: TextAlign.center,
                    style: title.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('Discover, organize, and listen your way.'),
                    textAlign: TextAlign.center,
                    style: title.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _WelcomeChoice(
                    icon: Icons.person_outline,
                    iconColor: scheme.primary,
                    iconBackground: scheme.primaryContainer,
                    title: context.tr('I am new to Podavio'),
                    subtitle: context.tr('Set up the app in a few quick steps'),
                    onTap: () => setState(() => _setup = 0),
                  ),
                  const SizedBox(height: 12),
                  _WelcomeChoice(
                    icon: Icons.history,
                    iconColor: scheme.onSurfaceVariant,
                    iconBackground: scheme.surfaceContainerHighest,
                    title: context.tr('I already use Podavio'),
                    subtitle: context.tr('Restore your library from a backup'),
                    onTap: () => setState(() => _restore = true),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _leave(AppRoutes.home),
                    child: Text(context.tr('Continue without setup')),
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

class _SetupFlow extends ConsumerWidget {
  const _SetupFlow({
    required this.step,
    required this.offline,
    required this.onBack,
    required this.onNext,
    required this.onImport,
    required this.onOffline,
    required this.onAutomatic,
  });

  final int step;
  final bool offline;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onImport;
  final ValueChanged<bool> onOffline;
  final ValueChanged<bool> onAutomatic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final title = Theme.of(context).textTheme;
    final (heading, subtitle, body) = switch (step) {
      0 => (
        context.tr('Import your library'),
        context.tr(
          'Import an OPML file exported from another podcast app.',
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onImport,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder(),
            ),
            child: Text(context.tr('Import')),
          ),
        ),
      ),
      1 => (
        context.tr('Use mobile data?'),
        context.tr(
          'Choose whether streaming and downloads can use mobile data.',
        ),
        Column(
          children: [
            _SwitchCard(
              label: context.tr('Allow streaming on mobile data'),
              value: settings.allowMobileStreaming,
              onChanged: (enabled) => ref
                  .read(settingsProvider.notifier)
                  .setAllowMobileStreaming(enabled),
            ),
            const SizedBox(height: 12),
            _SwitchCard(
              label: context.tr('Allow downloads on mobile data'),
              value: settings.allowMobileData,
              onChanged: (enabled) => ref
                  .read(settingsProvider.notifier)
                  .setAllowMobileData(enabled),
            ),
          ],
        ),
      ),
      2 => (
        context.tr('How do you want to listen?'),
        context.tr('Choose your default preference. You can change it later.'),
        Column(
          children: [
            _ListenChoice(
              label: context.tr('Streaming'),
              selected: !offline,
              onTap: () => onOffline(false),
            ),
            const SizedBox(height: 12),
            _ListenChoice(
              label: context.tr('Download to listen offline'),
              selected: offline,
              onTap: () => onOffline(true),
            ),
            if (offline) ...[
              const SizedBox(height: 16),
              _DownloadOptions(
                automatic: settings.automaticDownload,
                limit: settings.automaticDownloadLimit,
                onAutomatic: onAutomatic,
                onLimit: (limit) => ref
                    .read(settingsProvider.notifier)
                    .setAutomaticDownloadLimit(limit),
              ),
            ],
            const SizedBox(height: 28),
            const _ListenNotes(),
          ],
        ),
      ),
      _ => (
        context.tr('Eco mode'),
        context.tr(
          'Eco mode skips new cover downloads. You can turn it off later.',
        ),
        Column(
          children: [
            _SwitchCard(
              label: context.tr('Eco mode'),
              value: settings.ecoMode,
              onChanged: (enabled) =>
                  ref.read(settingsProvider.notifier).setEcoMode(enabled),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(
                'Eco mode limits network requests. Covers already saved or cached stay visible. New covers are not downloaded: the name appears in white on a square colored from the podcast name. In small lists a leaf sits in the center. Dark theme and pure black turn on and stay on. Automatic cover downloads stop, and the player no longer fetches a cover only to tint the screen.',
              ),
              style: title.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    };
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 180,
            child: _WelcomeWaves(flip: true),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primaryContainer,
                    child: step >= 3
                        ? const EcoIcon(size: 34)
                        : const PodavioIcon(size: 34),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    heading,
                    textAlign: TextAlign.center,
                    style: title.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: title.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(child: body),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onBack,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.primary,
                            side: BorderSide(color: scheme.outlineVariant),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                            backgroundColor: scheme.surface,
                          ),
                          child: Text(context.tr('Back')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(context.tr('Next')),
                        ),
                      ),
                    ],
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

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        title: Text(label),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _ListenChoice extends StatelessWidget {
  const _ListenChoice({
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
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: selected ? scheme.primaryContainer : scheme.surface,
          foregroundColor: scheme.onSurface,
          side: BorderSide(
            color: selected ? scheme.primaryContainer : scheme.outlineVariant,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _DownloadOptions extends StatelessWidget {
  const _DownloadOptions({
    required this.automatic,
    required this.limit,
    required this.onAutomatic,
    required this.onLimit,
  });

  final bool automatic;
  final int? limit;
  final ValueChanged<bool> onAutomatic;
  final ValueChanged<int?> onLimit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final limits = <int>[
      1,
      2,
      3,
      4,
      5,
      10,
      20,
      50,
      100,
      if (limit != null &&
          !const {1, 2, 3, 4, 5, 10, 20, 50, 100}.contains(limit))
        limit!,
    ];
    final muted = scheme.onSurface.withValues(alpha: 0.38);
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Download settings'),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'These global settings can be changed later and customized for each podcast.',
              ),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Automatic download')),
              value: automatic,
              onChanged: onAutomatic,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Keep at most'),
                    style: text.bodyLarge?.copyWith(
                      color: automatic ? scheme.onSurface : muted,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: automatic ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: limit ?? 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      borderRadius: BorderRadius.circular(12),
                      style: text.bodyLarge?.copyWith(
                        color: automatic ? scheme.onSurface : muted,
                      ),
                      onChanged: automatic
                          ? (value) => onLimit(value == 0 ? null : value)
                          : null,
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(context.tr('Unlimited')),
                        ),
                        for (final value in limits)
                          DropdownMenuItem(
                            value: value,
                            child: Text('$value'),
                          ),
                      ],
                    ),
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

class _ListenNotes extends StatelessWidget {
  const _ListenNotes();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      children: [
        Text(
          context.tr('Streaming needs an internet connection.'),
          textAlign: TextAlign.center,
          style: style,
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.tr(
                  'Downloads use storage space, but are available offline.',
                ),
                style: style,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RestoreBackupPage extends StatelessWidget {
  const _RestoreBackupPage({
    required this.onBack,
    required this.onNext,
    required this.onRestore,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 180,
            child: _WelcomeWaves(flip: true),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.history, color: scheme.primary, size: 28),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.tr('I already use Podavio'),
                    textAlign: TextAlign.center,
                    style: title.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('Restore your library from a backup'),
                    textAlign: TextAlign.center,
                    style: title.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onRestore,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.primary,
                        side: BorderSide(color: scheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(context.tr('Restore backup')),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onBack,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.primary,
                            side: BorderSide(color: scheme.outlineVariant),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                            backgroundColor: scheme.surface,
                          ),
                          child: Text(context.tr('Back')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(context.tr('Next')),
                        ),
                      ),
                    ],
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

class _WelcomeChoice extends StatelessWidget {
  const _WelcomeChoice({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: iconBackground,
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeWaves extends StatelessWidget {
  const _WelcomeWaves({required this.flip});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return CustomPaint(
      painter: _WavePainter(color: color, flip: flip),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.color, required this.flip});

  final Color color;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (flip) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }
    _band(canvas, size, color.withValues(alpha: 0.16), 0.42, 18, 0);
    _band(canvas, size, color.withValues(alpha: 0.09), 0.62, 26, 40);
    canvas.restore();
  }

  void _band(
    Canvas canvas,
    Size size,
    Color color,
    double heightFactor,
    double amplitude,
    double phase,
  ) {
    final path = Path()..moveTo(0, 0);
    final base = size.height * heightFactor;
    for (var x = 0.0; x <= size.width; x++) {
      final y =
          base +
          amplitude *
              (0.6 * _sin((x + phase) / 90) + 0.4 * _sin((x + phase) / 46));
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  double _sin(double turns) {
    final t = turns % 1;
    final x = t * 2 - 1;
    return 4 * x * (1 - x.abs());
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.flip != flip;
  }
}
