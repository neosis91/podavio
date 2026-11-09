import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';
import '../../player/player_controller.dart';
import '../widgets/app_bottom_sheet.dart';
import 'player_chapter.dart';

Future<void> showChaptersSheet({
  required BuildContext context,
  required WidgetRef ref,
  required int episodeId,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ChaptersSheet(episodeId: episodeId),
  );
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
