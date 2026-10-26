import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/l10n.dart';
import '../web_companion/web_companion_controller.dart';

class WebCompanionPage extends ConsumerStatefulWidget {
  const WebCompanionPage({super.key});

  @override
  ConsumerState<WebCompanionPage> createState() => _WebCompanionPageState();
}

class _WebCompanionPageState extends ConsumerState<WebCompanionPage> {
  var _scanning = false;

  bool get _canScan =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final link = ref.watch(webCompanionProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Podavio Web'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            context.tr(
              'Open your library in the browser. The phone keeps the data, encrypted end to end.',
            ),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (!link.linked) ...[
            if (_scanning && _canScan)
              SizedBox(
                height: 280,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final raw = capture.barcodes.firstOrNull?.rawValue;
                      if (raw == null || raw.isEmpty) return;
                      setState(() => _scanning = false);
                      ref.read(webCompanionProvider.notifier).pair(raw);
                    },
                  ),
                ),
              )
            else
              FilledButton(
                onPressed: _canScan
                    ? () => setState(() => _scanning = true)
                    : null,
                child: Text(context.tr('Scan the code')),
              ),
            if (!_canScan) ...[
              const SizedBox(height: 12),
              Text(context.tr('Scanning is available on the phone')),
            ],
          ] else ...[
            Text(
              link.browserOnline
                  ? context.tr('Browser connected')
                  : context.tr('Waiting for the browser'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (link.fingerprint != null) ...[
              const SizedBox(height: 16),
              Text(context.tr('Safety number')),
              const SizedBox(height: 6),
              SelectableText(
                link.fingerprint!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 1,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              context.tr(
                'On iOS, keep Podavio open. On Android, a notification keeps the link.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () =>
                  ref.read(webCompanionProvider.notifier).disconnect(),
              child: Text(context.tr('Disconnect')),
            ),
          ],
          if (link.error == 'invalid') ...[
            const SizedBox(height: 16),
            Text(
              context.tr('This code cannot be used'),
              style: TextStyle(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
