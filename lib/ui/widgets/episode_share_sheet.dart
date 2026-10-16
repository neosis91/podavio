import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../player/player_controller.dart';
import 'brand.dart';

Future<void> shareEpisode(EpisodeEntry entry) {
  return shareEpisodeAsMessage(entry, position: null);
}

Future<void> shareEpisodeAsMessage(EpisodeEntry entry, {Duration? position}) {
  final text = [
    entry.episode.title,
    entry.podcast.title,
    if (position != null && position > Duration.zero)
      'Position : ${formatClock(position)}',
    entry.episode.audioUrl,
  ].join('\n');
  return SharePlus.instance.share(
    ShareParams(text: text, title: entry.episode.title),
  );
}

Future<void> shareEpisodeAudioUrl(EpisodeEntry entry) {
  return SharePlus.instance.share(
    ShareParams(text: entry.episode.audioUrl, title: entry.episode.title),
  );
}

Future<void> showShareEpisodeSheet(
  BuildContext context,
  WidgetRef ref,
  EpisodeEntry entry,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _ShareEpisodeSheet(entry: entry),
  );
}

class _ShareEpisodeSheet extends ConsumerStatefulWidget {
  const _ShareEpisodeSheet({required this.entry});

  final EpisodeEntry entry;

  @override
  ConsumerState<_ShareEpisodeSheet> createState() => _ShareEpisodeSheetState();
}

class _ShareEpisodeSheetState extends ConsumerState<_ShareEpisodeSheet> {
  var _includePosition = false;

  Duration get _position {
    final player = ref.read(playerProvider);
    if (player.episodeId == widget.entry.episode.id) {
      return player.position;
    }
    return Duration(milliseconds: widget.entry.episode.positionMs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position = _position;
    final positionLabel = formatClock(position);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Partager', style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'Message',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ListTile(
              leading: const ShareIcon(),
              title: const Text('Titre et lien'),
              subtitle: const Text('Idéal pour un message'),
              onTap: () async {
                final includePosition = _includePosition;
                final pos = _position;
                Navigator.pop(context);
                await shareEpisodeAsMessage(
                  widget.entry,
                  position: includePosition ? pos : null,
                );
              },
            ),
            CheckboxListTile(
              value: _includePosition,
              onChanged: position > Duration.zero
                  ? (value) => setState(() => _includePosition = value ?? false)
                  : null,
              title: const Text('Inclure la position de lecture'),
              subtitle: Text(
                position > Duration.zero ? positionLabel : 'Aucune position',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Text(
                'Fichier',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Lien du fichier'),
              subtitle: Text(
                widget.entry.episode.audioUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                Navigator.pop(context);
                await shareEpisodeAudioUrl(widget.entry);
              },
            ),
          ],
        ),
      ),
    );
  }
}
