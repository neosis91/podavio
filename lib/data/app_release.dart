import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/build_info.dart';
import '../core/release_version.dart';
import 'providers.dart';

const githubLatestReleaseUrl =
    'https://api.github.com/repos/neosis91/podavio/releases/latest';
const latestReleaseUrl = 'https://podavio.com/latest.json';
const downloadPageUrl = 'https://podavio.com/download';

const _githubAssetSuffixes = {
  'android-arm64-v8a': '-android-arm64-v8a.apk',
  'android-armeabi-v7a': '-android-armeabi-v7a.apk',
  'android-x86_64': '-android-x86_64.apk',
  'android-universal': '-android-universal.apk',
  'linux-x64': '-linux-x64.tar.gz',
};

class AppRelease {
  const AppRelease({
    required this.version,
    this.date,
    this.notes = const [],
    this.files = const {},
  });

  final String version;
  final DateTime? date;
  final List<String> notes;

  /// URL absolue, ou chemin relatif sous podavio.com.
  final Map<String, String> files;

  /// URL de téléchargement d’un artefact, ou null.
  Uri? fileUri(String key) {
    final value = files[key]?.trim();
    if (value == null || value.isEmpty) return null;
    final absolute = Uri.tryParse(value);
    if (absolute != null && absolute.hasScheme) return absolute;
    return Uri.parse('https://podavio.com/$value');
  }

  static AppRelease? tryParse(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return null;
      final version = json['version'];
      if (version is! String || version.trim().isEmpty) return null;
      final rawDate = json['date'];
      final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
      final notes = <String>[];
      final rawNotes = json['notes'];
      if (rawNotes is List) {
        for (final note in rawNotes) {
          if (note is String && note.trim().isNotEmpty) notes.add(note.trim());
        }
      }
      final files = <String, String>{};
      final rawFiles = json['files'];
      if (rawFiles is Map) {
        rawFiles.forEach((key, value) {
          if (key is String && value is String && value.trim().isNotEmpty) {
            files[key] = value.trim();
          }
        });
      }
      return AppRelease(
        version: version.trim(),
        date: date,
        notes: notes,
        files: files,
      );
    } catch (_) {
      return null;
    }
  }

  /// Release GitHub : les fichiers sont les `browser_download_url`.
  static AppRelease? tryParseGitHub(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return null;
      final tag = json['tag_name'];
      if (tag is! String || tag.trim().isEmpty) return null;
      final version = tag.trim().replaceFirst(RegExp(r'^v'), '');
      final published = json['published_at'];
      final date = published is String ? DateTime.tryParse(published) : null;
      final notes = <String>[];
      final rawBody = json['body'];
      if (rawBody is String) {
        for (final line in rawBody.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('- ')) {
            notes.add(trimmed.substring(2).trim());
          } else if (trimmed.startsWith('* ')) {
            notes.add(trimmed.substring(2).trim());
          }
        }
      }
      final files = <String, String>{};
      final assets = json['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is! Map) continue;
          final name = asset['name'];
          final url = asset['browser_download_url'];
          if (name is! String || url is! String || url.trim().isEmpty) continue;
          for (final entry in _githubAssetSuffixes.entries) {
            if (name.endsWith(entry.value)) {
              files[entry.key] = url.trim();
            }
          }
        }
      }
      if (files.isEmpty) return null;
      return AppRelease(
        version: version,
        date: date?.toLocal(),
        notes: notes,
        files: files,
      );
    } catch (_) {
      return null;
    }
  }
}

Future<AppRelease?> _readRelease(http.Client client, Uri url) async {
  final response = await client
      .get(
        url,
        headers: const {
          'User-Agent': 'Podavio',
          'Accept': 'application/vnd.github+json',
        },
      )
      .timeout(const Duration(seconds: 12));
  if (response.statusCode != 200) return null;
  if (url.toString() == githubLatestReleaseUrl) {
    return AppRelease.tryParseGitHub(response.body);
  }
  return AppRelease.tryParse(response.body);
}

/// Dernière publication. Les fichiers viennent de la release GitHub.
/// Sans fichiers GitHub, la lecture retombe sur podavio.com.
Future<AppRelease?> fetchLatestRelease() async {
  final client = http.Client();
  try {
    final github = await _readRelease(
      client,
      Uri.parse(githubLatestReleaseUrl),
    );
    if (github != null) return github;
    return _readRelease(client, Uri.parse(latestReleaseUrl));
  } catch (_) {
    try {
      return _readRelease(client, Uri.parse(latestReleaseUrl));
    } catch (_) {
      return null;
    }
  } finally {
    client.close();
  }
}

/// Résultat d’une lecture de podavio.com.
sealed class AppUpdateLookup {
  const AppUpdateLookup();
}

/// Une publication plus récente existe.
class AppUpdateNewer extends AppUpdateLookup {
  const AppUpdateNewer(this.release);

  final AppRelease release;
}

/// La version installée est celle du site, ou plus récente.
class AppUpdateCurrent extends AppUpdateLookup {
  const AppUpdateCurrent();
}

/// Le serveur a répondu, mais cette installation n’a pas de version publiée.
class AppUpdateUnversioned extends AppUpdateLookup {
  const AppUpdateUnversioned(this.published);

  final AppRelease published;
}

/// Le site n’a pas répondu.
class AppUpdateFailed extends AppUpdateLookup {
  const AppUpdateFailed();
}

/// Interroge la release GitHub, puis podavio.com s’il n’y a pas encore de
/// fichiers. Une installation sans `PODAVIO_VERSION` n’est pas comparée :
/// `0.1.0` serait toujours en retard.
Future<AppUpdateLookup> lookupAppUpdate() async {
  final client = http.Client();
  try {
    AppRelease? latest;
    try {
      latest = await _readRelease(client, Uri.parse(githubLatestReleaseUrl));
    } catch (_) {}
    latest ??= await _readRelease(client, Uri.parse(latestReleaseUrl));
    if (latest == null) return const AppUpdateFailed();
    final current = BuildInfo.version;
    if (current.isEmpty) return AppUpdateUnversioned(latest);
    if (isNewerRelease(current, latest.version)) return AppUpdateNewer(latest);
    return const AppUpdateCurrent();
  } catch (_) {
    return const AppUpdateFailed();
  } finally {
    client.close();
  }
}

bool appUpdateWasChecked(AppUpdateLookup lookup) {
  return lookup is AppUpdateNewer ||
      lookup is AppUpdateCurrent ||
      lookup is AppUpdateUnversioned;
}

/// Lecture de podavio.com. Les tests peuvent la remplacer.
final appUpdateCheckerProvider = Provider<Future<AppUpdateLookup> Function()>(
  (ref) => lookupAppUpdate,
);

/// Publication plus récente sur podavio.com, ou rien.
///
/// Les lancements locaux n’ont pas `PODAVIO_VERSION` : on ne les prévient pas,
/// sinon `0.1.0` serait toujours en retard sur le site. L’heure est quand même
/// retenue quand le site a répondu.
final appUpdateProvider = FutureProvider<AppRelease?>((ref) async {
  final lookup = await ref.read(appUpdateCheckerProvider)();
  if (appUpdateWasChecked(lookup)) {
    await ref.read(appUpdateCheckedAtProvider.notifier).mark(DateTime.now());
  }
  return switch (lookup) {
    AppUpdateNewer(:final release) => release,
    _ => null,
  };
});

const appUpdateCheckedAtKey = 'appUpdateCheckedAt';

/// Moment de la dernière vérification aboutie.
final appUpdateCheckedAtProvider =
    NotifierProvider<AppUpdateCheckedAt, DateTime?>(AppUpdateCheckedAt.new);

class AppUpdateCheckedAt extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final ms = ref
        .watch(sharedPreferencesProvider)
        .getInt(appUpdateCheckedAtKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> mark(DateTime when) async {
    state = when;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(appUpdateCheckedAtKey, when.millisecondsSinceEpoch);
  }
}
