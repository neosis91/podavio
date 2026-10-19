import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../settings/settings_controller.dart';
import '../widgets/selection_chip.dart';

/// Rangée de filtres, mêmes pastilles que l’accueil.
class PodcastFilterChips extends StatelessWidget
    implements PreferredSizeWidget {
  const PodcastFilterChips({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  final PodcastFilters filters;
  final ValueChanged<PodcastFilters> onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final chips = <(String, bool, PodcastFilters)>[
      (
        'Compteur > 0',
        filters.counterAboveZero,
        filters.copyWith(counterAboveZero: !filters.counterAboveZero),
      ),
      (
        'Téléchargements auto',
        filters.autoDownload == true,
        filters.autoDownload == true
            ? filters.copyWith(clearAutoDownload: true)
            : filters.copyWith(autoDownload: true),
      ),
      (
        'Sans téléchargements auto',
        filters.autoDownload == false,
        filters.autoDownload == false
            ? filters.copyWith(clearAutoDownload: true)
            : filters.copyWith(autoDownload: false),
      ),
      (
        'Maintenu à jour',
        filters.keepUpdated == true,
        filters.keepUpdated == true
            ? filters.copyWith(clearKeepUpdated: true)
            : filters.copyWith(keepUpdated: true),
      ),
      (
        'Non maintenu à jour',
        filters.keepUpdated == false,
        filters.keepUpdated == false
            ? filters.copyWith(clearKeepUpdated: true)
            : filters.copyWith(keepUpdated: false),
      ),
    ];

    return SizedBox(
      height: preferredSize.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final (label, selected, next) = chips[index];
          return SelectionChip(
            label: label,
            selected: selected,
            onSelected: () => onChanged(next),
          );
        },
      ),
    );
  }
}

List<Podcast> filterPodcasts(
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

List<Podcast> sortPodcasts(
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

Future<void> showPodcastCounterDialog(
  BuildContext context,
  WidgetRef ref,
) async {
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

Future<void> showPodcastFilterDialog(
  BuildContext context,
  WidgetRef ref,
) async {
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

Future<void> showPodcastSortDialog(BuildContext context, WidgetRef ref) async {
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
