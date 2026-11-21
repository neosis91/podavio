import 'dart:io';
import 'dart:typed_data';

/// Pas d’une empreinte Chromaprint à ~8 valeurs par seconde.
const chromaprintHopMicros = 125000;

/// Analyse les fichiers déjà téléchargés pour repérer pubs, sponsors
/// et jingles. Seuils et classement : `lib/data/segment_match.dart`,
/// récit dans `docs/ad-skip.md`.
///
/// Une fois un jingle retenu, il est stocké comme gabarit du podcast
/// (tranche d’empreinte + log-mel). Les épisodes suivants ne cherchent
/// que ce gabarit.
abstract class EpisodeAudioAnalyzer {
  /// Empreinte binaire (uint32 little-endian). `null` tant que le
  /// décodage n’est pas branché, ou si le fichier est illisible.
  Future<Uint8List?> computeFingerprint(File file);

  /// Cherche les passages répétés de [podcastId] et les enregistre.
  /// L’implémentation de base ne fait rien.
  Future<void> findSegments(int podcastId);
}

/// Place nette, pour les tests. L’application branche le moteur
/// Chromaprint de `audio_analysis.dart`.
class PlaceholderEpisodeAudioAnalyzer implements EpisodeAudioAnalyzer {
  const PlaceholderEpisodeAudioAnalyzer();

  @override
  Future<Uint8List?> computeFingerprint(File file) async => null;

  @override
  Future<void> findSegments(int podcastId) async {}
}
