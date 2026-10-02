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

class _ChaptersSheet extends ConsumerWidget {
  const _ChaptersSheet({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chaptersAsync = ref.watch(chaptersProvider(episodeId));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final chapters = chaptersAsync.value ?? const <EpisodeChapter>[];
    final active = currentChapterFor(chapters, position);
    final height = MediaQuery.sizeOf(context).height * 0.55;

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
            Expanded(
              child: chaptersAsync.isLoading && chapters.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : chapters.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun chapitre pour cet épisode.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        final selected = identical(chapter, active) ||
                            chapter.id == active?.id;
                        final start = Duration(milliseconds: chapter.startMs);
                        return ListTile(
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
                            chapter.title.isEmpty
                                ? 'Chapitre ${index + 1}'
                                : chapter.title,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            ref
                                .read(playerProvider.notifier)
                                .seek(start);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
