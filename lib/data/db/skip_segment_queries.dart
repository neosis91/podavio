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
  const SkipClassification({required this.templates, required this.segments});

  final List<SegmentTemplate> templates;
  final List<LooseSkipSegment> segments;
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

  Future<void> setFingerprintEnvelope(int episodeId, Uint8List envelope) {
    return customStatement(
      'UPDATE episode_fingerprints SET envelope = ? WHERE episode_id = ?',
      [envelope, episodeId],
    );
  }

  /// Enveloppes déjà calculées. Une valeur absente ne relance pas le décodage.
  Future<Map<int, Uint8List>> fingerprintEnvelopes(int podcastId) async {
    final rows = await customSelect(
      'SELECT f.episode_id AS episode_id, f.envelope AS envelope '
      'FROM episode_fingerprints f '
      'INNER JOIN episodes e ON e.id = f.episode_id '
      'WHERE e.podcast_id = ? AND f.envelope IS NOT NULL',
      variables: [Variable.withInt(podcastId)],
      readsFrom: {episodeFingerprints, episodes},
    ).get();
    final found = <int, Uint8List>{};
    for (final row in rows) {
      final bytes = row.read<Uint8List?>('envelope');
      if (bytes == null || bytes.isEmpty) continue;
      found[row.read<int>('episode_id')] = bytes;
    }
    return found;
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

  Stream<List<SkipSegment>> watchSkipSegments(int episodeId) {
    final query = select(skipSegments)
      ..where((row) => row.episodeId.equals(episodeId))
      ..orderBy([(row) => OrderingTerm.asc(row.startMs)]);
    return query.watch();
  }

  /// Passages actifs de l’épisode : posés à la main, ou retrouvés grâce au
  /// gabarit d’un passage posé à la main. Les anciens passages détectés
  /// tout seuls (répétitions, log-mel, virgules, chapitres) restent en base
  /// mais ne sont plus ni montrés ni sautés.
  Future<List<SkipSegment>> listActiveSkipSegments(int episodeId) {
    return _activeSegments(episodeId).get();
  }

  Stream<List<SkipSegment>> watchActiveSkipSegments(int episodeId) {
    return _activeSegments(episodeId).watch();
  }

  SimpleSelectStatement<$SkipSegmentsTable, SkipSegment> _activeSegments(
    int episodeId,
  ) {
    return select(skipSegments)
      ..where((row) => row.episodeId.equals(episodeId) & _activeSegment)
      ..orderBy([(row) => OrderingTerm.asc(row.startMs)]);
  }

  /// Pub, sponsor et « autre » posés à la main, quel que soit le podcast.
  Future<List<SegmentTemplate>> sharedAdTemplates() {
    return _sharedManualTemplates([
      for (final kind in SkipSegmentKind.values)
        if (spreadsToEveryPodcast(kind)) kind,
    ]);
  }

  /// Virgules et jingles posés à la main sur [podcastIds] (même hébergeur).
  Future<List<SegmentTemplate>> sharedNetworkTemplates(List<int> podcastIds) {
    return _sharedManualTemplates([
      for (final kind in SkipSegmentKind.values)
        if (spreadsWithinNetwork(kind)) kind,
    ], podcastIds: podcastIds);
  }

  /// Retire les virgules et jingles d’un autre hébergeur sur [podcastId].
  /// Les passages posés à la main restent.
  Future<void> deleteNetworkHitsOutside(
    int podcastId,
    List<int> allowedPodcastIds,
  ) async {
    final kinds = [
      for (final kind in SkipSegmentKind.values)
        if (spreadsWithinNetwork(kind)) "'${kind.name}'",
    ].join(', ');
    if (kinds.isEmpty) return;
    final allowed = {...allowedPodcastIds, podcastId}.join(', ');
    final rows = await customSelect(
      'SELECT s.id AS id FROM skip_segments s '
      'INNER JOIN episodes e ON e.id = s.episode_id '
      'INNER JOIN segment_templates t ON t.id = s.template_id '
      'WHERE e.podcast_id = ? AND s.source != \'manual\' '
      'AND t.kind IN ($kinds) AND t.podcast_id NOT IN ($allowed)',
      variables: [Variable.withInt(podcastId)],
      readsFrom: {skipSegments, episodes, segmentTemplates},
    ).get();
    for (final row in rows) {
      await deleteSkipSegment(row.read<int>('id'));
    }
  }

  Future<List<SegmentTemplate>> _sharedManualTemplates(
    List<SkipSegmentKind> kinds, {
    List<int>? podcastIds,
  }) async {
    if (kinds.isEmpty) return const [];
    if (podcastIds != null && podcastIds.isEmpty) return const [];
    final kindSql = [for (final kind in kinds) "'${kind.name}'"].join(', ');
    final podcastSql = podcastIds == null
        ? ''
        : ' AND t.podcast_id IN (${podcastIds.join(', ')})';
    final rows = await customSelect(
      'SELECT DISTINCT t.* FROM segment_templates t '
      'WHERE t.kind IN ($kindSql) AND $_manualTemplateSql$podcastSql',
      readsFrom: {segmentTemplates, skipSegments},
    ).get();
    return [for (final row in rows) segmentTemplates.map(row.data)];
  }

  /// Podcasts qui ont au moins une empreinte, pour y chercher une pub.
  Future<List<int>> podcastIdsWithFingerprints() async {
    final rows = await customSelect(
      'SELECT DISTINCT e.podcast_id AS podcast_id '
      'FROM episode_fingerprints f '
      'INNER JOIN episodes e ON e.id = f.episode_id',
      readsFrom: {episodeFingerprints, episodes},
    ).get();
    return [for (final row in rows) row.read<int>('podcast_id')];
  }

  /// Gabarits du podcast rattachés à au moins un passage posé à la main :
  /// les seuls que l’analyse cherche, avec les publicités des autres.
  Future<Set<int>> manualTemplateIds(int podcastId) async {
    final rows = await customSelect(
      'SELECT DISTINCT s.template_id AS template_id '
      'FROM skip_segments s '
      'INNER JOIN episodes e ON e.id = s.episode_id '
      "WHERE e.podcast_id = ? AND s.source = 'manual' "
      'AND s.template_id IS NOT NULL',
      variables: [Variable.withInt(podcastId)],
      readsFrom: {skipSegments, episodes},
    ).get();
    return {for (final row in rows) row.read<int>('template_id')};
  }

  /// Gabarits actifs (rattachés à un passage posé à la main).
  Stream<List<SegmentTemplate>> watchSegmentTemplates(int podcastId) {
    return customSelect(
      'SELECT * FROM segment_templates t '
      'WHERE t.podcast_id = ? AND $_manualTemplateSql '
      'ORDER BY t.kind, t.id',
      variables: [Variable.withInt(podcastId)],
      readsFrom: {segmentTemplates, skipSegments},
    ).watch().map(
      (rows) => [for (final row in rows) segmentTemplates.map(row.data)],
    );
  }

  Stream<SkipClassification> watchSkipClassification(int podcastId) {
    return _combineSkip(
      watchSegmentTemplates(podcastId),
      _watchLooseSegments(podcastId),
      (templates, segments) =>
          SkipClassification(templates: templates, segments: segments),
    );
  }

  Stream<List<LooseSkipSegment>> _watchLooseSegments(int podcastId) {
    final query =
        select(skipSegments).join([
            innerJoin(episodes, episodes.id.equalsExp(skipSegments.episodeId)),
          ])
          ..where(
            episodes.podcastId.equals(podcastId) &
                skipSegments.templateId.isNull() &
                skipSegments.source.equalsValue(SkipSegmentSource.manual),
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

  /// Épisode téléchargé qui contient [templateId], pour l’écoute courte.
  Future<({int episodeId, int segmentId, int startMs, int endMs})?>
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
      endMs: segment.endMs,
    );
  }

  /// Un type choisi par l’utilisateur tient comme un passage posé à la
  /// main : l’analyse ne réécrit ni ne retire plus cette ligne.
  Future<void> setSkipSegmentKind(int id, SkipSegmentKind kind) {
    return (update(skipSegments)..where((row) => row.id.equals(id))).write(
      SkipSegmentsCompanion(
        kind: Value(kind),
        source: const Value(SkipSegmentSource.manual),
      ),
    );
  }

  Future<void> deleteSkipSegment(int id) {
    return (delete(skipSegments)..where((row) => row.id.equals(id))).go();
  }

  /// L’analyse ne retire qu’une détection. Un passage dont le type ou les
  /// bornes viennent d’être choisis (`manual`) reste en place.
  Future<void> deleteDetectedSkipSegment(int id) {
    return (delete(skipSegments)..where(
          (row) =>
              row.id.equals(id) &
              row.source.equalsValue(SkipSegmentSource.manual).not(),
        ))
        .go();
  }

  /// Retrait par l’utilisateur. La plage est mémorisée avant l’effacement,
  /// pour qu’une analyse du même épisode ou du même gabarit ne la recrée pas.
  Future<void> dismissSkipSegment(int id) {
    return transaction(() async {
      final row = await skipSegmentById(id);
      if (row == null) return;
      await _rememberDismissed(row);
      await deleteSkipSegment(id);
    });
  }

  Future<void> _rememberDismissed(SkipSegment row) {
    return into(dismissedSkipSpans).insert(
      DismissedSkipSpansCompanion.insert(
        episodeId: row.episodeId,
        templateId: Value(row.templateId),
        startMs: row.startMs,
        endMs: row.endMs,
      ),
    );
  }

  Future<List<DismissedSkipSpan>> dismissedSpansForPodcast(
    int podcastId,
  ) async {
    final query = select(dismissedSkipSpans).join([
      innerJoin(episodes, episodes.id.equalsExp(dismissedSkipSpans.episodeId)),
    ])..where(episodes.podcastId.equals(podcastId));
    final rows = await query.get();
    return [for (final row in rows) row.readTable(dismissedSkipSpans)];
  }

  Future<List<DismissedSkipSpan>> dismissedSpansForEpisode(int episodeId) {
    return (select(
      dismissedSkipSpans,
    )..where((row) => row.episodeId.equals(episodeId))).get();
  }

  Future<void> setTemplateKind(int id, SkipSegmentKind kind) {
    return transaction(() async {
      final current = await (select(
        segmentTemplates,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (current == null) return;
      await (update(segmentTemplates)..where((row) => row.id.equals(id))).write(
        SegmentTemplatesCompanion(kind: Value(kind)),
      );
      final narrowed =
          (sharesAcrossPodcasts(current.kind) && !sharesAcrossPodcasts(kind)) ||
          (spreadsToEveryPodcast(current.kind) && spreadsWithinNetwork(kind));
      if (narrowed) {
        final foreign =
            await (select(skipSegments).join([
                  innerJoin(
                    episodes,
                    episodes.id.equalsExp(skipSegments.episodeId),
                  ),
                ])..where(
                  skipSegments.templateId.equals(id) &
                      episodes.podcastId.equals(current.podcastId).not() &
                      skipSegments.source
                          .equalsValue(SkipSegmentSource.manual)
                          .not(),
                ))
                .get();
        for (final row in foreign) {
          final segment = row.readTable(skipSegments);
          // Sans trace, le même gabarit reposerait ces passages dès que
          // le type redevient large.
          await _rememberDismissed(segment);
          await deleteSkipSegment(segment.id);
        }
      }
      // Le type a été choisi : ces passages ne sont plus des détections
      // que l’analyse peut déplacer ou effacer.
      await (update(
        skipSegments,
      )..where((row) => row.templateId.equals(id))).write(
        SkipSegmentsCompanion(
          kind: Value(kind),
          source: const Value(SkipSegmentSource.manual),
        ),
      );
    });
  }

  Future<void> setTemplateLabel(int id, String? label) {
    final trimmed = label?.trim() ?? '';
    return (update(segmentTemplates)..where((row) => row.id.equals(id))).write(
      SegmentTemplatesCompanion(label: Value(trimmed.isEmpty ? null : trimmed)),
    );
  }

  /// Efface le modèle et les passages qui en dépendent.
  /// Chaque passage retiré est mémorisé : le même gabarit ne les repose pas.
  Future<void> deleteSegmentTemplate(int id) {
    return transaction(() async {
      final rows = await segmentsForTemplate(id);
      for (final row in rows) {
        await _rememberDismissed(row);
      }
      await (delete(
        skipSegments,
      )..where((row) => row.templateId.equals(id))).go();
      await (delete(segmentTemplates)..where((row) => row.id.equals(id))).go();
    });
  }

  Future<List<SegmentTemplate>> listSegmentTemplates(int podcastId) {
    return (select(segmentTemplates)
          ..where((row) => row.podcastId.equals(podcastId))
          ..orderBy([(row) => OrderingTerm.asc(row.id)]))
        .get();
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

  /// Épisodes téléchargés qui n’ont jamais été empreintés.
  ///
  /// Une ligne `running` ou `failed` n’est pas reprise au démarrage :
  /// l’analyse précédente n’est pas terminée, ou elle a déjà échoué.
  Future<List<({int id, int podcastId})>> downloadedEpisodesMissingFingerprint({
    int? podcastId,
  }) async {
    final rows = await customSelect(
      'SELECT e.id AS id, e.podcast_id AS podcast_id '
      'FROM episodes e '
      'LEFT JOIN episode_fingerprints f ON f.episode_id = e.id '
      'WHERE e.download_path IS NOT NULL AND length(e.download_path) > 0 '
      'AND f.episode_id IS NULL'
      '${podcastId == null ? '' : ' AND e.podcast_id = ?'}',
      variables: [if (podcastId != null) Variable.withInt(podcastId)],
      readsFrom: {episodes, episodeFingerprints},
    ).get();
    return [
      for (final row in rows)
        (id: row.read<int>('id'), podcastId: row.read<int>('podcast_id')),
    ];
  }

  /// Épisodes téléchargés du podcast, du plus récent au plus ancien,
  /// avec l’état d’empreinte déjà écrit.
  Future<
    List<
      ({
        int episodeId,
        String title,
        String? fingerprintStatus,
        bool chromaprint,
      })
    >
  >
  episodeAnalysisFacts(int podcastId) async {
    final rows = await customSelect(
      'SELECT e.id AS id, e.title AS title, f.status AS status, '
      'CASE WHEN f.data IS NOT NULL '
      'AND length(f.data) >= 32 AND length(f.data) % 4 = 0 '
      "AND NOT (substr(f.data, 1, 4) = X'4F6C6166') "
      'THEN 1 ELSE 0 END AS chromaprint '
      'FROM episodes e '
      'LEFT JOIN episode_fingerprints f ON f.episode_id = e.id '
      'WHERE e.podcast_id = ? '
      'AND e.download_path IS NOT NULL AND length(trim(e.download_path)) > 0 '
      'ORDER BY e.published_at DESC, e.id DESC',
      variables: [Variable.withInt(podcastId)],
      readsFrom: {episodes, episodeFingerprints},
    ).get();
    return [
      for (final row in rows)
        (
          episodeId: row.read<int>('id'),
          title: row.read<String>('title'),
          fingerprintStatus: row.read<String?>('status'),
          chromaprint: row.read<int>('chromaprint') == 1,
        ),
    ];
  }

  Future<String?> fingerprintStatus(int episodeId) async {
    final rows = await customSelect(
      'SELECT status FROM episode_fingerprints WHERE episode_id = ?',
      variables: [Variable.withInt(episodeId)],
      readsFrom: {episodeFingerprints},
    ).get();
    if (rows.isEmpty) return null;
    return rows.single.read<String>('status');
  }

  /// Pose `running` sans effacer une empreinte déjà bonne.
  Future<void> markFingerprintRunning(int episodeId) async {
    final existing = await fingerprintForEpisode(episodeId);
    if (existing == null) {
      await upsertEpisodeFingerprint(
        episodeId: episodeId,
        data: Uint8List(0),
        hopMicros: 0,
        speech: Uint8List(0),
      );
    }
    await customStatement(
      "UPDATE episode_fingerprints SET status = 'running' WHERE episode_id = ?",
      [episodeId],
    );
  }

  Future<void> markFingerprintDone(int episodeId) {
    return customStatement(
      "UPDATE episode_fingerprints SET status = 'done' WHERE episode_id = ?",
      [episodeId],
    );
  }

  /// Échec ou analyse interrompue. Une empreinte déjà `done` est gardée.
  Future<void> markFingerprintFailed(int episodeId) async {
    final status = await fingerprintStatus(episodeId);
    if (status == 'done') return;
    if (status == null) {
      await upsertEpisodeFingerprint(
        episodeId: episodeId,
        data: Uint8List(0),
        hopMicros: 0,
        speech: Uint8List(0),
      );
    }
    await customStatement(
      "UPDATE episode_fingerprints SET status = 'failed' WHERE episode_id = ?",
      [episodeId],
    );
  }

  /// Au démarrage : une analyse tuée en cours ne repart pas toute seule.
  Future<void> failInterruptedFingerprints() {
    return customStatement(
      "UPDATE episode_fingerprints SET status = 'failed' WHERE status = 'running'",
    );
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
    return (update(skipSegments)..where(
          (row) =>
              row.id.equals(id) &
              row.source.equalsValue(SkipSegmentSource.manual).not(),
        ))
        .write(
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

  Future<void> setSegmentTemplateFingerprint(
    int id,
    Uint8List fingerprint, {
    int? durationMs,
  }) {
    return (update(segmentTemplates)..where((row) => row.id.equals(id))).write(
      SegmentTemplatesCompanion(
        fingerprint: Value(fingerprint),
        durationMs: durationMs == null
            ? const Value.absent()
            : Value(durationMs),
      ),
    );
  }

  Future<SkipSegment?> skipSegmentById(int id) {
    return (select(
      skipSegments,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  /// Bornes corrigées à la main : le passage devient `manual`.
  /// Une nouvelle analyse ne réécrit que les lignes `fingerprint`.
  Future<void> setManualSegmentBounds(
    int id, {
    required int startMs,
    required int endMs,
    int? templateId,
  }) {
    return (update(skipSegments)..where((row) => row.id.equals(id))).write(
      SkipSegmentsCompanion(
        startMs: Value(startMs),
        endMs: Value(endMs),
        source: const Value(SkipSegmentSource.manual),
        templateId: templateId == null
            ? const Value.absent()
            : Value(templateId),
      ),
    );
  }

  /// Passages corrigés à la main du podcast, que l’analyse ne recouvre pas.
  Future<List<SkipSegment>> manualSegmentsForPodcast(int podcastId) async {
    final query =
        select(skipSegments).join([
          innerJoin(episodes, episodes.id.equalsExp(skipSegments.episodeId)),
        ])..where(
          episodes.podcastId.equals(podcastId) &
              skipSegments.source.equalsValue(SkipSegmentSource.manual),
        );
    final rows = await query.get();
    return [for (final row in rows) row.readTable(skipSegments)];
  }

  Future<Uint8List?> envelopeForEpisode(int episodeId) async {
    final row = await customSelect(
      'SELECT envelope FROM episode_fingerprints WHERE episode_id = ?',
      variables: [Variable.withInt(episodeId)],
      readsFrom: {episodeFingerprints},
    ).getSingleOrNull();
    final bytes = row?.read<Uint8List?>('envelope');
    return bytes == null || bytes.isEmpty ? null : bytes;
  }

  /// Vérité terrain locale : bornes détectées puis corrigées, une ligne
  /// par enregistrement. Sert plus tard à régler les seuils, hors réseau.
  /// Sans source détectée, le passage a été créé à la main.
  Future<void> insertSegmentAnnotation({
    required int segmentId,
    required int episodeId,
    required SkipSegmentKind kind,
    SkipSegmentSource? detectedSource,
    int? detectedStartMs,
    int? detectedEndMs,
    required int correctedStartMs,
    required int correctedEndMs,
    DateTime? createdAt,
  }) {
    return customStatement(
      'INSERT INTO segment_annotations (segment_id, episode_id, kind, '
      'detected_source, detected_start_ms, detected_end_ms, '
      'corrected_start_ms, corrected_end_ms, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        segmentId,
        episodeId,
        kind.name,
        detectedSource?.name,
        detectedStartMs,
        detectedEndMs,
        correctedStartMs,
        correctedEndMs,
        (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
      ],
    );
  }

  Future<List<SegmentAnnotation>> listSegmentAnnotations() async {
    final rows = await customSelect(
      'SELECT * FROM segment_annotations ORDER BY id',
    ).get();
    return [
      for (final row in rows)
        SegmentAnnotation(
          segmentId: row.read<int>('segment_id'),
          episodeId: row.read<int>('episode_id'),
          kind: row.read<String>('kind'),
          detectedSource: row.read<String?>('detected_source'),
          detectedStartMs: row.read<int?>('detected_start_ms'),
          detectedEndMs: row.read<int?>('detected_end_ms'),
          correctedStartMs: row.read<int>('corrected_start_ms'),
          correctedEndMs: row.read<int>('corrected_end_ms'),
        ),
    ];
  }

  /// Épisodes où créer un passage : analysés d’abord (enveloppe stockée),
  /// puis téléchargés, puis les autres, du plus récent au plus ancien.
  Future<List<PassageEpisodeChoice>> passageEpisodeChoices(
    int podcastId, {
    int limit = 100,
  }) async {
    final rows = await customSelect(
      'SELECT e.id AS id, e.title AS title, '
      'CASE WHEN e.download_path IS NOT NULL AND length(e.download_path) > 0 '
      'THEN 1 ELSE 0 END AS downloaded, '
      'CASE WHEN f.envelope IS NOT NULL AND length(f.envelope) > 0 '
      'THEN 1 ELSE 0 END AS analysed '
      'FROM episodes e '
      'LEFT JOIN episode_fingerprints f ON f.episode_id = e.id '
      'WHERE e.podcast_id = ? '
      'ORDER BY analysed DESC, downloaded DESC, e.published_at DESC, e.id DESC '
      'LIMIT ?',
      variables: [Variable.withInt(podcastId), Variable.withInt(limit)],
      readsFrom: {episodes, episodeFingerprints},
    ).get();
    return [
      for (final row in rows)
        PassageEpisodeChoice(
          episodeId: row.read<int>('id'),
          title: row.read<String>('title'),
          downloaded: row.read<int>('downloaded') == 1,
          analysed: row.read<int>('analysed') == 1,
        ),
    ];
  }

  /// Vrai si [segmentId] a été créé à la main (vérité sans bornes détectées).
  Future<bool> isCreatedSegment(int segmentId) async {
    final row = await customSelect(
      'SELECT 1 FROM segment_annotations '
      'WHERE segment_id = ? AND detected_source IS NULL LIMIT 1',
      variables: [Variable.withInt(segmentId)],
    ).getSingleOrNull();
    return row != null;
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

  Future<
    List<({int id, int episodeId, int podcastId, Uint8List data, int endMs})>
  >
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
          id: row.readTable(skipSegments).id,
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

  /// Podcasts suivis, et ceux qui ont encore un fichier, pour la page globale.
  ///
  /// Un seul flux : Drift garde un minuteur par requête observée, et la page
  /// n’en a pas besoin de trois.
  Stream<AnalysisFacts> watchAnalysisFacts() {
    return customSelect(
      'SELECT COUNT(*) AS n FROM episodes',
      readsFrom: {
        podcasts,
        episodes,
        episodeFingerprints,
        segmentTemplates,
        skipSegments,
      },
    ).watch().asyncMap((_) async {
      return AnalysisFacts(
        catalog: await _analysisCatalog(),
        downloads: await _analysisDownloads(),
        segments: await _analysisSegments(),
        manual: await _analysisManual(),
      );
    });
  }

  /// Passages posés à la main (créés ou corrigés), par podcast.
  Future<Map<int, int>> _analysisManual() async {
    final rows = await customSelect(
      'SELECT e.podcast_id AS podcast_id, COUNT(*) AS n '
      'FROM skip_segments s '
      'INNER JOIN episodes e ON e.id = s.episode_id '
      "WHERE s.source = 'manual' "
      'GROUP BY e.podcast_id',
      readsFrom: {skipSegments, episodes},
    ).get();
    return {
      for (final row in rows) row.read<int>('podcast_id'): row.read<int>('n'),
    };
  }

  Future<List<AnalysisCatalogRow>> _analysisCatalog() async {
    final rows = await customSelect(
      'SELECT p.id AS id, p.title AS title, '
      "COALESCE(p.image_url, '') AS image_url, "
      "COALESCE(p.image_path, '') AS image_path, "
      'p.feed_url AS feed_url '
      'FROM podcasts p '
      'WHERE p.subscribed = 1 OR EXISTS ('
      'SELECT 1 FROM episodes e '
      'WHERE e.podcast_id = p.id '
      'AND e.download_path IS NOT NULL AND length(e.download_path) > 0)',
      readsFrom: {podcasts, episodes},
    ).get();
    return [
      for (final row in rows)
        AnalysisCatalogRow(
          id: row.read<int>('id'),
          title: row.read<String>('title'),
          imageUrl: row.read<String>('image_url'),
          imagePath: row.read<String>('image_path'),
          feedUrl: row.read<String>('feed_url'),
        ),
    ];
  }

  Future<List<AnalysisDownloadRow>> _analysisDownloads() async {
    final rows = await customSelect(
      'SELECT e.podcast_id AS podcast_id, e.audio_url AS audio_url, '
      "COALESCE(f.status, '') AS status "
      'FROM episodes e '
      'LEFT JOIN episode_fingerprints f ON f.episode_id = e.id '
      'WHERE e.download_path IS NOT NULL AND length(e.download_path) > 0',
      readsFrom: {episodes, episodeFingerprints},
    ).get();
    return [
      for (final row in rows)
        AnalysisDownloadRow(
          podcastId: row.read<int>('podcast_id'),
          audioUrl: row.read<String>('audio_url'),
          status: row.read<String>('status'),
        ),
    ];
  }

  Future<List<AnalysisSegmentRow>> _analysisSegments() async {
    final rows = await customSelect(
      'SELECT t.podcast_id AS podcast_id, t.kind AS kind, COUNT(*) AS n '
      'FROM segment_templates t '
      'WHERE $_manualTemplateSql '
      'GROUP BY t.podcast_id, t.kind '
      'UNION ALL '
      'SELECT e.podcast_id AS podcast_id, s.kind AS kind, COUNT(*) AS n '
      'FROM skip_segments s '
      'INNER JOIN episodes e ON e.id = s.episode_id '
      'WHERE s.template_id IS NULL '
      "AND s.source = 'manual' "
      'AND e.download_path IS NOT NULL AND length(e.download_path) > 0 '
      'GROUP BY e.podcast_id, s.kind',
      readsFrom: {segmentTemplates, skipSegments, episodes},
    ).get();
    return [
      for (final row in rows)
        AnalysisSegmentRow(
          podcastId: row.read<int>('podcast_id'),
          kind: row.read<String>('kind'),
          count: row.read<int>('n'),
        ),
    ];
  }

  /// URLs de tous les épisodes connus, pour l’hébergeur du réseau.
  ///
  /// Sans le filtre « téléchargé » : retirer le dernier fichier ne doit
  /// pas faire oublier l’hébergeur et effacer ses virgules ailleurs.
  Future<List<({int podcastId, String audioUrl, String feedUrl})>>
  hostingRows() async {
    final rows = await customSelect(
      'SELECT e.podcast_id AS podcast_id, e.audio_url AS audio_url, '
      'p.feed_url AS feed_url '
      'FROM episodes e '
      'INNER JOIN podcasts p ON p.id = e.podcast_id ',
      readsFrom: {episodes, podcasts},
    ).get();
    return [
      for (final row in rows)
        (
          podcastId: row.read<int>('podcast_id'),
          audioUrl: row.read<String>('audio_url'),
          feedUrl: row.read<String>('feed_url'),
        ),
    ];
  }

  /// Retire l’empreinte et les passages de cet épisode.
  ///
  /// Le gabarit reste, même sans occurrence : un prochain téléchargement
  /// retrouve la séquence. Les chapitres et les passages manuels restent.
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
        final episodes = left.map((row) => row.episodeId).toSet().length;
        await touchSegmentTemplate(templateId, occurrences: episodes);
      }
    });
  }
}

class AnalysisFacts {
  const AnalysisFacts({
    required this.catalog,
    required this.downloads,
    required this.segments,
    this.manual = const {},
  });

  final List<AnalysisCatalogRow> catalog;
  final List<AnalysisDownloadRow> downloads;
  final List<AnalysisSegmentRow> segments;

  /// Passages posés à la main, par id de podcast.
  final Map<int, int> manual;
}

class PassageEpisodeChoice {
  const PassageEpisodeChoice({
    required this.episodeId,
    required this.title,
    required this.downloaded,
    required this.analysed,
  });

  final int episodeId;
  final String title;
  final bool downloaded;

  /// L’enveloppe est stockée : forme d’onde et empreinte disponibles.
  final bool analysed;
}

class AnalysisCatalogRow {
  const AnalysisCatalogRow({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.imagePath,
    required this.feedUrl,
  });

  final int id;
  final String title;
  final String imageUrl;
  final String imagePath;
  final String feedUrl;
}

class AnalysisDownloadRow {
  const AnalysisDownloadRow({
    required this.podcastId,
    required this.audioUrl,
    required this.status,
  });

  final int podcastId;
  final String audioUrl;
  final String status;
}

class AnalysisSegmentRow {
  const AnalysisSegmentRow({
    required this.podcastId,
    required this.kind,
    required this.count,
  });

  final int podcastId;
  final String kind;
  final int count;
}

Stream<T> _combineSkip<A, B, T>(
  Stream<A> first,
  Stream<B> second,
  T Function(A, B) map,
) {
  return Stream<T>.multi((controller) {
    A? latestA;
    B? latestB;
    var hasA = false;
    var hasB = false;
    void emit() {
      if (!hasA || !hasB || controller.isClosed) return;
      controller.add(map(latestA as A, latestB as B));
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
    ];
    controller.onCancel = () {
      for (final sub in subs) {
        unawaited(sub.cancel());
      }
    };
  });
}

/// Gabarit `t` rattaché à un passage posé à la main.
const _manualTemplateSql =
    'EXISTS (SELECT 1 FROM skip_segments m '
    "WHERE m.template_id = t.id AND m.source = 'manual')";

/// Passage manuel, ou occurrence d’un gabarit rattaché à un passage manuel.
const _activeSegment = CustomExpression<bool>(
  "(skip_segments.source = 'manual' OR EXISTS ("
  'SELECT 1 FROM skip_segments m '
  'WHERE m.template_id = skip_segments.template_id '
  "AND m.source = 'manual'))",
);
