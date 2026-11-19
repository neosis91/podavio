import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../settings/settings_controller.dart';
import 'more_page.dart';
import 'router.dart';
import 'widgets/brand.dart';

/// Premier écran, quand la bibliothèque est encore vide.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  var _restore = false;
  int? _setup;

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

  @override
  Widget build(BuildContext context) {
    if (_setup != null) {
      return _SetupFlow(
        step: _setup!,
        onBack: () => setState(() {
          if (_setup == 0) {
            _setup = null;
          } else {
            _setup = _setup! - 1;
          }
        }),
        onNext: () {
          if (_setup! < 2) {
            setState(() => _setup = _setup! + 1);
          } else {
            _leave(AppRoutes.home);
          }
        },
        onImport: () => importOpmlFile(context, ref),
      );
    }
    if (_restore) {
      return _RestoreBackupPage(
        onBack: () => setState(() => _restore = false),
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
    required this.onBack,
    required this.onNext,
    required this.onImport,
  });

  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final title = Theme.of(context).textTheme;
    final (heading, subtitle, body) = switch (step) {
      0 => (
        context.tr('Import your library'),
        context.tr('Import an OPML file exported from another podcast app.'),
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
          'Each setting starts on Wi-Fi only. The first action on mobile data still asks for confirmation.',
        ),
        Column(
          children: [
            _SwitchCard(
              label: context.tr('Episode downloads'),
              subtitle: _networkModeLabel(context, settings.allowMobileData),
              value: settings.allowMobileData,
              onChanged: (enabled) => ref
                  .read(settingsProvider.notifier)
                  .setAllowMobileData(enabled),
            ),
            const SizedBox(height: 12),
            _SwitchCard(
              label: context.tr('Streaming'),
              subtitle: _networkModeLabel(
                context,
                settings.allowMobileStreaming,
              ),
              value: settings.allowMobileStreaming,
              onChanged: (enabled) => ref
                  .read(settingsProvider.notifier)
                  .setAllowMobileStreaming(enabled),
            ),
            const SizedBox(height: 12),
            _SwitchCard(
              label: context.tr('Refresh'),
              subtitle: _networkModeLabel(context, settings.allowMobileRefresh),
              value: settings.allowMobileRefresh,
              onChanged: (enabled) => ref
                  .read(settingsProvider.notifier)
                  .setAllowMobileRefresh(enabled),
            ),
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
                'Eco mode limits network requests. Covers already saved or cached stay visible. New covers are not downloaded: the name appears in white on a square colored from the podcast name. In small lists a leaf sits in the center. Dark theme and pure black turn on with Eco mode and return to their previous setting when it is turned off. Automatic cover downloads stop, and the player no longer fetches a cover only to tint the screen.',
              ),
              style: title.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
                    child: step >= 2
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
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = subtitle;
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
        subtitle: caption == null ? null : Text(caption),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

String _networkModeLabel(BuildContext context, bool unrestricted) {
  return context.tr(unrestricted ? 'Wi-Fi and mobile data' : 'Wi-Fi only');
}

class _RestoreBackupPage extends StatelessWidget {
  const _RestoreBackupPage({required this.onBack, required this.onRestore});

  final VoidCallback onBack;
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
                  SizedBox(
                    width: double.infinity,
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
