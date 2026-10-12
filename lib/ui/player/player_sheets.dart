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

class _PlayerQueue extends ConsumerStatefulWidget {
  const _PlayerQueue();

  @override
  ConsumerState<_PlayerQueue> createState() => _PlayerQueueState();
}

class _PlayerQueueState extends ConsumerState<_PlayerQueue> {
  List<int>? _orderIds;

  List<EpisodeEntry> _ordered(List<EpisodeEntry> entries) {
    final ids = _orderIds;
    if (ids == null) return entries;
    final byId = {for (final entry in entries) entry.episode.id: entry};
    final ordered = <EpisodeEntry>[];
    for (final id in ids) {
      final entry = byId[id];
      if (entry != null) ordered.add(entry);
    }
    if (ordered.length != entries.length) return entries;
    return ordered;
  }

  void _commit(List<EpisodeEntry> next) {
    final ids = next.map((entry) => entry.episode.id).toList();
    setState(() => _orderIds = ids);
    ref.read(databaseProvider).setQueueOrder(ids);
  }

  void _move(List<EpisodeEntry> entries, int from, int delta) {
    final to = from + delta;
    if (from < 0 || to < 0 || to >= entries.length) return;
    final next = [...entries];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    _commit(next);
  }

  void _showActions({
    required EpisodeEntry entry,
    required int position,
    required int count,
    required List<EpisodeEntry> entries,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (position > 0)
                ListTile(
                  leading: const MoveUpIcon(),
                  title: const Text('Monter'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _move(entries, position, -1);
                  },
                ),
              if (position < count - 1)
                ListTile(
                  leading: const MoveDownIcon(),
                  title: const Text('Descendre'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _move(entries, position, 1);
                  },
                ),
              ListTile(
                leading: const DeleteIcon(),
                title: const Text('Supprimer'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _orderIds = _orderIds
                        ?.where((id) => id != entry.episode.id)
                        .toList();
                  });
                  ref.read(databaseProvider).removeFromQueue(entry.episode.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final window = ref.watch(
      episodesProvider(const EpisodeQuery(queuedOnly: true, paginated: false)),
    );
    final currentId = ref.watch(
      playerProvider.select((state) => state.episodeId),
    );
    final current = currentId == null
        ? null
        : ref.watch(episodeProvider(currentId)).value;
    final loaded = window.asData?.value.entries ?? const <EpisodeEntry>[];
    final entries = _ordered(loaded);
    final currentInQueue =
        currentId != null &&
        entries.any((entry) => entry.episode.id == currentId);
    final currentIndex = currentId == null
        ? -1
        : entries.indexWhere((entry) => entry.episode.id == currentId);
    final upcoming = currentIndex < 0
        ? entries
        : entries.sublist(currentIndex + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != null)
          _QueueNowPlaying(
            entry: current,
            canAdd: !currentInQueue && !window.isLoading,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(
            'À suivre',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          child: window.isLoading && entries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : upcoming.isEmpty
              ? EmptyState(
                  title: entries.isEmpty
                      ? 'La playlist est vide'
                      : 'Rien à suivre',
                  message: entries.isEmpty
                      ? 'Ajoutez des épisodes pour les écouter les uns à la suite des autres.'
                      : 'Les épisodes suivants apparaîtront ici.',
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  buildDefaultDragHandles: false,
                  itemCount: upcoming.length,
                  proxyDecorator: _queueDragProxy,
                  onReorderItem: (oldIndex, newIndex) {
                    final next = [...upcoming];
                    final moved = next.removeAt(oldIndex);
                    next.insert(newIndex, moved);
                    final head = currentIndex < 0
                        ? const <EpisodeEntry>[]
                        : entries.sublist(0, currentIndex + 1);
                    _commit([...head, ...next]);
                  },
                  itemBuilder: (context, index) {
                    final entry = upcoming[index];
                    final position = currentIndex < 0
                        ? index
                        : currentIndex + 1 + index;
                    return _QueueRow(
                      key: ValueKey(entry.episode.id),
                      entry: entry,
                      index: index,
                      onMore: () => _showActions(
                        entry: entry,
                        position: position,
                        count: entries.length,
                        entries: entries,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Widget _queueDragProxy(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      return Material(
        elevation: 8 * t,
        shadowColor: Colors.black45,
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(8),
        child: child,
      );
    },
    child: child,
  );
}

class _QueueNowPlaying extends ConsumerWidget {
  const _QueueNowPlaying({required this.entry, required this.canAdd});

  final EpisodeEntry entry;
  final bool canAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preferPodcastCover = ref.watch(
      settingsProvider.select((settings) => settings.preferPodcastCover),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          PodcastCover(
            url: entry.imageUrl(preferPodcastCover: preferPodcastCover),
            localPath: entry.imagePath(preferPodcastCover: preferPodcastCover),
            httpHeaders: podcastAuthHeaders(
              username: entry.podcast.authUsername,
              password: entry.podcast.authPassword,
            ),
            size: 55,
            radius: 4,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.episode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.podcast.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (canAdd)
            IconButton(
              tooltip: 'Ajouter l’épisode',
              onPressed: () =>
                  ref.read(databaseProvider).addToQueue(entry.episode.id),
              icon: const PlaylistAddIcon(),
            ),
          IconButton(
            tooltip: 'Fermer la playlist',
            onPressed: () => ref.read(_playerPanelProvider.notifier).close(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends ConsumerWidget {
  const _QueueRow({
    super.key,
    required this.entry,
    required this.index,
    required this.onMore,
  });

  final EpisodeEntry entry;
  final int index;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preferPodcastCover = ref.watch(
      settingsProvider.select((settings) => settings.preferPodcastCover),
    );
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          children: [
            Expanded(
              child: ReorderableDelayedDragStartListener(
                index: index,
                child: InkWell(
                  onTap: () =>
                      ref.read(playerProvider.notifier).playEntry(entry),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
                    child: Row(
                      children: [
                        PodcastCover(
                          url: entry.imageUrl(
                            preferPodcastCover: preferPodcastCover,
                          ),
                          localPath: entry.imagePath(
                            preferPodcastCover: preferPodcastCover,
                          ),
                          httpHeaders: podcastAuthHeaders(
                            username: entry.podcast.authUsername,
                            password: entry.podcast.authPassword,
                          ),
                          size: 48,
                          radius: 4,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.episode.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                entry.podcast.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actions',
              onPressed: onMore,
              icon: const MoreVertIcon(),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showNotesSheet({
  required BuildContext context,
  required int episodeId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return _NotesSheet(
            episodeId: episodeId,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _NotesSheet extends ConsumerWidget {
  const _NotesSheet({required this.episodeId, required this.scrollController});

  final int episodeId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes =
        ref.watch(episodeProvider(episodeId)).value?.episode.description ?? '';
    final hasNotes = plainText(notes).isNotEmpty;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Text('Notes', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (!hasNotes)
          Text(
            'Aucune note pour cet épisode.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          ShowNotes(html: notes, style: theme.textTheme.bodyMedium),
      ],
    );
  }
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
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
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
    final showLoading =
        chapters.isEmpty &&
        (loadAsync.isLoading ||
            (pendingFetch && phase != ChaptersLoadPhase.failed));
    final showError = chapters.isEmpty && phase == ChaptersLoadPhase.failed;

    if (chapters.isNotEmpty) {
      _scrollToActive(active, animate: _lastScrolledChapterId != null);
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
