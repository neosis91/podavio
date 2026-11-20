import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';
import '../../data/skip_segments.dart';
import '../../l10n/l10n.dart';
import '../../player/player_controller.dart';
import '../widgets/choice_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/list_metrics.dart';
import '../widgets/messages.dart';

final skipClassificationProvider =
    StreamProvider.family<SkipClassification, int>((ref, podcastId) {
      return ref.watch(databaseProvider).watchSkipClassification(podcastId);
    });

class SkipClassificationPage extends ConsumerWidget {
  const SkipClassificationPage({super.key, required this.podcastId});

  final int podcastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcast = ref.watch(podcastProvider(podcastId));
    return podcast.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          title: 'Podcast introuvable',
          message: error.toString(),
        ),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              title: 'Podcast introuvable',
              message: 'Cet abonnement n’est plus dans la bibliothèque.',
            ),
          );
        }
        final theme = Theme.of(context);
        final classification = ref.watch(skipClassificationProvider(podcastId));
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Skip ads and jingles'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: underChrome(context, const EdgeInsets.only(bottom: 32)),
            children: [
              _Section(context.tr('Skip automatically')),
              SwitchListTile(
                title: Text(context.tr('Skip automatically')),
                subtitle: Text(
                  context.tr('Skips confirmed passages in downloaded episodes'),
                ),
                value: item.autoSkipAds,
                onChanged: (enabled) => _setAutoSkip(ref, item, enabled),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  context.tr('Kinds to skip'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              for (final kind in SkipSegmentKind.values)
                SwitchListTile(
                  title: Text(context.tr(skipKindLabel(kind))),
                  value: decodeAutoSkipKinds(item.autoSkipKinds).contains(kind),
                  onChanged: (enabled) =>
                      _toggleKind(ref, item, kind, enabled: enabled),
                ),
              _Section(context.tr('Detected segments')),
              ..._segmentTiles(context, ref, classification),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _segmentTiles(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<SkipClassification> classification,
  ) {
    return classification.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, _) => [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error.toString()),
        ),
      ],
      data: (data) {
        final grouped = <SkipSegmentKind, List<_Row>>{};
        for (final template in data.templates) {
          grouped
              .putIfAbsent(template.kind, () => [])
              .add(
                _Row.template(
                  template,
                  confirmed: data.templateConfirmed[template.id],
                ),
              );
        }
        for (final loose in data.segments) {
          grouped
              .putIfAbsent(loose.segment.kind, () => [])
              .add(_Row.segment(loose));
        }
        if (grouped.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Text(
                context.tr(
                  'Segments show up after a download is analyzed, or when a chapter title looks like an ad.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ];
        }
        final tiles = <Widget>[];
        for (final kind in SkipSegmentKind.values) {
          final rows = grouped[kind];
          if (rows == null || rows.isEmpty) continue;
          tiles.add(_Section(context.tr(skipKindLabel(kind))));
          for (final row in rows) {
            tiles.add(_SegmentTile(podcastId: podcastId, row: row));
          }
        }
        return tiles;
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _Row {
  const _Row.template(this.template, {required this.confirmed}) : loose = null;

  const _Row.segment(this.loose) : template = null, confirmed = null;

  final SegmentTemplate? template;
  final LooseSkipSegment? loose;

  /// Avis du modèle. Ignoré pour un passage isolé (il a le sien).
  final bool? confirmed;

  bool get isTemplate => template != null;
}

class _SegmentTile extends ConsumerWidget {
  const _SegmentTile({required this.podcastId, required this.row});

  final int podcastId;
  final _Row row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = row.template;
    final loose = row.loose;
    final title = template != null
        ? _templateTitle(context, template)
        : loose!.episodeTitle;
    final durationMs =
        template?.durationMs ?? (loose!.segment.endMs - loose.segment.startMs);
    final count = template?.occurrences ?? loose!.segment.matches;
    final review = template != null ? row.confirmed : loose!.segment.confirmed;
    final range = loose == null
        ? null
        : '${formatClock(Duration(milliseconds: loose.segment.startMs))}'
              '–${formatClock(Duration(milliseconds: loose.segment.endMs))}';
    final subtitle = [
      ?range,
      formatClock(Duration(milliseconds: durationMs < 0 ? 0 : durationMs)),
      _episodeCount(context, count),
      context.tr(_reviewKey(review)),
    ].join(' · ');
    return ListTile(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.tr('Preview'),
            icon: const Icon(Icons.play_arrow),
            onPressed: () => _preview(context, ref),
          ),
          PopupMenuButton<_SegmentAction>(
            onSelected: (action) => _run(context, ref, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SegmentAction.kind,
                child: Text(context.tr('Change kind')),
              ),
              PopupMenuItem(
                value: _SegmentAction.confirm,
                child: Text(context.tr('Confirm')),
              ),
              PopupMenuItem(
                value: _SegmentAction.ignore,
                child: Text(context.tr('Ignore')),
              ),
              if (template != null)
                PopupMenuItem(
                  value: _SegmentAction.rename,
                  child: Text(context.tr('Rename')),
                ),
              PopupMenuItem(
                value: _SegmentAction.delete,
                child: Text(context.tr('Delete')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _preview(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final int episodeId;
    final int startMs;
    final int segmentId;
    final template = row.template;
    if (template != null) {
      final target = await db.previewTargetForTemplate(template.id);
      if (!context.mounted) return;
      if (target == null) {
        showMessage(
          context,
          context.tr('Download the episode to preview this passage.'),
        );
        return;
      }
      episodeId = target.episodeId;
      startMs = target.startMs;
      segmentId = target.segmentId;
    } else {
      final loose = row.loose!;
      final path = loose.downloadPath?.trim() ?? '';
      if (path.isEmpty) {
        showMessage(
          context,
          context.tr('Download the episode to preview this passage.'),
        );
        return;
      }
      episodeId = loose.segment.episodeId;
      startMs = loose.segment.startMs;
      segmentId = loose.segment.id;
    }
    final entry = await db.getEpisode(episodeId);
    if (!context.mounted) return;
    final path = entry?.episode.downloadPath?.trim() ?? '';
    if (entry == null || path.isEmpty) {
      showMessage(
        context,
        context.tr('Download the episode to preview this passage.'),
      );
      return;
    }
    await ref
        .read(playerProvider.notifier)
        .previewPassage(
          entry,
          position: Duration(milliseconds: startMs),
          segmentId: segmentId,
        );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _SegmentAction action,
  ) async {
    final db = ref.read(databaseProvider);
    final template = row.template;
    final segment = row.loose?.segment;
    switch (action) {
      case _SegmentAction.kind:
        final current = template?.kind ?? segment!.kind;
        final choice = await showChoiceDialog<SkipSegmentKind>(
          context,
          title: 'Change kind',
          selected: current,
          options: [
            for (final kind in SkipSegmentKind.values)
              (value: kind, label: skipKindLabel(kind)),
          ],
        );
        if (choice == null || choice == current) return;
        if (template != null) {
          await db.setTemplateKind(template.id, choice);
        } else {
          await db.setSkipSegmentKind(segment!.id, choice);
        }
      case _SegmentAction.confirm:
        if (template != null) {
          await db.setTemplateReview(template.id, confirmed: true);
        } else {
          await db.setSkipSegmentReview(segment!.id, confirmed: true);
        }
      case _SegmentAction.ignore:
        if (template != null) {
          await db.setTemplateReview(template.id, confirmed: false);
        } else {
          await db.setSkipSegmentReview(segment!.id, confirmed: false);
        }
      case _SegmentAction.rename:
        if (template == null) return;
        final label = await _askLabel(context, template.label);
        if (label == null) return;
        await db.setTemplateLabel(template.id, label);
      case _SegmentAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('Delete this passage?')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.tr('Delete')),
              ),
            ],
          ),
        );
        if (ok != true) return;
        if (template != null) {
          await db.deleteSegmentTemplate(template.id);
        } else {
          await db.deleteSkipSegment(segment!.id);
        }
    }
  }
}

enum _SegmentAction { kind, confirm, ignore, rename, delete }

Future<void> _setAutoSkip(WidgetRef ref, Podcast item, bool enabled) async {
  final db = ref.read(databaseProvider);
  await db.setPodcastAutoSkip(item.id, autoSkipAds: enabled);
  if (enabled && decodeAutoSkipKinds(item.autoSkipKinds).isEmpty) {
    await db.setPodcastAutoSkip(
      item.id,
      autoSkipKinds: const [SkipSegmentKind.ad, SkipSegmentKind.sponsor],
    );
  }
}

Future<void> _toggleKind(
  WidgetRef ref,
  Podcast item,
  SkipSegmentKind kind, {
  required bool enabled,
}) async {
  final selected = decodeAutoSkipKinds(item.autoSkipKinds).toSet();
  if (enabled) {
    selected.add(kind);
  } else {
    selected.remove(kind);
  }
  await ref
      .read(databaseProvider)
      .setPodcastAutoSkip(
        item.id,
        autoSkipKinds: [
          for (final value in SkipSegmentKind.values)
            if (selected.contains(value)) value,
        ],
      );
}

String _templateTitle(BuildContext context, SegmentTemplate template) {
  final label = template.label?.trim() ?? '';
  if (label.isNotEmpty) return label;
  return context.tr('Unnamed pattern');
}

String _episodeCount(BuildContext context, int count) {
  if (count == 1) return context.tr('1 episode');
  return context.tr('{count} episodes', {'count': '$count'});
}

String _reviewKey(bool? confirmed) {
  if (confirmed == true) return 'Confirmed';
  if (confirmed == false) return 'Ignored';
  return 'Unreviewed';
}

Future<String?> _askLabel(BuildContext context, String? current) async {
  final controller = TextEditingController(text: current ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('Rename label')),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: context.tr('Label')),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(context.tr('Apply')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
