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
    final clockSpeed = settings.timeRespectsSpeed ? speed : 1.0;
    final displayPosition = durationAtSpeed(position, clockSpeed);
    final displayDuration = durationAtSpeed(duration, clockSpeed);
    final displayRemaining = durationAtSpeed(duration - position, clockSpeed);
    final hasNext = ref.watch(hasNextInQueueProvider).value ?? false;
    final episodeId = ref.watch(playerProvider.select((s) => s.episodeId));
    final chapters = episodeId == null
        ? const <EpisodeChapter>[]
        : (ref.watch(chaptersProvider(episodeId)).value ??
              const <EpisodeChapter>[]);
    final hasChapters = chapters.isNotEmpty;
    final player = ref.read(playerProvider.notifier);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final clockStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final sideIconSize = carMode ? 48.0 : 32.0;
    final skipIconSize = carMode ? 48.0 : 28.0;
    const playIconSize = 36.0;
    const playButtonSize = 56.0;
    void toggleRemaining() {
      ref
          .read(settingsProvider.notifier)
          .setShowRemainingTime(!settings.showRemainingTime);
    }

    final scheme = Theme.of(context).colorScheme;
    final activeChapter = currentChapterFor(chapters, position);
    final showChapterMarkers = totalMs > 0 && chapters.isNotEmpty;
    final sliderTheme = SliderTheme.of(context);
    final thumbWidth = (sliderTheme.thumbShape ?? const RoundSliderThumbShape())
        .getPreferredSize(true, false)
        .width;
    final overlayWidth =
        (sliderTheme.overlayShape ?? const RoundSliderOverlayShape())
            .getPreferredSize(true, false)
            .width;
    // Même inset horizontal que BaseSliderTrackShape.getPreferredRect.
    final trackInset = sliderTheme.padding == null
        ? math.max(overlayWidth / 2, thumbWidth / 2)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (showChapterMarkers)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ChapterMarkersPainter(
                      chapters: chapters,
                      durationMs: totalMs,
                      activeStartMs: activeChapter?.startMs,
                      markerColor: scheme.onSurfaceVariant,
                      activeColor: scheme.primary,
                      trackInset: trackInset,
                    ),
                  ),
                ),
              ),
            Slider(
              value: totalMs == 0 ? 0 : positionMs.toDouble(),
              max: totalMs == 0 ? 1 : totalMs.toDouble(),
              onChanged: totalMs == 0
                  ? null
                  : (value) =>
                        player.seek(Duration(milliseconds: value.round())),
            ),
          ],
        ),
        Row(
          children: [
            Tooltip(
              message: settings.showRemainingTime
                  ? 'Afficher la durée totale'
                  : 'Afficher le temps restant',
              child: InkWell(
                onTap: toggleRemaining,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Text(formatClock(displayPosition), style: clockStyle),
                ),
              ),
            ),
            const Spacer(),
            Tooltip(
              message: settings.showRemainingTime
                  ? 'Afficher la durée totale'
                  : 'Afficher le temps restant',
              child: InkWell(
                onTap: toggleRemaining,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Text(
                    settings.showRemainingTime
                        ? '−${formatClock(displayRemaining)}'
                        : formatClock(displayDuration),
                    style: clockStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: carMode ? 8 : 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'Reculer de ${settings.skipBackSeconds} s (J)',
              onPressed: () => player.skipBy(-settings.skipBackSeconds),
              icon: SkipIcon.back(size: skipIconSize),
            ),
            IconButton(
              tooltip: 'Épisode précédent',
              iconSize: sideIconSize,
              onPressed: player.playPreviousInQueue,
              icon: Icon(Icons.skip_previous, size: sideIconSize),
            ),
            if (!carMode)
              IconButton.filled(
                tooltip: playing ? 'Pause (Espace)' : 'Lecture (Espace)',
                iconSize: playIconSize,
                style: IconButton.styleFrom(
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                  fixedSize: const Size(
                    playButtonSize + 16,
                    playButtonSize + 16,
                  ),
                ),
                onPressed: player.toggle,
                icon: PlayPauseIcon(
                  playing: playing,
                  size: playIconSize,
                  color: scheme.surface,
                ),
              ),
            IconButton(
              tooltip: hasNext
                  ? 'Épisode suivant'
                  : 'Pas d’épisode suivant dans la playlist',
              iconSize: sideIconSize,
              onPressed: hasNext ? player.playNextInQueue : null,
              icon: SkipIcon.next(size: sideIconSize),
            ),
            IconButton(
              tooltip: 'Avancer de ${settings.skipForwardSeconds} s (L)',
              onPressed: () => player.skipBy(settings.skipForwardSeconds),
              icon: SkipIcon.forward(size: skipIconSize),
            ),
          ],
        ),
        if (!carMode) ...[
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'Vitesse ${_formatSpeed(speed)}',
                        onPressed: () => _chooseSpeed(context, ref),
                        icon: Text(
                          _formatSpeed(speed),
                          style: labelStyle?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (hasChapters)
                        IconButton(
                          tooltip: 'Chapitres',
                          onPressed: episodeId == null
                              ? null
                              : () => showChaptersSheet(
                                  context: context,
                                  ref: ref,
                                  episodeId: episodeId,
                                ),
                          icon: const Icon(Icons.list_alt),
                        ),
                      IconButton(
                        tooltip: 'Notes',
                        onPressed: episodeId == null
                            ? null
                            : () => showNotesSheet(
                                context: context,
                                episodeId: episodeId,
                              ),
                        icon: const InfoIcon(),
                      ),
                      const _QueueAction(),
                      const _SleepAction(),
                      IconButton(
                        tooltip: 'Volume (− / =)',
                        onPressed: () => _chooseVolume(context, ref),
                        icon: Icon(_volumeIcon(volume)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Repères de chapitres alignés sur la piste du [Slider] Material.
class _ChapterMarkersPainter extends CustomPainter {
  const _ChapterMarkersPainter({
    required this.chapters,
    required this.durationMs,
    required this.activeStartMs,
    required this.markerColor,
    required this.activeColor,
    required this.trackInset,
  });

  final List<EpisodeChapter> chapters;
  final int durationMs;
  final int? activeStartMs;
  final Color markerColor;
  final Color activeColor;
  final double trackInset;

  @override
  void paint(Canvas canvas, Size size) {
    if (durationMs <= 0 || chapters.isEmpty) return;

    final trackLeft = trackInset;
    final trackWidth = size.width - trackInset * 2;
    if (trackWidth <= 0) return;

    final trackCenterY = size.height / 2;
    const markerHalfHeight = 6.0;
    final inactivePaint = Paint()
      ..color = markerColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (final chapter in chapters) {
      final start = chapter.startMs;
      if (start < 0 || start > durationMs) continue;
      final x = trackLeft + trackWidth * (start / durationMs);
      final isActive = activeStartMs != null && start == activeStartMs;
      canvas.drawLine(
        Offset(x, trackCenterY - markerHalfHeight),
        Offset(x, trackCenterY + markerHalfHeight),
        isActive ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChapterMarkersPainter oldDelegate) {
    return oldDelegate.chapters != chapters ||
        oldDelegate.durationMs != durationMs ||
        oldDelegate.activeStartMs != activeStartMs ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackInset != trackInset;
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

class _QueueAction extends ConsumerWidget {
  const _QueueAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(queueCountProvider).value ?? 0;
    final open = ref.watch(_playerPanelProvider) == _PlayerPanel.playlist;
    final scheme = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : '$count';
    return IconButton(
      tooltip: open
          ? 'Revenir à l’épisode'
          : (count == 0 ? 'Playlist' : 'Playlist ($count)'),
      isSelected: open,
      style: IconButton.styleFrom(
        backgroundColor: open ? scheme.secondaryContainer : null,
      ),
      onPressed: () => ref.read(_playerPanelProvider.notifier).toggle(),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        label: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        child: const PlaylistPlayIcon(),
      ),
    );
  }
}

class _SleepAction extends ConsumerWidget {
  const _SleepAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sélectionner le libellé (change chaque seconde), pas sleepEndsAt
    // (DateTime fixe → pas de rebuild avec select).
    final badgeText = ref.watch(
      playerProvider.select((s) => _sleepBadgeText(s)),
    );
    final active = badgeText != null;
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: badgeText == null
          ? 'Minuteur'
          : badgeText == 'Fin'
          ? 'Fin de l’épisode'
          : badgeText,
      onPressed: () => _chooseSleep(context, ref),
      style: active
          ? IconButton.styleFrom(foregroundColor: scheme.primary)
          : null,
      icon: Badge(
        isLabelVisible: active,
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        label: badgeText == null
            ? null
            : Text(
                badgeText,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
        child: const TimerIcon(size: 24),
      ),
    );
  }
}

/// Texte du badge sommeil, ou `null` si inactif.
String? _sleepBadgeText(PlayerUiState state) {
  if (state.sleepAtEnd) return 'Fin';
  final ends = state.sleepEndsAt;
  if (ends == null) return null;
  final remaining = ends.difference(DateTime.now());
  if (remaining.isNegative) return '0:00';
  return formatClock(remaining);
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
      onPressed: () =>
          runEpisodeAction(context, ref, entry, EpisodeMenuAction.favorite),
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
      onPressed: () =>
          runEpisodeAction(context, ref, entry, EpisodeMenuAction.share),
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
