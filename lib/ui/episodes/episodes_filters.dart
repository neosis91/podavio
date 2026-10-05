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
          label: const Text('Non lus'),
          onPressed: onEdit,
          onDeleted: () => onChanged(filters.copyWith(unreadOnly: false)),
        ),
      if (filters.downloadsOnly)
        InputChip(
          label: const Text('Téléchargés'),
          onPressed: onEdit,
          onDeleted: () => onChanged(filters.copyWith(downloadsOnly: false)),
        ),
      if (filters.inProgressOnly)
        InputChip(
          label: const Text('En cours'),
          onPressed: onEdit,
          onDeleted: () => onChanged(filters.copyWith(inProgressOnly: false)),
        ),
      ActionChip(
        avatar: Icon(Icons.clear_all, size: 18, color: scheme.primary),
        label: const Text('Tout effacer'),
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
            title: const Text('Filtrer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Non lus'),
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
                    title: const Text('Téléchargés'),
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
                    title: const Text('En cours'),
                    subtitle: const Text('Commencés et non terminés'),
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
                child: const Text('Effacer'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, draft),
                child: const Text('Appliquer'),
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
