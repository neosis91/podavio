part of '../app_database.dart';

/// Segment sans modèle, avec le titre de l’épisode pour l’écran de revue.
class LooseSkipSegment {
  const LooseSkipSegment({
    required this.segment,
    required this.episodeTitle,
    required this.downloadPath,
  });

  final SkipSegment segment;
  final String episodeTitle;
  final String? downloadPath;
}

/// Modèles du podcast et passages qui n’y sont pas rattachés.
class SkipClassification {
  const SkipClassification({
    required this.templates,
    required this.segments,
    required this.templateConfirmed,
  });

  final List<SegmentTemplate> templates;
  final List<LooseSkipSegment> segments;

  /// `null` : pas revu ou avis partagé. `true` / `false` : tous les
  /// passages du modèle sont confirmés ou ignorés.
  final Map<int, bool?> templateConfirmed;
}

mixin _SkipSegmentQueries on _$AppDatabase {
  Future<void> upsertEpisodeFingerprint({
    required int episodeId,
    required Uint8List data,
    required int hopMicros,
    Uint8List? speech,
    DateTime? createdAt,
  }) {
    return into(episodeFingerprints).insertOnConflictUpdate(
      EpisodeFingerprintsCompanion.insert(
        episodeId: Value(episodeId),
        data: data,
        hopMicros: hopMicros,
        speech: speech == null ? const Value.absent() : Value(speech),
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<EpisodeFingerprint?> fingerprintForEpisode(int episodeId) {
    return (select(
      episodeFingerprints,
    )..where((table) => table.episodeId.equals(episodeId))).getSingleOrNull();
  }

  Future<int> insertSegmentTemplate({
    required int podcastId,
    required SkipSegmentKind kind,
    String? label,
    Uint8List? fingerprint,
    Uint8List? logMel,
    required int durationMs,
    int occurrences = 1,
    int? confidence,
    DateTime? createdAt,
  }) {
    return into(segmentTemplates).insert(
      SegmentTemplatesCompanion.insert(
        podcastId: podcastId,
        kind: kind,
        label: Value(label),
        fingerprint: fingerprint ?? Uint8List(0),
        logMel: Value(logMel),
        durationMs: durationMs,
        occurrences: Value(occurrences),
        confidence: Value(confidence),
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<int> insertSkipSegment({
    required int episodeId,
    required int startMs,
    required int endMs,
    required SkipSegmentKind kind,
    required SkipSegmentSource source,
    int matches = 1,
    bool? confirmed,
    int? confidence,
    int? templateId,
  }) {
    return into(skipSegments).insert(
      SkipSegmentsCompanion.insert(
        episodeId: episodeId,
        startMs: startMs,
        endMs: endMs,
        kind: kind,
        source: source,
        matches: Value(matches),
        confirmed: Value(confirmed),
        confidence: Value(confidence),
        templateId: Value(templateId),
      ),
    );
  }

  Future<List<SkipSegment>> listSkipSegments(int episodeId) {
    return (select(skipSegments)
          ..where((row) => row.episodeId.equals(episodeId))
          ..orderBy([(row) => OrderingTerm.asc(row.startMs)]))
        .get();
  }

  Stream<List<SegmentTemplate>> watchSegmentTemplates(int podcastId) {
    return (select(segmentTemplates)
          ..where((row) => row.podcastId.equals(podcastId))
          ..orderBy([
            (row) => OrderingTerm.asc(row.kind),
            (row) => OrderingTerm.asc(row.id),
          ]))
        .watch();
  }

  Stream<SkipClassification> watchSkipClassification(int podcastId) {
    return _combineSkip(
      watchSegmentTemplates(podcastId),
      _watchLooseSegments(podcastId),
      _watchTemplateReviews(podcastId),
      (templates, segments, reviews) => SkipClassification(
        templates: templates,
        segments: segments,
        templateConfirmed: reviews,
      ),
    );
  }

  Stream<List<LooseSkipSegment>> _watchLooseSegments(int podcastId) {
    final query =
        select(skipSegments).join([
            innerJoin(episodes, episodes.id.equalsExp(skipSegments.episodeId)),
          ])
          ..where(
            episodes.podcastId.equals(podcastId) &
                skipSegments.templateId.isNull(),
          )
          ..orderBy([
            OrderingTerm.asc(skipSegments.kind),
            OrderingTerm.asc(skipSegments.startMs),
          ]);
    return query.watch().map((rows) {
      return [
        for (final row in rows)
          LooseSkipSegment(
            segment: row.readTable(skipSegments),
            episodeTitle: row.read(episodes.title) ?? '',
            downloadPath: row.read(episodes.downloadPath),
          ),
      ];
    });
  }

  Stream<Map<int, bool?>> _watchTemplateReviews(int podcastId) {
    return customSelect(
      'SELECT s.template_id AS template_id, '
      'SUM(CASE WHEN s.confirmed IS NULL THEN 1 ELSE 0 END) AS pending, '
      'SUM(CASE WHEN s.confirmed = 1 THEN 1 ELSE 0 END) AS yes, '
      'SUM(CASE WHEN s.confirmed = 0 THEN 1 ELSE 0 END) AS no '
      'FROM skip_segments s '
      'INNER JOIN episodes e ON e.id = s.episode_id '
      'WHERE e.podcast_id = ? AND s.template_id IS NOT NULL '
      'GROUP BY s.template_id',
      variables: [Variable.withInt(podcastId)],
      readsFrom: {skipSegments, episodes},
    ).watch().map((rows) {
      return {
        for (final row in rows)
          row.read<int>('template_id'): _reviewOf(
            row.read<int>('pending'),
            row.read<int>('yes'),
            row.read<int>('no'),
          ),
      };
    });
  }

  /// Épisode téléchargé qui contient [templateId], pour l’écoute courte.
  Future<({int episodeId, int segmentId, int startMs})?>
  previewTargetForTemplate(int templateId) async {
    final query =
        select(skipSegments).join([
            innerJoin(episodes, episodes.id.equalsExp(skipSegments.episodeId)),
          ])
          ..where(
            skipSegments.templateId.equals(templateId) &
                episodes.downloadPath.isNotNull() &
                episodes.downloadPath.length.isBiggerThanValue(0),
          )
          ..orderBy([OrderingTerm.asc(episodes.id)])
          ..limit(1);
    final rows = await query.get();
    if (rows.isEmpty) return null;
    final segment = rows.single.readTable(skipSegments);
    return (
      episodeId: segment.episodeId,
      segmentId: segment.id,
      startMs: segment.startMs,
    );
  }

  Future<void> setSkipSegmentKind(int id, SkipSegmentKind kind) {
    return (update(skipSegments)..where((row) => row.id.equals(id))).write(
      SkipSegmentsCompanion(kind: Value(kind)),
    );
  }

  Future<void> setSkipSegmentReview(int id, {required bool? confirmed}) {
    return (update(skipSegments)..where((row) => row.id.equals(id))).write(
      SkipSegmentsCompanion(confirmed: Value(confirmed)),
    );
  }

  Future<void> deleteSkipSegment(int id) {
    return (delete(skipSegments)..where((row) => row.id.equals(id))).go();
  }

  Future<void> setTemplateKind(int id, SkipSegmentKind kind) {
    return transaction(() async {
      await (update(segmentTemplates)..where((row) => row.id.equals(id))).write(
        SegmentTemplatesCompanion(kind: Value(kind)),
      );
      await (update(skipSegments)..where((row) => row.templateId.equals(id)))
          .write(SkipSegmentsCompanion(kind: Value(kind)));
    });
  }

  Future<void> setTemplateLabel(int id, String? label) {
    final trimmed = label?.trim() ?? '';
    return (update(segmentTemplates)..where((row) => row.id.equals(id))).write(
      SegmentTemplatesCompanion(label: Value(trimmed.isEmpty ? null : trimmed)),
    );
  }

  Future<void> setTemplateReview(int id, {required bool confirmed}) {
    return (update(skipSegments)..where((row) => row.templateId.equals(id)))
        .write(SkipSegmentsCompanion(confirmed: Value(confirmed)));
  }

  /// Efface le modèle et les passages qui en dépendent.
  Future<void> deleteSegmentTemplate(int id) {
    return transaction(() async {
      await (delete(
        skipSegments,
      )..where((row) => row.templateId.equals(id))).go();
      await (delete(segmentTemplates)..where((row) => row.id.equals(id))).go();
    });
  }

  /// Remplace les passages `chapter` de l’épisode d’après ses chapitres.
  ///
  /// La fin d’un chapitre est le début du suivant, ou la durée de l’épisode
  /// pour le dernier. Un avis déjà posé sur le même début et le même type
  /// est conservé.
  Future<void> seedChapterSkipSegments(int episodeId) async {
    final chapters =
        await (select(episodeChapters)
              ..where((row) => row.episodeId.equals(episodeId))
              ..orderBy([
                (row) => OrderingTerm.asc(row.startMs),
                (row) => OrderingTerm.asc(row.sortIndex),
              ]))
            .get();
    final episode = await (select(
      episodes,
    )..where((table) => table.id.equals(episodeId))).getSingleOrNull();
    final durationMs = (episode?.durationSeconds ?? 0) * 1000;
    final previous =
        await (select(skipSegments)..where(
              (row) =>
                  row.episodeId.equals(episodeId) &
                  row.source.equalsValue(SkipSegmentSource.chapter),
            ))
            .get();
    final kept = <String, bool?>{
      for (final row in previous)
        '${row.startMs}:${row.kind.name}': row.confirmed,
    };
    await (delete(skipSegments)..where(
          (row) =>
              row.episodeId.equals(episodeId) &
              row.source.equalsValue(SkipSegmentSource.chapter),
        ))
        .go();
    final rows = <SkipSegmentsCompanion>[];
    for (var i = 0; i < chapters.length; i++) {
      final kind = skipKindForChapterTitle(chapters[i].title);
      if (kind == null) continue;
      final start = chapters[i].startMs;
      final next = i + 1 < chapters.length ? chapters[i + 1].startMs : null;
      final end = next ?? (durationMs > start ? durationMs : null);
      if (end == null || end <= start) continue;
      rows.add(
        SkipSegmentsCompanion.insert(
          episodeId: episodeId,
          startMs: start,
          endMs: end,
          kind: kind,
          source: SkipSegmentSource.chapter,
          confirmed: Value(kept['$start:${kind.name}']),
        ),
      );
    }
    if (rows.isEmpty) return;
    await batch((statement) => statement.insertAll(skipSegments, rows));
  }

  Future<List<SegmentTemplate>> listSegmentTemplates(int podcastId) {
    return (select(segmentTemplates)
          ..where((row) => row.podcastId.equals(podcastId))
          ..orderBy([(row) => OrderingTerm.asc(row.id)]))
        .get();
  }

  Future<Map<int, bool?>> templateReviews(int podcastId) async {
    final rows = await customSelect(
      'SELECT s.template_id AS template_id, '
      'SUM(CASE WHEN s.confirmed IS NULL THEN 1 ELSE 0 END) AS pending, '
      'SUM(CASE WHEN s.confirmed = 1 THEN 1 ELSE 0 END) AS yes, '
      'SUM(CASE WHEN s.confirmed = 0 THEN 1 ELSE 0 END) AS no '
      'FROM skip_segments s '
      'INNER JOIN episodes e ON e.id = s.episode_id '
      'WHERE e.podcast_id = ? AND s.template_id IS NOT NULL '
      'GROUP BY s.template_id',
      variables: [Variable.withInt(podcastId)],
      readsFrom: {skipSegments, episodes},
    ).get();
    return {
      for (final row in rows)
        row.read<int>('template_id'): _reviewOf(
          row.read<int>('pending'),
          row.read<int>('yes'),
          row.read<int>('no'),
        ),
    };
  }

  Future<List<({Episode episode, EpisodeFingerprint fingerprint})>>
  fingerprintedDownloads(int podcastId) async {
    final query =
        select(episodes).join([
          innerJoin(
            episodeFingerprints,
            episodeFingerprints.episodeId.equalsExp(episodes.id),
          ),
        ])..where(
          episodes.podcastId.equals(podcastId) &
              episodes.downloadPath.isNotNull() &
              episodes.downloadPath.length.isBiggerThanValue(0),
        );
    final rows = await query.get();
    return [
      for (final row in rows)
        (
          episode: row.readTable(episodes),
          fingerprint: row.readTable(episodeFingerprints),
        ),
    ];
  }

  Future<List<({int id, int podcastId})>> downloadedEpisodesMissingFingerprint({
    int? podcastId,
  }) async {
    final query =
        select(episodes).join([
          leftOuterJoin(
            episodeFingerprints,
            episodeFingerprints.episodeId.equalsExp(episodes.id),
          ),
        ])..where(
          episodes.downloadPath.isNotNull() &
              episodes.downloadPath.length.isBiggerThanValue(0) &
              (episodeFingerprints.episodeId.isNull() |
                  episodeFingerprints.speech.isNull()),
        );
    if (podcastId != null) query.where(episodes.podcastId.equals(podcastId));
    final rows = await query.get();
    return [
      for (final row in rows)
        (
          id: row.readTable(episodes).id,
          podcastId: row.readTable(episodes).podcastId,
        ),
    ];
  }

  Future<List<SkipSegment>> fingerprintSegmentsForPodcast(int podcastId) async {
    final query =
        select(skipSegments).join([
          innerJoin(episodes, episodes.id.equalsExp(skipSegments.episodeId)),
        ])..where(
          episodes.podcastId.equals(podcastId) &
              skipSegments.source.equalsValue(SkipSegmentSource.fingerprint),
        );
    final rows = await query.get();
    return [for (final row in rows) row.readTable(skipSegments)];
  }

  Future<List<SkipSegment>> segmentsForTemplate(int templateId) {
    return (select(
      skipSegments,
    )..where((row) => row.templateId.equals(templateId))).get();
  }

  Future<void> updateFingerprintSegment({
    required int id,
    required int startMs,
    required int endMs,
    required int matches,
    required int? templateId,
    Value<int?>? confidence,
  }) {
    return (update(skipSegments)..where((row) => row.id.equals(id))).write(
      SkipSegmentsCompanion(
        startMs: Value(startMs),
        endMs: Value(endMs),
        matches: Value(matches),
        templateId: Value(templateId),
        confidence: confidence ?? const Value.absent(),
      ),
    );
  }

  Future<void> touchSegmentTemplate(int id, {required int occurrences}) {
    return (update(segmentTemplates)..where((row) => row.id.equals(id))).write(
      SegmentTemplatesCompanion(occurrences: Value(occurrences)),
    );
  }

  Future<void> setTemplateLogMel(int id, Uint8List logMel) {
    return (update(segmentTemplates)..where((row) => row.id.equals(id))).write(
      SegmentTemplatesCompanion(logMel: Value(logMel)),
    );
  }

  Future<void> upsertEpisodeLogMel({
    required int episodeId,
    required Uint8List data,
    int hopMs = logMelHopMs,
    DateTime? createdAt,
  }) {
    return into(episodeLogMels).insertOnConflictUpdate(
      EpisodeLogMelsCompanion.insert(
        episodeId: Value(episodeId),
        data: data,
        hopMs: hopMs,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<EpisodeLogMel?> logMelForEpisode(int episodeId) {
    return (select(
      episodeLogMels,
    )..where((row) => row.episodeId.equals(episodeId))).getSingleOrNull();
  }

  Future<List<({int episodeId, int podcastId, Uint8List data})>>
  logMelForPodcast(int podcastId) async {
    final query =
        select(episodeLogMels).join([
          innerJoin(episodes, episodes.id.equalsExp(episodeLogMels.episodeId)),
        ])..where(
          episodes.podcastId.equals(podcastId) &
              episodes.downloadPath.isNotNull() &
              episodes.downloadPath.length.isBiggerThanValue(0),
        );
    final rows = await query.get();
    return [
      for (final row in rows)
        (
          episodeId: row.readTable(episodeLogMels).episodeId,
          podcastId: podcastId,
          data: row.readTable(episodeLogMels).data,
        ),
    ];
  }

  Future<List<({int episodeId, int podcastId, Uint8List data, int endMs})>>
  dynamicAdBoundaries() async {
    final query =
        select(skipSegments).join([
          innerJoin(episodes, episodes.id.equalsExp(skipSegments.episodeId)),
          innerJoin(
            episodeLogMels,
            episodeLogMels.episodeId.equalsExp(skipSegments.episodeId),
          ),
        ])..where(
          skipSegments.kind.equalsValue(SkipSegmentKind.ad) &
              skipSegments.source.equalsValue(SkipSegmentSource.fingerprint) &
              skipSegments.endMs.isSmallerOrEqualValue(logMelSearchWindowMs),
        );
    final rows = await query.get();
    return [
      for (final row in rows)
        (
          episodeId: row.readTable(skipSegments).episodeId,
          podcastId: row.readTable(episodes).podcastId,
          data: row.readTable(episodeLogMels).data,
          endMs: row.readTable(skipSegments).endMs,
        ),
    ];
  }

  Future<List<LearnedNetworkSting>> listLearnedNetworkStings() {
    return (select(
      learnedNetworkStings,
    )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
  }

  Future<int> insertLearnedNetworkSting({
    required Uint8List logMel,
    required int durationMs,
    String? name,
    int episodeCount = 1,
    int podcastCount = 1,
  }) {
    return into(learnedNetworkStings).insert(
      LearnedNetworkStingsCompanion.insert(
        name: Value(name),
        logMel: logMel,
        durationMs: durationMs,
        episodeCount: Value(episodeCount),
        podcastCount: Value(podcastCount),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> touchLearnedNetworkSting(
    int id, {
    required int episodeCount,
    required int podcastCount,
  }) {
    return (update(
      learnedNetworkStings,
    )..where((row) => row.id.equals(id))).write(
      LearnedNetworkStingsCompanion(
        episodeCount: Value(episodeCount),
        podcastCount: Value(podcastCount),
      ),
    );
  }

  Future<List<SkipSegment>> networkSegmentsForPodcast(int podcastId) async {
    final query =
        select(skipSegments).join([
          innerJoin(episodes, episodes.id.equalsExp(skipSegments.episodeId)),
        ])..where(
          episodes.podcastId.equals(podcastId) &
              skipSegments.source.equalsValue(SkipSegmentSource.network),
        );
    final rows = await query.get();
    return [for (final row in rows) row.readTable(skipSegments)];
  }

  /// Retire l’empreinte et les passages qui en viennent. Un gabarit sans
  /// passage restant est effacé. Les chapitres et les passages manuels restent.
  Future<void> clearDownloadAnalysis(int episodeId) {
    return transaction(() async {
      final rows =
          await (select(skipSegments)..where(
                (row) =>
                    row.episodeId.equals(episodeId) &
                    row.source.equalsValue(SkipSegmentSource.fingerprint),
              ))
              .get();
      final templateIds = <int>{
        for (final row in rows)
          if (row.templateId != null) row.templateId!,
      };
      await (delete(skipSegments)..where(
            (row) =>
                row.episodeId.equals(episodeId) &
                row.source.equalsValue(SkipSegmentSource.fingerprint),
          ))
          .go();
      await (delete(
        episodeFingerprints,
      )..where((row) => row.episodeId.equals(episodeId))).go();
      await (delete(
        episodeLogMels,
      )..where((row) => row.episodeId.equals(episodeId))).go();
      for (final templateId in templateIds) {
        final left = await segmentsForTemplate(templateId);
        if (left.isEmpty) {
          await (delete(
            segmentTemplates,
          )..where((row) => row.id.equals(templateId))).go();
          continue;
        }
        final episodes = left.map((row) => row.episodeId).toSet().length;
        await touchSegmentTemplate(templateId, occurrences: episodes);
      }
    });
  }
}

bool? _reviewOf(int pending, int yes, int no) {
  if (pending == 0 && no == 0 && yes > 0) return true;
  if (pending == 0 && yes == 0 && no > 0) return false;
  return null;
}

Stream<T> _combineSkip<A, B, C, T>(
  Stream<A> first,
  Stream<B> second,
  Stream<C> third,
  T Function(A, B, C) map,
) {
  return Stream<T>.multi((controller) {
    A? latestA;
    B? latestB;
    C? latestC;
    var hasA = false;
    var hasB = false;
    var hasC = false;
    void emit() {
      if (!hasA || !hasB || !hasC || controller.isClosed) return;
      controller.add(map(latestA as A, latestB as B, latestC as C));
    }

    final subs = [
      first.listen((value) {
        latestA = value;
        hasA = true;
        emit();
      }, onError: controller.addError),
      second.listen((value) {
        latestB = value;
        hasB = true;
        emit();
      }, onError: controller.addError),
      third.listen((value) {
        latestC = value;
        hasC = true;
        emit();
      }, onError: controller.addError),
    ];
    controller.onCancel = () {
      for (final sub in subs) {
        unawaited(sub.cancel());
      }
    };
  });
}
