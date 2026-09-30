import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../data/providers.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'widgets/brand.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_tile.dart';

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeId = ref.watch(
      playerProvider.select((state) => state.episodeId),
    );
    if (episodeId == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Réduire',
            onPressed: () => Navigator.of(context).pop(),
            icon: const SkipIcon.collapse(),
          ),
        ),
        body: const EmptyState(
          title: 'Aucune lecture',
          message: 'Lancez un épisode pour ouvrir le lecteur.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Réduire',
          onPressed: () => Navigator.of(context).pop(),
          icon: const SkipIcon.collapse(),
        ),
        title: const Text('Lecture'),
        actions: [
          const _SleepAction(),
          _PlayerActions(episodeId: episodeId),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PlayerHeading(),
                  const _PlayerTransport(),
                  _PlayerNotes(episodeId: episodeId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerHeading extends ConsumerWidget {
  const _PlayerHeading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(playerProvider.select((state) => state.title));
    final podcastTitle = ref.watch(
      playerProvider.select((state) => state.podcastTitle),
    );
    final imageUrl = ref.watch(
      playerProvider.select((state) => state.imageUrl),
    );
    final imagePath = ref.watch(
      playerProvider.select((state) => state.imagePath),
    );
    final error = ref.watch(playerProvider.select((state) => state.error));
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: PodcastCover(
            url: imageUrl,
            localPath: imagePath,
            size: 280,
            radius: 24,
          ),
        ),
        const SizedBox(height: 24),
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          podcastTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}

class _PlayerTransport extends ConsumerWidget {
  const _PlayerTransport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final settings = ref.watch(settingsProvider);
    final totalMs = player.duration.inMilliseconds;
    final positionMs = player.position.inMilliseconds.clamp(
      0,
      totalMs == 0 ? 0 : totalMs,
    );
    return Column(
      children: [
        const SizedBox(height: 12),
        Slider(
          value: totalMs == 0 ? 0 : positionMs.toDouble(),
          max: totalMs == 0 ? 1 : totalMs.toDouble(),
          onChanged: totalMs == 0
              ? null
              : (value) => ref
                    .read(playerProvider.notifier)
                    .seek(Duration(milliseconds: value.round())),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatClock(player.position)),
            Text(formatClock(player.duration)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Reculer de ${settings.skipBackSeconds} s',
              iconSize: 36,
              onPressed: () => ref
                  .read(playerProvider.notifier)
                  .skipBy(-settings.skipBackSeconds),
              icon: const SkipIcon.back(size: 36),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              tooltip: player.playing ? 'Pause' : 'Lecture',
              iconSize: 56,
              onPressed: () => ref.read(playerProvider.notifier).toggle(),
              icon: PlayPauseIcon(playing: player.playing, size: 36),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Avancer de ${settings.skipForwardSeconds} s',
              iconSize: 36,
              onPressed: () => ref
                  .read(playerProvider.notifier)
                  .skipBy(settings.skipForwardSeconds),
              icon: const SkipIcon.forward(size: 36),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: ActionChip(
            avatar: const Icon(Icons.speed, size: 18),
            label: Text('${player.speed}×'),
            onPressed: () => _chooseSpeed(context, ref, player.speed),
          ),
        ),
      ],
    );
  }
}

class _SleepAction extends ConsumerWidget {
  const _SleepAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final active = player.sleepAtEnd || player.sleepRemaining != null;
    return IconButton(
      tooltip: _sleepLabel(player),
      onPressed: () => _chooseSleep(context, ref),
      icon: Icon(active ? Icons.bedtime : Icons.bedtime_outlined),
    );
  }
}

class _PlayerNotes extends ConsumerWidget {
  const _PlayerNotes({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes =
        ref.watch(episodeProvider(episodeId)).value?.episode.description ?? '';
    final text = plainText(notes);
    if (text.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Notes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _PlayerActions extends ConsumerWidget {
  const _PlayerActions({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(episodeProvider(episodeId)).value;
    if (entry == null) return const SizedBox.shrink();
    final episode = entry.episode;
    return PopupMenuButton<EpisodeMenuAction>(
      onSelected: (action) => runEpisodeAction(context, ref, entry, action),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: EpisodeMenuAction.queue,
          child: Text(
            episode.queueIndex == null
                ? 'Ajouter à la file'
                : 'Retirer de la file',
          ),
        ),
        PopupMenuItem(
          value: EpisodeMenuAction.favorite,
          child: Text(
            episode.favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
          ),
        ),
        PopupMenuItem(
          value: EpisodeMenuAction.download,
          child: Text(
            episode.downloadPath == null
                ? 'Télécharger'
                : 'Supprimer le téléchargement',
          ),
        ),
        const PopupMenuItem(
          value: EpisodeMenuAction.share,
          child: Text('Partager'),
        ),
      ],
    );
  }
}

String _sleepLabel(PlayerUiState player) {
  if (player.sleepAtEnd) return 'Fin de l’épisode';
  final remaining = player.sleepRemaining;
  if (remaining == null) return 'Minuteur';
  return formatClock(remaining);
}

Future<void> _chooseSpeed(
  BuildContext context,
  WidgetRef ref,
  double current,
) async {
  const speeds = [0.8, 1.0, 1.2, 1.5, 1.8, 2.0, 2.5, 3.0];
  final selected = await showModalBottomSheet<double>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final speed in speeds)
            ListTile(
              title: Text('$speed×'),
              trailing: speed == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, speed),
            ),
        ],
      ),
    ),
  );
  if (selected != null) {
    await ref.read(playerProvider.notifier).setSpeed(selected);
  }
}

Future<void> _chooseSleep(BuildContext context, WidgetRef ref) async {
  final choice = await showModalBottomSheet<_SleepChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Désactivé'),
            onTap: () => Navigator.pop(context, const _SleepChoice.off()),
          ),
          for (final minutes in [5, 15, 30, 45, 60])
            ListTile(
              title: Text('$minutes minutes'),
              onTap: () => Navigator.pop(
                context,
                _SleepChoice.duration(Duration(minutes: minutes)),
              ),
            ),
          ListTile(
            title: const Text('Fin de l’épisode'),
            onTap: () => Navigator.pop(context, const _SleepChoice.end()),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  ref
      .read(playerProvider.notifier)
      .setSleep(choice.duration, atEnd: choice.atEnd);
}

class _SleepChoice {
  const _SleepChoice.off() : duration = null, atEnd = false;
  const _SleepChoice.end() : duration = null, atEnd = true;
  const _SleepChoice.duration(this.duration) : atEnd = false;

  final Duration? duration;
  final bool atEnd;
}
