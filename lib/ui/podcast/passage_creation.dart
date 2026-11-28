import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../data/audio_analysis.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../player/player_controller.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/messages.dart';
import 'segment_editor_page.dart';

enum _NotAnalysed { analyse, createAnyway }

/// Ouvre la création d’une portion dans [episodeId].
///
/// Le début est posé à [positionMs], sinon à la position de lecture si
/// l’épisode joue, sinon au début. Un épisode non téléchargé ne s’ouvre pas ;
/// sans enveloppe (pas encore analysé), l’analyse est proposée d’abord.
Future<void> openPassageCreator(
  BuildContext context,
  WidgetRef ref,
  int episodeId, {
  int? positionMs,
}) async {
  final database = ref.read(databaseProvider);
  final entry = await database.getEpisode(episodeId);
  if (!context.mounted || entry == null) return;
  if ((entry.episode.downloadPath?.trim() ?? '').isEmpty) {
    showMessage(
      context,
      context.tr('Download the episode to create a passage in it.'),
    );
    return;
  }
  final envelope = await database.envelopeForEpisode(episodeId);
  if (!context.mounted) return;
  if (envelope == null) {
    final choice = await showDialog<_NotAnalysed>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('This episode is not analysed yet')),
        content: Text(
          context.tr(
            'Analyse it first to see its waveform. A passage created now '
            'gets its fingerprint once the episode is analysed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _NotAnalysed.createAnyway),
            child: Text(context.tr('Create anyway')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _NotAnalysed.analyse),
            child: Text(context.tr('Analyse')),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == _NotAnalysed.analyse) {
      unawaited(
        ref.read(audioAnalysisProvider.notifier).enqueueEpisode(episodeId),
      );
      showMessage(
        context,
        context.tr('Analysis started. Come back once it is done.'),
      );
      return;
    }
  }
  final player = ref.read(playerProvider);
  final start =
      positionMs ??
      (player.episodeId == episodeId ? player.position.inMilliseconds : 0);
  await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      builder: (_) =>
          SegmentEditorPage.create(episodeId: episodeId, positionMs: start),
    ),
  );
}

/// Choisit un épisode de [podcastId] (analysés d’abord), puis ouvre la
/// création d’une portion dedans.
Future<void> pickEpisodeForPassage(
  BuildContext context,
  WidgetRef ref,
  int podcastId,
) async {
  final choices = await ref
      .read(databaseProvider)
      .passageEpisodeChoices(podcastId);
  if (!context.mounted) return;
  if (choices.isEmpty) {
    showMessage(context, context.tr('No episodes in this podcast.'));
    return;
  }
  final episodeId = await showAppModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => PassageEpisodePicker(choices: choices),
  );
  if (episodeId == null || !context.mounted) return;
  await openPassageCreator(context, ref, episodeId);
}

/// Liste des épisodes où créer une portion. Renvoie l’id choisi.
class PassageEpisodePicker extends StatelessWidget {
  const PassageEpisodePicker({super.key, required this.choices});

  final List<PassageEpisodeChoice> choices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                context.tr('Choose an episode'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final choice in choices)
                    ListTile(
                      leading: Icon(
                        choice.analysed
                            ? Icons.graphic_eq
                            : choice.downloaded
                            ? Icons.download_done
                            : Icons.cloud_outlined,
                      ),
                      title: Text(
                        choice.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        context.tr(
                          choice.analysed
                              ? 'Analysed'
                              : choice.downloaded
                              ? 'Not analysed yet'
                              : 'Not downloaded',
                        ),
                      ),
                      onTap: () => Navigator.pop(context, choice.episodeId),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
