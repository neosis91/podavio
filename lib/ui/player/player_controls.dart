import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../player/player_controller.dart';
import '../../settings/settings_controller.dart';
import '../widgets/brand.dart';
import '../widgets/episode_tile.dart';
import 'audio_output_sheet.dart';
import 'player_chapter.dart';
import 'player_panel.dart';
import 'player_sheets.dart';

class PlayerTransport extends ConsumerWidget {
  const PlayerTransport({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final playing = ref.watch(playerProvider.select((s) => s.playing));
    final streamQuality = ref.watch(
      playerProvider.select((s) => s.streamQualityLabel),
    );
    final carMode = ref.watch(playerProvider.select((s) => s.carMode));
    final speed = ref.watch(playerProvider.select((s) => s.speed));
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
        Stack(
          alignment: Alignment.center,
          children: [
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
                      child: Text(
                        formatClock(displayPosition),
                        style: clockStyle,
                      ),
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
            IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: streamQuality == null
                    ? const SizedBox.shrink(key: ValueKey('stream-quality'))
                    : _StreamQualityLabel(
                        key: ValueKey(streamQuality),
                        label: streamQuality,
                        style: clockStyle,
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
              tooltip: context.tr('Previous episode'),
              iconSize: sideIconSize,
              onPressed: player.playPreviousInQueue,
              icon: SkipIcon.previous(size: sideIconSize),
            ),
            IconButton(
              tooltip: context.tr('Rewind {seconds} s (J)', {
                'seconds': '${settings.skipBackSeconds}',
              }),
              onPressed: () => player.skipBy(-settings.skipBackSeconds),
              icon: SkipIcon.back(size: skipIconSize),
            ),
            if (!carMode)
              IconButton.filled(
                tooltip: context.tr(playing ? 'Pause (Space)' : 'Play (Space)'),
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
              tooltip: context.tr('Forward {seconds} s (L)', {
                'seconds': '${settings.skipForwardSeconds}',
              }),
              onPressed: () => player.skipBy(settings.skipForwardSeconds),
              icon: SkipIcon.forward(size: skipIconSize),
            ),
            IconButton(
              tooltip: context.tr(
                hasNext ? 'Next episode' : 'No next episode in the queue',
              ),
              iconSize: sideIconSize,
              onPressed: hasNext ? player.playNextInQueue : null,
              icon: SkipIcon.next(size: sideIconSize),
            ),
          ],
        ),
        if (!carMode) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: context.tr('Notes'),
                onPressed: episodeId == null
                    ? null
                    : () => showNotesSheet(
                        context: context,
                        episodeId: episodeId,
                      ),
                icon: const InfoIcon(),
              ),
              IconButton(
                tooltip: 'Effets audios',
                onPressed: () => showAudioEffectsSheet(context),
                icon: const TuneIcon(),
              ),
              const Spacer(),
              if (hasChapters)
                IconButton(
                  tooltip: context.tr('Chapters'),
                  onPressed: episodeId == null
                      ? null
                      : () => showChaptersSheet(
                          context: context,
                          ref: ref,
                          episodeId: episodeId,
                        ),
                  icon: const Icon(Icons.list_alt),
                ),
              const _QueueAction(),
            ],
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

/// Casque 13 px puis « 154 kbps · 48 kHz », plus pâle que les temps.
class _StreamQualityLabel extends StatelessWidget {
  const _StreamQualityLabel({
    super.key,
    required this.label,
    required this.style,
  });

  final String label;
  final TextStyle? style;

  static const _color = Color(0x73FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.headphones, size: 13, color: _color),
        const SizedBox(width: 4),
        Text(label, maxLines: 1, style: style?.copyWith(color: _color)),
      ],
    );
  }
}

class _QueueAction extends ConsumerWidget {
  const _QueueAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(playerPanelProvider) == PlayerPanel.playlist;
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: open ? context.tr('Back to the episode') : context.tr('Queue'),
      isSelected: open,
      style: IconButton.styleFrom(
        backgroundColor: open ? scheme.secondaryContainer : null,
      ),
      onPressed: () => ref.read(playerPanelProvider.notifier).toggle(),
      icon: const QueueMusicIcon(),
    );
  }
}

class PlayerFavoriteAction extends ConsumerWidget {
  const PlayerFavoriteAction({super.key, required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(episodeProvider(episodeId)).value;
    if (entry == null) return const SizedBox.shrink();
    final favorite = entry.episode.favorite;
    return IconButton(
      tooltip: context.tr(
        favorite ? 'Remove from favorites' : 'Add to favorites',
      ),
      onPressed: () =>
          runEpisodeAction(context, ref, entry, EpisodeMenuAction.favorite),
      icon: Icon(
        favorite ? Icons.favorite : Icons.favorite_outline,
        color: favorite ? favoriteHeartColor : null,
      ),
    );
  }
}

const _headerGlyphSize = 26.0;

ButtonStyle _headerActionStyle() {
  return IconButton.styleFrom(
    iconSize: _headerGlyphSize,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    minimumSize: const Size(48, 48),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

class PlayerCastAction extends ConsumerWidget {
  const PlayerCastAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castName = ref.watch(
      playerProvider.select((state) => state.castDeviceName),
    );
    return IconButton(
      tooltip: castName ?? context.tr('Audio output'),
      style: _headerActionStyle(),
      color: castName == null ? null : const Color(0xFF4FC3F7),
      onPressed: () => showAudioOutputSheet(context, ref),
      icon: const CastIcon(size: _headerGlyphSize),
    );
  }
}

class PlayerSpeedAction extends ConsumerWidget {
  const PlayerSpeedAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playerProvider.select((state) => state.speed));
    return IconButton(
      tooltip: context.tr('Speed'),
      style: _headerActionStyle().copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
      onPressed: () => choosePlaybackSpeed(context, ref),
      icon: Builder(
        builder: (context) => Text(
          formatPlaybackSpeed(speed),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            color: IconTheme.of(context).color,
            fontSize: _headerGlyphSize,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class PlayerSleepAction extends ConsumerWidget {
  const PlayerSleepAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleepAtEnd = ref.watch(
      playerProvider.select((state) => state.sleepAtEnd),
    );
    final sleepEndsAt = ref.watch(
      playerProvider.select((state) => state.sleepEndsAt),
    );
    final active = sleepAtEnd || sleepEndsAt != null;
    final remaining = sleepEndsAt?.difference(DateTime.now());
    final detail = sleepAtEnd
        ? 'Fin de l’épisode'
        : remaining == null
        ? null
        : formatClock(remaining.isNegative ? Duration.zero : remaining);
    final tooltip = detail == null
        ? context.tr('Sleep timer')
        : '${context.tr('Sleep timer')} · $detail';
    return IconButton(
      tooltip: tooltip,
      style: _headerActionStyle(),
      color: active ? Theme.of(context).colorScheme.primary : null,
      onPressed: () => chooseSleepTimer(context, ref),
      icon: const BedtimeIcon(size: _headerGlyphSize),
    );
  }
}

class PlayerEpisodeActions extends ConsumerWidget {
  const PlayerEpisodeActions({super.key, required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(episodeProvider(episodeId)).value;
    if (entry == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: context.tr('Actions'),
      style: _headerActionStyle(),
      onPressed: () =>
          showEpisodeActionsSheet(context, ref, entry, fromPlayer: true),
      icon: const MoreVertIcon(size: _headerGlyphSize),
    );
  }
}
