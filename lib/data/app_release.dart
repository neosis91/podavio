import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/build_info.dart';
import '../core/release_version.dart';
import 'providers.dart';

const latestReleaseUrl = 'https://podavio.com/latest.json';
const downloadPageUrl = 'https://podavio.com/telecharger/';

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

  /// Chemins relatifs sous podavio.com, ex. `android-universal`.
  final Map<String, String> files;

  /// URL absolue d’un artefact, ou null.
  Uri? fileUri(String key) {
    final relative = files[key]?.trim();
    if (relative == null || relative.isEmpty) return null;
    return Uri.parse('https://podavio.com/$relative');
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
}

/// Dernière publication sur podavio.com, sans comparer à la version locale.
Future<AppRelease?> fetchLatestRelease() async {
  final client = http.Client();
  try {
    final response = await client
        .get(
          Uri.parse(latestReleaseUrl),
          headers: const {'User-Agent': 'Podavio'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    return AppRelease.tryParse(response.body);
  } catch (_) {
    return null;
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

/// Interroge podavio.com. Une installation sans `PODAVIO_VERSION` n’est pas
/// comparée : `0.1.0` serait toujours en retard sur le site.
Future<AppUpdateLookup> lookupAppUpdate() async {
  final client = http.Client();
  try {
    final response = await client
        .get(
          Uri.parse(latestReleaseUrl),
          headers: const {'User-Agent': 'Podavio'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return const AppUpdateFailed();
    final latest = AppRelease.tryParse(response.body);
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

/// Publication plus récente sur podavio.com, ou rien.
///
/// Les lancements locaux n’ont pas `PODAVIO_VERSION` : on ne les prévient pas,
/// sinon `0.1.0` serait toujours en retard sur le site. L’heure est quand même
/// retenue quand le site a répondu.
final appUpdateProvider = FutureProvider<AppRelease?>((ref) async {
  final lookup = await lookupAppUpdate();
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
