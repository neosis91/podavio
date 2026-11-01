import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/l10n.dart';
import '../web_companion/web_companion_controller.dart';
import 'browser_logo.dart';
import 'router.dart';

class WebCompanionPage extends ConsumerWidget {
  const WebCompanionPage({super.key});

  bool get _canScan =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(webCompanionProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Linked devices'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          const _LinkArt(),
          const SizedBox(height: 28),
          if (!link.linked)
            Text(
              context.tr('Use Podavio on another screen'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
          if (!link.linked) const SizedBox(height: 12),
          Text(
            context.tr(
              'You can connect a browser to this phone. The library stays here, encrypted end to end.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            onPressed: _canScan
                ? () => context.push(AppRoutes.webCompanionScan)
                : null,
            child: Text(context.tr('Connect a device')),
          ),
          if (!_canScan) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('Scanning is available on the phone'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (link.linked) ...[
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              context.tr('Device status').toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('Tap a device to view it or disconnect it.'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: LinkedDeviceMark(browser: link.browser, os: link.os),
              title: Text(
                linkedDeviceLabel(link.browser, link.os) ??
                    context.tr('Podavio Web'),
              ),
              subtitle: Text(
                link.browserOnline
                    ? context.tr('Browser connected')
                    : context.tr('Waiting for the browser'),
              ),
              onTap: () => context.push(AppRoutes.webCompanionDevice),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.tr('Your library stays encrypted end to end.'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WebCompanionScanPage extends ConsumerStatefulWidget {
  const WebCompanionScanPage({super.key});

  @override
  ConsumerState<WebCompanionScanPage> createState() =>
      _WebCompanionScanPageState();
}

class _WebCompanionScanPageState extends ConsumerState<WebCompanionScanPage> {
  var _busy = false;

  bool get _canScan =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pair(String raw) async {
    await ref.read(webCompanionProvider.notifier).pair(raw);
    if (!mounted) return;
    final link = ref.read(webCompanionProvider);
    if (link.linked && link.error == null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.webCompanion);
      }
      return;
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final link = ref.watch(webCompanionProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Scan the QR code'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Text(
              context.tr(
                'Open web.podavio.com on a computer, then scan the code.',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortest = constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight;
                final window = Rect.fromCenter(
                  center: Offset(
                    constraints.maxWidth / 2,
                    constraints.maxHeight / 2,
                  ),
                  width: shortest * 0.68,
                  height: shortest * 0.68,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: _busy || !_canScan
                          ? const SizedBox.expand()
                          : MobileScanner(
                              scanWindow: window,
                              onDetect: (capture) {
                                if (_busy) return;
                                final raw =
                                    capture.barcodes.firstOrNull?.rawValue;
                                if (raw == null || raw.isEmpty) return;
                                setState(() => _busy = true);
                                _pair(raw);
                              },
                            ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ScanShadePainter(window: window),
                        ),
                      ),
                    ),
                    if (_busy) const Center(child: CircularProgressIndicator()),
                    if (!_busy && !_canScan)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            context.tr('Scanning is available on the phone'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    if (link.error == 'invalid')
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 24,
                        child: Text(
                          context.tr('This code cannot be used'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanShadePainter extends CustomPainter {
  const _ScanShadePainter({required this.window});

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(window, const Radius.circular(12));
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0x52000000))
      ..drawRRect(cutout, Paint()..blendMode = BlendMode.clear)
      ..restore()
      ..drawRRect(
        cutout,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xB3FFFFFF),
      );
  }

  @override
  bool shouldRepaint(_ScanShadePainter oldDelegate) =>
      oldDelegate.window != window;
}

class WebCompanionDevicePage extends ConsumerWidget {
  const WebCompanionDevicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(webCompanionProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = linkedDeviceLabel(link.browser, link.os);
    return Scaffold(
      appBar: AppBar(title: Text(label ?? context.tr('Podavio Web'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          Center(
            child: LinkedDeviceMark(
              browser: link.browser,
              os: link.os,
              size: 72,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label ?? context.tr('Podavio Web'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            label == null ? context.tr('Browser') : context.tr('Device name'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(
              link.browserOnline
                  ? context.tr('Browser connected')
                  : context.tr('Waiting for the browser'),
            ),
          ),
          if (link.fingerprint != null) ...[
            const SizedBox(height: 8),
            Text(context.tr('Safety number')),
            const SizedBox(height: 6),
            SelectableText(
              link.fingerprint!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 1,
              ),
            ),
          ],
          const SizedBox(height: 28),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error),
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              await ref.read(webCompanionProvider.notifier).disconnect();
              if (context.mounted && context.canPop()) context.pop();
            },
            child: Text(context.tr('Disconnect')),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('If you do not recognize this browser, disconnect it.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'On iOS, keep Podavio open. On Android, a notification keeps the link.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkArt extends StatelessWidget {
  const _LinkArt();

  @override
  Widget build(BuildContext context) {
    final green = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: IconTheme(
        data: IconThemeData(color: green),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.smartphone, size: 64),
            SizedBox(width: 8),
            Icon(Icons.sync_alt, size: 28),
            SizedBox(width: 8),
            Icon(Icons.laptop_mac, size: 72),
          ],
        ),
      ),
    );
  }
}
