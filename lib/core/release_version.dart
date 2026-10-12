/// Vrai quand [tag] désigne une publication plus récente que [current].
///
/// Les numéros se comparent un par un, donc `2026.10.11` est plus récent que
/// `2026.10.6`. Un suffixe (`-hf`, `-dev`) ne change pas les numéros : seul le
/// nom distingue un correctif de la version qu’il remplace.
bool isNewerRelease(String current, String tag) {
  final running = _stripDev(_bare(current));
  final release = _stripDev(_bare(tag));
  if (running.isEmpty || release.isEmpty) return false;
  return release != running && compareVersions(running, release) <= 0;
}

/// Comparaison de versions pointées, nombre par nombre.
int compareVersions(String a, String b) {
  final left = _numbers(a);
  final right = _numbers(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final x = i < left.length ? left[i] : 0;
    final y = i < right.length ? right[i] : 0;
    final diff = x.compareTo(y);
    if (diff != 0) return diff;
  }
  return 0;
}

String _bare(String version) {
  final trimmed = version.trim();
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return trimmed.substring(1);
  }
  return trimmed;
}

String _stripDev(String version) {
  if (version.endsWith('-dev')) {
    return version.substring(0, version.length - 4);
  }
  return version;
}

List<int> _numbers(String version) {
  final head = version.split('-').first;
  return [for (final part in head.split('.')) int.tryParse(part.trim()) ?? 0];
}
