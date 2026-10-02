part of '../podcasts_page.dart';

class _ActiveFiltersBar extends StatelessWidget {
  const _ActiveFiltersBar({
    required this.filters,
    required this.onEdit,
    required this.onChanged,
  });

  final PodcastFilters filters;
  final VoidCallback onEdit;
  final ValueChanged<PodcastFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = <Widget>[
      if (filters.counterAboveZero)
        InputChip(
          label: const Text('Compteur > 0'),
          onPressed: onEdit,
          onDeleted: () =>
              onChanged(filters.copyWith(counterAboveZero: false)),
        ),
      if (filters.autoDownload == true)
        InputChip(
          label: const Text('Téléchargements auto'),
          onPressed: onEdit,
          onDeleted: () =>
              onChanged(filters.copyWith(clearAutoDownload: true)),
        ),
      if (filters.autoDownload == false)
        InputChip(
          label: const Text('Sans téléchargements auto'),
          onPressed: onEdit,
          onDeleted: () =>
              onChanged(filters.copyWith(clearAutoDownload: true)),
        ),
      if (filters.keepUpdated == true)
        InputChip(
          label: const Text('Maintenu à jour'),
          onPressed: onEdit,
          onDeleted: () =>
              onChanged(filters.copyWith(clearKeepUpdated: true)),
        ),
      if (filters.keepUpdated == false)
        InputChip(
          label: const Text('Non maintenu à jour'),
          onPressed: onEdit,
          onDeleted: () =>
              onChanged(filters.copyWith(clearKeepUpdated: true)),
        ),
      ActionChip(
        avatar: Icon(Icons.clear_all, size: 18, color: scheme.primary),
        label: const Text('Tout effacer'),
        onPressed: () => onChanged(PodcastFilters.empty),
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

List<Podcast> _filterPodcasts(
  List<Podcast> items, {
  required PodcastFilters filters,
  required Map<int, int> counterCounts,
}) {
  if (filters.isEmpty) return items;
  return items.where((podcast) {
    if (filters.counterAboveZero && (counterCounts[podcast.id] ?? 0) <= 0) {
      return false;
    }
    if (filters.autoDownload != null &&
        podcast.autoDownload != filters.autoDownload) {
      return false;
    }
    if (filters.keepUpdated != null &&
        podcast.keepUpdated != filters.keepUpdated) {
      return false;
    }
    return true;
  }).toList();
}

List<Podcast> _sortPodcasts(
  List<Podcast> items, {
  required PodcastSort sort,
  required Map<int, int> counterCounts,
  required Map<int, int> playedCounts,
}) {
  final sorted = List<Podcast>.of(items);
  int byTitle(Podcast a, Podcast b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  switch (sort) {
    case PodcastSort.published:
      // Déjà trié par date du dernier épisode via watchPodcasts().
      return sorted;
    case PodcastSort.alphabetical:
      sorted.sort(byTitle);
    case PodcastSort.counter:
      sorted.sort((a, b) {
        final cmp = (counterCounts[b.id] ?? 0).compareTo(
          counterCounts[a.id] ?? 0,
        );
        return cmp != 0 ? cmp : byTitle(a, b);
      });
    case PodcastSort.played:
      sorted.sort((a, b) {
        final cmp = (playedCounts[b.id] ?? 0).compareTo(
          playedCounts[a.id] ?? 0,
        );
        return cmp != 0 ? cmp : byTitle(a, b);
      });
  }
  return sorted;
}

Future<void> _showCounterDialog(BuildContext context, WidgetRef ref) async {
  final selected = ref.read(settingsProvider).podcastCounter;
  final choice = await showDialog<PodcastCounter>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Compteur'),
      children: [
        for (final mode in PodcastCounter.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, mode),
            child: Row(
              children: [
                Expanded(child: Text(mode.label)),
                if (mode == selected) const Icon(Icons.check, size: 20),
              ],
            ),
          ),
      ],
    ),
  );
  if (choice == null) return;
  await ref.read(settingsProvider.notifier).setPodcastCounter(choice);
}

Future<void> _showFilterDialog(BuildContext context, WidgetRef ref) async {
  var draft = ref.read(settingsProvider).podcastFilters;
  final applied = await showDialog<PodcastFilters>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          void toggleCounter(bool? value) {
            setState(() {
              draft = draft.copyWith(counterAboveZero: value ?? false);
            });
          }

          void toggleAutoDownload(bool wantWith) {
            setState(() {
              if (draft.autoDownload == wantWith) {
                draft = draft.copyWith(clearAutoDownload: true);
              } else {
                draft = draft.copyWith(autoDownload: wantWith);
              }
            });
          }

          void toggleKeepUpdated(bool wantKept) {
            setState(() {
              if (draft.keepUpdated == wantKept) {
                draft = draft.copyWith(clearKeepUpdated: true);
              } else {
                draft = draft.copyWith(keepUpdated: wantKept);
              }
            });
          }

          return AlertDialog(
            title: const Text('Filtrer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compteur supérieur à zéro'),
                    value: draft.counterAboveZero,
                    onChanged: toggleCounter,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Avec téléchargements automatiques'),
                    value: draft.autoDownload == true,
                    onChanged: (_) => toggleAutoDownload(true),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sans téléchargements automatiques'),
                    value: draft.autoDownload == false,
                    onChanged: (_) => toggleAutoDownload(false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Maintenu à jour'),
                    value: draft.keepUpdated == true,
                    onChanged: (_) => toggleKeepUpdated(true),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Non maintenu à jour'),
                    value: draft.keepUpdated == false,
                    onChanged: (_) => toggleKeepUpdated(false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, PodcastFilters.empty),
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
  await ref.read(settingsProvider.notifier).setPodcastFilters(applied);
}

Future<void> _showSortDialog(BuildContext context, WidgetRef ref) async {
  final selected = ref.read(settingsProvider).podcastSort;
  final choice = await showDialog<PodcastSort>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Trier'),
      children: [
        for (final mode in PodcastSort.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, mode),
            child: Row(
              children: [
                Expanded(child: Text(mode.label)),
                if (mode == selected) const Icon(Icons.check, size: 20),
              ],
            ),
          ),
      ],
    ),
  );
  if (choice == null) return;
  await ref.read(settingsProvider.notifier).setPodcastSort(choice);
}

