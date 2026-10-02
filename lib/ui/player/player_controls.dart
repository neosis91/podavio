part of '../player_page.dart';

class _PlayerTransport extends ConsumerWidget {
  const _PlayerTransport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final playing = ref.watch(playerProvider.select((s) => s.playing));
    final carMode = ref.watch(playerProvider.select((s) => s.carMode));
    final speed = ref.watch(playerProvider.select((s) => s.speed));
    final volume = ref.watch(playerProvider.select((s) => s.volume));
    final settings = ref.watch(settingsProvider);
    final totalMs = duration.inMilliseconds;
    final positionMs = position.inMilliseconds.clamp(
      0,
      totalMs == 0 ? 0 : totalMs,
    );
    final hasNext = ref.watch(hasNextInQueueProvider).value ?? false;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final sideIconSize = carMode ? 48.0 : 36.0;
    final skipIconSize = carMode ? 56.0 : 36.0;
    const playIconSize = 36.0;
    const playButtonSize = 56.0;
    final gap = carMode ? 12.0 : 4.0;
    final skipGap = carMode ? 12.0 : 8.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
          children: [
            Text(formatClock(position)),
            const Spacer(),
            Text(
              settings.showRemainingTime
                  ? '−${formatClock(duration - position)}'
                  : formatClock(duration),
            ),
            IconButton(
              tooltip: 'Volume (− / =)',
              visualDensity: VisualDensity.compact,
              onPressed: () => _chooseVolume(context, ref),
              icon: Icon(_volumeIcon(volume)),
            ),
          ],
        ),
        SizedBox(height: carMode ? 12 : 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TransportControl(
                tooltip: 'Vitesse de lecture',
                label: _formatSpeed(speed),
                labelStyle: labelStyle,
                onPressed: () => _chooseSpeed(context, ref, speed),
                icon: Icon(Icons.speed, size: sideIconSize),
                iconSize: sideIconSize,
              ),
              SizedBox(width: gap),
              _TransportControl(
                tooltip:
                    'Reculer de ${settings.skipBackSeconds} s (J)',
                label: '−${settings.skipBackSeconds} s',
                labelStyle: labelStyle,
                onPressed: () => ref
                    .read(playerProvider.notifier)
                    .skipBy(-settings.skipBackSeconds),
                icon: SkipIcon.back(size: skipIconSize),
                iconSize: skipIconSize,
              ),
              if (!carMode) ...[
                SizedBox(width: skipGap),
                _TransportControl(
                  tooltip:
                      playing ? 'Pause (Espace)' : 'Lecture (Espace)',
                  label: '',
                  labelStyle: labelStyle,
                  filled: true,
                  iconSize: playButtonSize,
                  onPressed: () => ref.read(playerProvider.notifier).toggle(),
                  icon: PlayPauseIcon(
                    playing: playing,
                    size: playIconSize,
                  ),
                ),
              ],
              SizedBox(width: skipGap),
              _TransportControl(
                tooltip: 'Avancer de ${settings.skipForwardSeconds} s (L)',
                label: '+${settings.skipForwardSeconds} s',
                labelStyle: labelStyle,
                onPressed: () => ref
                    .read(playerProvider.notifier)
                    .skipBy(settings.skipForwardSeconds),
                icon: SkipIcon.forward(size: skipIconSize),
                iconSize: skipIconSize,
              ),
              SizedBox(width: gap),
              _TransportControl(
                tooltip: hasNext
                    ? 'Épisode suivant'
                    : 'Pas d’épisode suivant dans la playlist',
                label: '',
                labelStyle: labelStyle,
                onPressed: hasNext
                    ? () => ref.read(playerProvider.notifier).playNextInQueue()
                    : null,
                icon: SkipIcon.next(size: sideIconSize),
                iconSize: sideIconSize,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatSpeed(double speed) {
  final text = speed == speed.roundToDouble()
      ? speed.toInt().toString()
      : speed.toString();
  return '$text×';
}

String _formatVolume(double volume) {
  return '${(volume * 100).round()} %';
}

IconData _volumeIcon(double volume) {
  if (volume <= 0) return Icons.volume_off;
  if (volume < 0.34) return Icons.volume_mute;
  if (volume < 0.67) return Icons.volume_down;
  return Icons.volume_up;
}

class _TransportControl extends StatelessWidget {
  const _TransportControl({
    required this.icon,
    required this.label,
    required this.labelStyle,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.iconSize = 36,
  });

  final Widget icon;
  final String label;
  final TextStyle? labelStyle;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? IconButton.filled(
            tooltip: tooltip,
            iconSize: iconSize,
            onPressed: onPressed,
            icon: icon,
          )
        : IconButton(
            tooltip: tooltip,
            iconSize: iconSize,
            onPressed: onPressed,
            icon: icon,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        SizedBox(
          height: 16,
          child: label.isEmpty
              ? null
              : Text(label, style: labelStyle, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _SleepAction extends ConsumerWidget {
  const _SleepAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleepAtEnd = ref.watch(
      playerProvider.select((s) => s.sleepAtEnd),
    );
    final sleepEndsAt = ref.watch(
      playerProvider.select((s) => s.sleepEndsAt),
    );
    return IconButton(
      tooltip: _sleepLabel(sleepAtEnd: sleepAtEnd, sleepEndsAt: sleepEndsAt),
      onPressed: () => _chooseSleep(context, ref),
      icon: const TimerIcon(size: 24),
    );
  }
}

class _FavoriteAction extends ConsumerWidget {
  const _FavoriteAction({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(episodeProvider(episodeId)).value;
    if (entry == null) return const SizedBox.shrink();
    final favorite = entry.episode.favorite;
    return IconButton(
      tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      onPressed: () => runEpisodeAction(
        context,
        ref,
        entry,
        EpisodeMenuAction.favorite,
      ),
      icon: Icon(favorite ? Icons.favorite : Icons.favorite_outline),
    );
  }
}

class _ShareAction extends ConsumerWidget {
  const _ShareAction({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(episodeProvider(episodeId)).value;
    if (entry == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Partager',
      onPressed: () => runEpisodeAction(
        context,
        ref,
        entry,
        EpisodeMenuAction.share,
      ),
      icon: const ShareIcon(size: 24),
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
    final website = _podcastWebsite(entry.podcast.link);
    final carMode = ref.watch(playerProvider.select((state) => state.carMode));
    // Mode voiture : téléphone uniquement (même seuil que la grille podcasts).
    final showCarMode = MediaQuery.sizeOf(context).shortestSide < 600;
    return PopupMenuButton<_PlayerMenuAction>(
      onSelected: (action) => _onSelected(context, ref, entry, action),
      itemBuilder: (context) => [
        if (showCarMode)
          PopupMenuItem(
            value: _PlayerMenuAction.toggleCarMode,
            child: Row(
              children: [
                Icon(
                  carMode
                      ? Icons.directions_car
                      : Icons.directions_car_outlined,
                ),
                const SizedBox(width: 12),
                Text(carMode ? 'Quitter le mode voiture' : 'Mode voiture'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: _PlayerMenuAction.openPodcast,
          child: Row(
            children: [
              PodcastsIcon(),
              SizedBox(width: 12),
              Text('Ouvrir le podcast'),
            ],
          ),
        ),
        if (website != null)
          const PopupMenuItem(
            value: _PlayerMenuAction.openWebsite,
            child: Row(
              children: [
                LinkIcon(),
                SizedBox(width: 12),
                Text('Ouvrir le site web'),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    EpisodeEntry entry,
    _PlayerMenuAction action,
  ) async {
    switch (action) {
      case _PlayerMenuAction.toggleCarMode:
        final enabled = !ref.read(playerProvider).carMode;
        ref.read(playerProvider.notifier).setCarMode(enabled);
      case _PlayerMenuAction.openPodcast:
        ref.read(playerSheetProvider.notifier).collapse();
        if (context.mounted) {
          context.push(AppRoutes.podcast(entry.podcast.id));
        }
      case _PlayerMenuAction.openWebsite:
        final website = _podcastWebsite(entry.podcast.link);
        if (website == null) return;
        final opened = await launchUrl(
          website,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && context.mounted) {
          showMessage(context, 'Impossible d’ouvrir le site web');
        }
    }
  }
}

enum _PlayerMenuAction { toggleCarMode, openPodcast, openWebsite }

Uri? _podcastWebsite(String? link) {
  final raw = link?.trim();
  if (raw == null || raw.isEmpty) return null;
  final withScheme = raw.contains('://') ? raw : 'https://$raw';
  final uri = Uri.tryParse(withScheme);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}

String _sleepLabel({
  required bool sleepAtEnd,
  required DateTime? sleepEndsAt,
}) {
  if (sleepAtEnd) return 'Fin de l’épisode';
  if (sleepEndsAt == null) return 'Minuteur';
  final remaining = sleepEndsAt.difference(DateTime.now());
  if (remaining.isNegative) return formatClock(Duration.zero);
  return formatClock(remaining);
}

