part of '../episodes_page.dart';

class _ActiveEpisodeFiltersBar extends StatelessWidget {
  const _ActiveEpisodeFiltersBar({
    required this.filters,
    required this.onEdit,
    required this.onChanged,
  });

  final EpisodeFilters filters;
  final VoidCallback onEdit;
  final ValueChanged<EpisodeFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = <Widget>[
      if (filters.unreadOnly)
        InputChip(
          label: Text(context.tr('Unplayed')),
          onPressed: onEdit,
          onDeleted: () => onChanged(filters.copyWith(unreadOnly: false)),
        ),
      if (filters.downloadsOnly)
        InputChip(
          label: Text(context.tr('Downloaded')),
          onPressed: onEdit,
          onDeleted: () => onChanged(filters.copyWith(downloadsOnly: false)),
        ),
      if (filters.inProgressOnly)
        InputChip(
          label: Text(context.tr('In progress')),
          onPressed: onEdit,
          onDeleted: () => onChanged(filters.copyWith(inProgressOnly: false)),
        ),
      ActionChip(
        avatar: Icon(Icons.clear_all, size: 18, color: scheme.primary),
        label: Text(context.tr('Clear all')),
        onPressed: () => onChanged(EpisodeFilters.empty),
      ),
    ];

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => chips[index],
        ),
      ),
    );
  }
}

Future<void> _showEpisodeFilterDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  var draft = ref.read(settingsProvider).episodeFilters;
  final applied = await showDialog<EpisodeFilters>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(context.tr('Filter')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Unplayed')),
                    value: draft.unreadOnly,
                    onChanged: (value) {
                      setState(() {
                        draft = draft.copyWith(unreadOnly: value ?? false);
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Downloaded')),
                    value: draft.downloadsOnly,
                    onChanged: (value) {
                      setState(() {
                        draft = draft.copyWith(downloadsOnly: value ?? false);
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('In progress')),
                    subtitle: Text(context.tr('Started and not finished')),
                    value: draft.inProgressOnly,
                    onChanged: (value) {
                      setState(() {
                        draft = draft.copyWith(inProgressOnly: value ?? false);
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, EpisodeFilters.empty),
                child: Text(context.tr('Clear')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, draft),
                child: Text(context.tr('Apply')),
              ),
            ],
          );
        },
      );
    },
  );
  if (applied == null) return;
  await ref.read(settingsProvider.notifier).setEpisodeFilters(applied);
}
