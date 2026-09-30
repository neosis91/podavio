/// Nom affichable pour un paquet listé dans les licences.
String friendlyLicenseName(String package) {
  final known = _knownLicenseNames[package];
  if (known != null) return known;

  final raw = package.startsWith('_') ? package.substring(1) : package;
  final parts = raw
      .split(RegExp(r'[_\-]+'))
      .where((part) => part.isNotEmpty)
      .map(_titleLicenseWord)
      .toList();
  if (parts.isEmpty) return package;
  return parts.join(' ');
}

const _knownLicenseNames = <String, String>{
  'flutter': 'Flutter',
  'flutter_localizations': 'Flutter (localisations)',
  'flutter_test': 'Flutter Test',
  'flutter_web_plugins': 'Flutter Web Plugins',
  'sky_engine': 'Moteur Flutter',
  'cupertino_icons': 'Cupertino Icons',
  'material_color_utilities': 'Material Color Utilities',
  'meta': 'Dart Meta',
  'collection': 'Dart Collection',
  'characters': 'Dart Characters',
  'typed_data': 'Dart Typed Data',
  'async': 'Dart Async',
  'io': 'Dart IO',
  'path': 'Dart Path',
  'convert': 'Dart Convert',
  'crypto': 'Dart Crypto',
};

String _titleLicenseWord(String word) {
  final lower = word.toLowerCase();
  final special = _specialLicenseWords[lower];
  if (special != null) return special;
  if (_licenseAcronyms.contains(lower)) return lower.toUpperCase();
  if (word.length <= 1) return word.toUpperCase();
  return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
}

const _specialLicenseWords = <String, String>{
  'ios': 'iOS',
  'macos': 'macOS',
  'ipados': 'iPadOS',
  'github': 'GitHub',
  'gitlab': 'GitLab',
  'sqlite': 'SQLite',
  'youtube': 'YouTube',
  'javascript': 'JavaScript',
  'typescript': 'TypeScript',
};

const _licenseAcronyms = <String>{
  'sdk',
  'http',
  'https',
  'xml',
  'ui',
  'api',
  'db',
  'sql',
  'ffi',
  'json',
  'yaml',
  'rss',
  'opml',
  'svg',
  'png',
  'url',
  'uri',
  'id',
  'uuid',
  'html',
  'css',
  'mp3',
  'aac',
  'pdf',
  'ssh',
  'ssl',
  'tls',
  'cpu',
  'gpu',
  'wasm',
  'saf',
};

/// Extrait les titulaires de copyright depuis le texte d'une licence.
List<String> extractLicenseCreators(String license) {
  final found = <String>[];
  final patterns = [
    RegExp(
      r'^Copyright\s*(?:\(c\)|©)?\s*(?:\d{4}(?:\s*[-–—,/]\s*\d{4})?[,.]?\s+)+(.+)$',
      caseSensitive: false,
    ),
    RegExp(r'^Copyright\s*(?:\(c\)|©)\s*(.+)$', caseSensitive: false),
    RegExp(r'^©\s*(?:\d{4}(?:\s*[-–—,/]\s*\d{4})?[,.]?\s+)?(.+)$'),
  ];
  for (final raw in license.split('\n').take(30)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      var name = match.group(1)!.trim();
      name = name
          .replaceAll(
            RegExp(r'[.,]?\s*All rights reserved\.?$', caseSensitive: false),
            '',
          )
          .replaceAll(RegExp(r'\.$'), '')
          .trim();
      if (name.isEmpty || name.length > 120) break;
      if (!found.contains(name)) found.add(name);
      break;
    }
  }
  return found;
}
