part of '../player_page.dart';

Future<void> showChaptersSheet({
  required BuildContext context,
  required WidgetRef ref,
  required int episodeId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ChaptersSheet(episodeId: episodeId),
  );
}

Future<void> _chooseSpeed(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _SpeedSheet(),
  );
}

class _SpeedSheet extends ConsumerWidget {
  const _SpeedSheet();

  static const _presets = [0.8, 1.0, 1.2, 1.5, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playerProvider.select((state) => state.speed));
    final episodeId = ref.watch(
      playerProvider.select((state) => state.episodeId),
    );
    final hasOverride = episodeId == null
        ? false
        : ref
                  .watch(episodeProvider(episodeId))
                  .asData
                  ?.value
                  ?.podcast
                  .playbackSpeed !=
              null;
    final theme = Theme.of(context);
    final sliderValue = speed.clamp(0.5, 3.0);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Vitesse', style: theme.textTheme.titleMedium),
            if (hasOverride) ...[
              const SizedBox(height: 4),
              Text(
                'Pour ce podcast',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: sliderValue,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    label: _formatSpeed(sliderValue),
                    onChanged: (value) {
                      unawaited(
                        ref.read(playerProvider.notifier).setSpeed(value),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _formatSpeed(sliderValue),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ChoiceChip(
                    label: Text(_formatSpeed(preset)),
                    selected: (speed - preset).abs() < 0.05,
                    onSelected: (_) {
                      unawaited(
                        ref.read(playerProvider.notifier).setSpeed(preset),
                      );
                    },
                  ),
              ],
            ),
            if (hasOverride) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    unawaited(
                      ref.read(playerProvider.notifier).resetPodcastSpeed(),
                    );
                  },
                  child: const Text('Réinitialiser'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _chooseVolume(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _VolumeSheet(),
  );
}

class _VolumeSheet extends ConsumerWidget {
  const _VolumeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerProvider.select((state) => state.volume));
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Volume', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_volumeIcon(volume)),
                Expanded(
                  child: Slider(
                    value: volume,
                    onChanged: (value) {
                      unawaited(
                        ref.read(playerProvider.notifier).setVolume(value),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _formatVolume(volume),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

class _ChaptersSheet extends ConsumerStatefulWidget {
  const _ChaptersSheet({required this.episodeId});

  final int episodeId;

  @override
  ConsumerState<_ChaptersSheet> createState() => _ChaptersSheetState();
}

class _ChaptersSheetState extends ConsumerState<_ChaptersSheet> {
  final _itemKeys = <int, GlobalKey>{};
  int? _lastScrolledChapterId;
  int? _pendingScrollId;

  GlobalKey _keyFor(int chapterId) =>
      _itemKeys.putIfAbsent(chapterId, GlobalKey.new);

  void _scrollToActive(EpisodeChapter? active, {required bool animate}) {
    if (active == null) return;
    if (_lastScrolledChapterId == active.id) return;
    if (_pendingScrollId == active.id) return;
    _pendingScrollId = active.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScrollId = null;
      if (!mounted) return;
      final ctx = _itemKeys[active.id]?.currentContext;
      if (ctx == null) return;
      _lastScrolledChapterId = active.id;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: animate
            ? const Duration(milliseconds: 250)
            : Duration.zero,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final episodeId = widget.episodeId;
    final chapters =
        ref.watch(chaptersProvider(episodeId)).value ??
        const <EpisodeChapter>[];
    final loadAsync = ref.watch(chaptersLoadStateProvider(episodeId));
    final episode = ref.watch(episodeProvider(episodeId)).value?.episode;
    final chaptersUrl = episode?.chaptersUrl?.trim() ?? '';
    final fetched = episode?.chaptersFetched ?? false;
    final position = ref.watch(playerProvider.select((s) => s.position));
    final active = currentChapterFor(chapters, position);
    final height = MediaQuery.sizeOf(context).height * 0.55;

    final phase = loadAsync.asData?.value;
    final pendingFetch = chaptersUrl.isNotEmpty && !fetched;
    final showLoading = chapters.isEmpty &&
        (loadAsync.isLoading ||
            (pendingFetch && phase != ChaptersLoadPhase.failed));
    final showError = chapters.isEmpty && phase == ChaptersLoadPhase.failed;

    if (chapters.isNotEmpty) {
      _scrollToActive(
        active,
        animate: _lastScrolledChapterId != null,
      );
    }

    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final Widget body;
    if (showLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (showError) {
      body = Center(
        child: Text(
          'Impossible de charger les chapitres.',
          style: muted,
          textAlign: TextAlign.center,
        ),
      );
    } else if (chapters.isEmpty) {
      body = Center(
        child: Text(
          'Aucun chapitre pour cet épisode.',
          style: muted,
          textAlign: TextAlign.center,
        ),
      );
    } else {
      body = ListView(
        children: [
          for (var index = 0; index < chapters.length; index++)
            _chapterTile(
              theme: theme,
              chapter: chapters[index],
              index: index,
              selected: chapters[index].id == active?.id,
            ),
        ],
      );
    }

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Chapitres', style: theme.textTheme.titleMedium),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _chapterTile({
    required ThemeData theme,
    required EpisodeChapter chapter,
    required int index,
    required bool selected,
  }) {
    final start = Duration(milliseconds: chapter.startMs);
    return ListTile(
      key: _keyFor(chapter.id),
      selected: selected,
      leading: Text(
        formatClock(start),
        style: theme.textTheme.labelLarge?.copyWith(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      title: Text(
        chapter.title.isEmpty ? 'Chapitre ${index + 1}' : chapter.title,
      ),
      onTap: () {
        Navigator.pop(context);
        ref.read(playerProvider.notifier).seek(start);
      },
    );
  }
}
