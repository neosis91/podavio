import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/build_info.dart';
import '../core/release_version.dart';

const latestReleaseUrl = 'https://podavio.com/latest.json';
const downloadPageUrl = 'https://podavio.com/telecharger/';

class AppRelease {
  const AppRelease({required this.version, this.date, this.notes = const []});

  final String version;
  final DateTime? date;
  final List<String> notes;

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
      return AppRelease(version: version.trim(), date: date, notes: notes);
    } catch (_) {
      return null;
    }
  }
}

/// Publication plus récente sur podavio.com, ou rien.
///
/// Les lancements locaux n’ont pas `PODAVIO_VERSION` : on ne les prévient pas,
/// sinon `0.1.0` serait toujours en retard sur le site.
final appUpdateProvider = FutureProvider<AppRelease?>((ref) async {
  final current = BuildInfo.version;
  if (current.isEmpty) return null;
  final client = http.Client();
  try {
    final response = await client
        .get(
          Uri.parse(latestReleaseUrl),
          headers: const {'User-Agent': 'Podavio'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final latest = AppRelease.tryParse(response.body);
    if (latest == null || !isNewerRelease(current, latest.version)) {
      return null;
    }
    return latest;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
});
