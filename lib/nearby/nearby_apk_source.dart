import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_release.dart';

const _channelName = 'fr.podavio.podavio/nearby_share';

/// APK prêt à être servi en local.
class NearbyShareableApk {
  const NearbyShareableApk({required this.file, required this.versionLabel});

  final File file;
  final String versionLabel;
}

/// Impossible de produire un APK unique partageable.
enum NearbyApkFailure {
  unsupportedPlatform,
  splitsWithoutCache,
  downloadFailed,
  missingFile,
}

class NearbyApkException implements Exception {
  NearbyApkException(this.failure, [this.detail]);

  final NearbyApkFailure failure;
  final String? detail;

  @override
  String toString() => 'NearbyApkException($failure${detail == null ? '' : ': $detail'})';
}

/// Prépare un APK unique pour le partage à proximité (Android).
class NearbyApkSource {
  NearbyApkSource({
    MethodChannel? channel,
    this._client,
  }) : _channel = channel ?? const MethodChannel(_channelName);

  final MethodChannel _channel;
  final http.Client? _client;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<File> _cacheFile() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'nearby'));
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'podavio-universal.apk'));
  }

  Future<NearbyShareableApk> prepare({
    required String versionLabel,
    void Function(double progress)? onProgress,
  }) async {
    if (!isSupported) {
      throw NearbyApkException(NearbyApkFailure.unsupportedPlatform);
    }

    final info = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getInstallApkInfo',
    );
    final sourceDir = info?['sourceDir'] as String?;
    final hasSplits = info?['hasSplits'] == true;

    if (!hasSplits && sourceDir != null && sourceDir.isNotEmpty) {
      final source = File(sourceDir);
      if (!await source.exists()) {
        throw NearbyApkException(NearbyApkFailure.missingFile, sourceDir);
      }
      final dest = await _cacheFile();
      await source.copy(dest.path);
      onProgress?.call(1);
      return NearbyShareableApk(file: dest, versionLabel: versionLabel);
    }

    final cached = await _cacheFile();
    if (await cached.exists() && await cached.length() > 0) {
      onProgress?.call(1);
      return NearbyShareableApk(file: cached, versionLabel: versionLabel);
    }

    final downloaded = await _downloadUniversal(cached, onProgress: onProgress);
    if (downloaded != null) {
      return NearbyShareableApk(file: downloaded, versionLabel: versionLabel);
    }

    throw NearbyApkException(
      hasSplits
          ? NearbyApkFailure.splitsWithoutCache
          : NearbyApkFailure.downloadFailed,
    );
  }

  Future<File?> _downloadUniversal(
    File dest, {
    void Function(double progress)? onProgress,
  }) async {
    final release = await fetchLatestRelease();
    final uri = release?.fileUri('android-universal');
    if (uri == null) return null;

    final client = _client ?? http.Client();
    final owned = _client == null;
    try {
      final request = http.Request('GET', uri);
      request.headers['User-Agent'] = 'Podavio';
      final response = await client.send(request).timeout(
        const Duration(minutes: 5),
      );
      if (response.statusCode != 200) return null;

      final total = response.contentLength ?? 0;
      final sink = dest.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        if (await dest.exists()) await dest.delete();
        rethrow;
      }
      onProgress?.call(1);
      return dest;
    } catch (_) {
      if (await dest.exists()) await dest.delete();
      return null;
    } finally {
      if (owned) client.close();
    }
  }
}
