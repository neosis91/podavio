import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/build_info.dart';
import '../l10n/l10n.dart';
import '../nearby/nearby_apk_server.dart';
import '../nearby/nearby_apk_source.dart';
import 'widgets/frosted_header.dart';
import 'widgets/messages.dart';

/// Partage l’APK Podavio sur le LAN (même Wi‑Fi ou hotspot manuel).
class NearbySharePage extends StatefulWidget {
  const NearbySharePage({super.key});

  @override
  State<NearbySharePage> createState() => _NearbySharePageState();
}

class _NearbySharePageState extends State<NearbySharePage>
    with WidgetsBindingObserver {
  final _source = NearbyApkSource();
  NearbyApkServer? _server;
  var _busy = false;
  double? _progress;
  String? _url;
  String? _errorKey;
  String? _versionLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopServer());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_stopServer());
      if (mounted) {
        setState(() {
          _url = null;
          _server = null;
          _errorKey =
              'Sharing stops when you leave this screen or switch apps.';
        });
      }
    }
  }

  Future<void> _start() async {
    if (!_source.isSupported) {
      setState(() => _errorKey = 'Share nearby is only available on Android');
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _errorKey = null;
      _url = null;
    });
    try {
      final packaged = await PackageInfo.fromPlatform();
      final version = BuildInfo.version.isNotEmpty
          ? BuildInfo.version
          : packaged.version;
      _versionLabel = version;

      final apk = await _source.prepare(
        versionLabel: version,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      final server = await NearbyApkServer.start(
        apkFile: apk.file,
        versionLabel: apk.versionLabel,
      );
      final addresses = await lanIpv4Addresses();
      if (addresses.isEmpty) {
        await server.close();
        if (!mounted) return;
        setState(() {
          _errorKey =
              'Turn on a hotspot or join the same Wi-Fi, then try again';
          _busy = false;
          _progress = null;
        });
        return;
      }
      final url = 'http://${addresses.first.address}:${server.port}/';
      if (!mounted) {
        await server.close();
        return;
      }
      setState(() {
        _server = server;
        _url = url;
        _busy = false;
        _progress = null;
      });
    } on NearbyApkException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorKey = _failureMessage(e.failure);
        _busy = false;
        _progress = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorKey = 'Could not start nearby sharing';
        _busy = false;
        _progress = null;
      });
    }
  }

  String _failureMessage(NearbyApkFailure failure) {
    return switch (failure) {
      NearbyApkFailure.unsupportedPlatform =>
        'Share nearby is only available on Android',
      NearbyApkFailure.splitsWithoutCache =>
        'This install cannot be shared offline. Download Podavio once from podavio.com while online, then try again.',
      NearbyApkFailure.downloadFailed =>
        'Could not download a shareable APK. Check your connection and try again.',
      NearbyApkFailure.missingFile =>
        'Could not find the installed APK on this device.',
    };
  }

  Future<void> _stopServer() async {
    final server = _server;
    _server = null;
    await server?.close();
  }

  Future<void> _stopAndLeave() async {
    await _stopServer();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _copyUrl() async {
    final url = _url;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      showMessage(context, context.tr('Link copied'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FrostedScaffold(
      appBar: FrostedAppBar(
        title: Text(context.tr('Share Podavio nearby')),
      ),
      body: ListView(
        padding: belowFrostedBar(
          context,
          const EdgeInsets.fromLTRB(24, 16, 24, 32),
        ),
        children: [
          Text(
            context.tr(
              'Turn on a hotspot or join the same Wi-Fi. The other phone scans the QR code, opens the page, and installs Podavio. No internet needed.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (_busy) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 12),
            Text(
              context.tr('Preparing Podavio…'),
              style: theme.textTheme.bodySmall,
            ),
          ] else if (_errorKey != null) ...[
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(_errorKey!),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _start,
              child: Text(context.tr('Try again')),
            ),
          ] else if (_url != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _url!,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              _url!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: const Color(0xFF1F6B48),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_versionLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('Version {version}', {'version': _versionLabel!}),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _copyUrl,
              icon: const Icon(Icons.copy),
              label: Text(context.tr('Copy link')),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _stopAndLeave,
              child: Text(context.tr('Stop sharing')),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(
                'Sharing stops when you leave this screen or switch apps.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
