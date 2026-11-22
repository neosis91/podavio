import 'dart:convert';
import 'dart:typed_data';

/// Passage qu’on peut sauter dans un épisode.
enum SkipSegmentKind { intro, outro, sponsor, ad, jingle, selfPromo, other }

/// D’où vient le passage.
enum SkipSegmentSource {
  /// Empreinte audio partagée entre épisodes du même podcast.
  fingerprint,

  /// Titre de chapitre qui ressemble à une pub ou un sponsor.
  chapter,

  /// Posé à la main.
  manual,

  /// Virgule de réseau (pré-roll ou post-roll délimité par un sting).
  network,
}

/// Chapitre de contenu quand le podcast n’a pas donné de titre.
const episodeChapterLabel = 'Episode';

/// Clé anglaise affichée pour [kind] (traduite par l’interface).
String skipKindLabel(SkipSegmentKind kind) {
  switch (kind) {
    case SkipSegmentKind.intro:
      return 'Intro start';
    case SkipSegmentKind.outro:
      return 'Outro end';
    case SkipSegmentKind.sponsor:
      return 'Sponsor';
    case SkipSegmentKind.ad:
      return 'Ad';
    case SkipSegmentKind.jingle:
      return 'Jingle';
    case SkipSegmentKind.selfPromo:
      return 'Self-promo';
    case SkipSegmentKind.other:
      return 'Other';
  }
}

/// Clé anglaise du chapitre posé sur un passage détecté.
///
/// L’intro et l’outro ont ici un libellé court. Une virgule apprise
/// (jingle de source réseau) ne porte pas le même nom qu’un jingle.
String detectedChapterLabel(
  SkipSegmentKind kind, {
  SkipSegmentSource source = SkipSegmentSource.fingerprint,
}) {
  if (kind == SkipSegmentKind.jingle && source == SkipSegmentSource.network) {
    return 'Network sting';
  }
  switch (kind) {
    case SkipSegmentKind.intro:
      return 'Intro';
    case SkipSegmentKind.outro:
      return 'Outro';
    default:
      return skipKindLabel(kind);
  }
}

/// Liste JSON des noms d’enum (`["ad","sponsor"]`). Une valeur illisible
/// donne une liste vide.
List<SkipSegmentKind> decodeAutoSkipKinds(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final kinds = <SkipSegmentKind>[];
    for (final item in decoded) {
      if (item is! String) continue;
      for (final kind in SkipSegmentKind.values) {
        if (kind.name == item) {
          if (!kinds.contains(kind)) kinds.add(kind);
          break;
        }
      }
    }
    return kinds;
  } catch (_) {
    return const [];
  }
}

/// Encode [kinds] en JSON, sans doublon, dans l’ordre donné.
String encodeAutoSkipKinds(Iterable<SkipSegmentKind> kinds) {
  final names = <String>[];
  for (final kind in kinds) {
    if (!names.contains(kind.name)) names.add(kind.name);
  }
  return jsonEncode(names);
}

/// Blob little-endian des valeurs uint32 d’une empreinte Chromaprint.
Uint8List encodeFingerprint(List<int> values) {
  final data = Uint8List(values.length * 4);
  final view = ByteData.sublistView(data);
  for (var i = 0; i < values.length; i++) {
    view.setUint32(i * 4, values[i], Endian.little);
  }
  return data;
}

/// Inverse de [encodeFingerprint]. Les octets en trop (pas un multiple de 4)
/// sont ignorés.
List<int> decodeFingerprint(Uint8List data) {
  final view = ByteData.sublistView(data);
  final count = data.lengthInBytes ~/ 4;
  return [for (var i = 0; i < count; i++) view.getUint32(i * 4, Endian.little)];
}

/// Vrai pour un blob Chromaprint utilisable. Un blob qui commence par
/// `Olaf` vient de l’ancien détecteur : l’épisode est réempreinté, et le
/// gabarit est retaillé dans la nouvelle empreinte.
bool isChromaprintPrint(Uint8List data) {
  if (data.lengthInBytes < 32 || data.lengthInBytes % 4 != 0) return false;
  return !(data[0] == 0x4F &&
      data[1] == 0x6C &&
      data[2] == 0x61 &&
      data[3] == 0x66);
}
