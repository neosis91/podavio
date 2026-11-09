/// Pliage pour recherche locale : minuscules + sans diacritiques (é→e, œ→oe…).
String foldForSearch(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folds[char] ?? char);
  }
  return buffer.toString();
}

/// Motif `LIKE` pour une recherche déjà pliée. `%` et `_` restent littéraux.
String foldedLikePattern(String needle) {
  final folded = foldForSearch(needle);
  final escaped = folded
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
  return '%$escaped%';
}

/// `true` si [haystack] contient [needle] sans tenir compte casse / accents.
bool searchMatch(String haystack, String needle) {
  final foldedNeedle = foldForSearch(needle.trim());
  if (foldedNeedle.isEmpty) return true;
  return foldForSearch(haystack).contains(foldedNeedle);
}

/// Pliage avec index d’origine (unités UTF-16 de [value.toLowerCase()]) par
/// caractère plié — pour surligner dans le texte d’origine.
({String folded, List<int> origins}) foldForSearchMapped(String value) {
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  final origins = <int>[];
  var offset = 0;
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final folded = _folds[char] ?? char;
    for (var i = 0; i < folded.length; i++) {
      buffer.writeCharCode(folded.codeUnitAt(i));
      origins.add(offset);
    }
    offset += char.length;
  }
  return (folded: buffer.toString(), origins: origins);
}

/// Fin exclusive (UTF-16) dans [lower] pour une plage pliée `[foldStart, foldStart + foldLen)`.
int foldedMatchEndExclusive(
  String lower,
  List<int> origins,
  int foldStart,
  int foldLen,
) {
  if (foldLen <= 0 || origins.isEmpty) return foldStart;
  var maxOrigin = origins[foldStart];
  final end = foldStart + foldLen;
  for (var i = foldStart; i < end; i++) {
    final origin = origins[i];
    if (origin > maxOrigin) maxOrigin = origin;
  }
  if (maxOrigin >= lower.length) return lower.length;
  final unit = lower.codeUnitAt(maxOrigin);
  final charLen = unit >= 0xD800 && unit <= 0xDBFF ? 2 : 1;
  return maxOrigin + charLen;
}

const _folds = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'œ': 'oe',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
};
