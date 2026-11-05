import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/providers.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/show_notes.dart';

Future<void> showNotesSheet({
  required BuildContext context,
  required int episodeId,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 1,
        minChildSize: 0.35,
        maxChildSize: 1,
        builder: (context, scrollController) {
          return Material(
            color:
                theme.bottomSheetTheme.backgroundColor ??
                scheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top + 12),
                const SheetDragHandle(),
                Expanded(
                  child: _NotesSheet(
                    episodeId: episodeId,
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
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
    final notesAsync = ref.watch(episodeProvider(episodeId));
    final notes = notesAsync.asData?.value?.episode.description ?? '';
    final hasNotes = plainText(notes).isNotEmpty;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text('Notes', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (notesAsync.isLoading && !notesAsync.hasValue)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!hasNotes)
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
