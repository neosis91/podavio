import 'dart:convert';
import 'dart:io';

/// Langues traduites. L’anglais est la source, dans l10n/en.json.
const _languages = <String>[
  'fr',
  'de',
  'es',
  'it',
  'pt',
  'nl',
  'zh',
  'hi',
  'id',
  'ja',
  'ko',
  'ru',
  'tr',
  'ar',
  'pl',
];

final _placeholder = RegExp(r'\{[A-Za-z0-9_]+\}');

/// Relit l10n/*.json et réécrit lib/l10n/messages.dart.
Future<void> main() async {
  final root = _root();
  final errors = <String>[];
  final en = _read(File('${root.path}/l10n/en.json'), errors, 'en');
  for (final entry in en.entries) {
    if (entry.value != entry.key) {
      errors.add('en : « ${entry.key} » ne correspond pas à sa clé.');
    }
  }

  final translated = <String, Map<String, String>>{};
  for (final code in _languages) {
    final map = _read(File('${root.path}/l10n/$code.json'), errors, code);
    final kept = <String, String>{};
    for (final entry in map.entries) {
      if (!en.containsKey(entry.key)) {
        errors.add('$code : clé inconnue « ${entry.key} ».');
        continue;
      }
      final missing = _placeholders(entry.key)
          .difference(_placeholders(entry.value));
      if (missing.isNotEmpty) {
        errors.add('$code : « ${entry.key} » retire ${missing.join(', ')}.');
      }
      kept[entry.key] = entry.value;
    }
    translated[code] = kept;
  }

  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
    return;
  }

  final out = File('${root.path}/lib/l10n/messages.dart');
  out.writeAsStringSync(_dart(translated));
  final format = await Process.run('dart', ['format', out.path]);
  if (format.exitCode != 0) {
    stderr.write(format.stderr);
    exitCode = format.exitCode;
    return;
  }
  stdout.writeln('Écrit ${out.path}.');
}

Map<String, String> _read(File file, List<String> errors, String code) {
  if (!file.existsSync()) {
    errors.add('$code : fichier manquant (${file.path}).');
    return const {};
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    errors.add('$code : le fichier n’est pas un objet JSON.');
    return const {};
  }
  final map = <String, String>{};
  for (final entry in decoded.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || value is! String) {
      errors.add('$code : clé ou valeur non textuelle.');
      continue;
    }
    map[key] = value;
  }
  final sorted = map.keys.toList()..sort();
  return {for (final key in sorted) key: map[key]!};
}

Set<String> _placeholders(String text) {
  return {for (final match in _placeholder.allMatches(text)) match.group(0)!};
}

String _dart(Map<String, Map<String, String>> translated) {
  final buffer = StringBuffer()
    ..writeln('// Généré par tool/l10n_generate.dart. Ne pas modifier.')
    ..writeln('/// Traductions de l’interface. La clé est le texte anglais.')
    ..writeln('const interfaceMessages = <String, Map<String, String>>{');
  for (final code in _languages) {
    buffer.writeln("  '$code': _$code,");
  }
  buffer.writeln('};');
  for (final code in _languages) {
    buffer
      ..writeln()
      ..writeln('const _$code = <String, String>{');
    for (final entry in translated[code]!.entries) {
      buffer.writeln('  ${_quote(entry.key)}: ${_quote(entry.value)},');
    }
    buffer.writeln('};');
  }
  return buffer.toString();
}

String _quote(String value) {
  return "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\r', r'\r').replaceAll('\n', r'\n')}'";
}

Directory _root() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('pubspec.yaml introuvable.');
    }
    dir = parent;
  }
}
