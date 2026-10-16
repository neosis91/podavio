import '../../data/app_database.dart';

EpisodeChapter? currentChapterFor(
  List<EpisodeChapter> chapters,
  Duration position,
) {
  if (chapters.isEmpty) return null;
  final ms = position.inMilliseconds;
  EpisodeChapter? current;
  for (final chapter in chapters) {
    if (chapter.startMs <= ms) {
      current = chapter;
    } else {
      break;
    }
  }
  return current;
}
