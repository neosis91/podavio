import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_categories.dart';
import '../data/discover_providers.dart';
import '../l10n/l10n.dart';
import 'widgets/app_bottom_sheet.dart';
import 'widgets/selection_chip.dart';

Future<void> showCategorySubjectsSheet(
  BuildContext context,
  WidgetRef ref,
  String categoryId,
) {
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _CategorySubjectsSheet(categoryId: categoryId),
  );
}

/// Pastilles des sujets gardés pour cette catégorie. Un appui retire le
/// sujet. S’il n’en reste qu’un, l’appui ouvre la feuille pour en ajouter.
class CategorySubjectChips extends ConsumerWidget {
  const CategorySubjectChips({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(categorySubjectsProvider);
    final members = enabledSubjects(categoryId, stored[categoryId]);
    if (members.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final member = members[index];
          return SelectionChip(
            label: context.tr(member.genre),
            selected: true,
            onSelected: () {
              if (members.length < 2) {
                showCategorySubjectsSheet(context, ref, categoryId);
                return;
              }
              ref.read(categorySubjectsProvider.notifier).setEnabled(
                categoryId,
                {
                  for (final item in members)
                    if (item.genre != member.genre) item.genre,
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CategorySubjectsSheet extends ConsumerWidget {
  const _CategorySubjectsSheet({required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(categorySubjectsProvider);
    final enabled = enabledSubjects(
      categoryId,
      stored[categoryId],
    ).map((member) => member.genre).toSet();
    final theme = Theme.of(context);
    final title = context.tr(homeCategoryTitle(categoryId));
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                context.tr('Choose the subjects in this category'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final category in catalogCategories) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Text(
                        context.tr(category.title),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    for (final member in category.regroupMembers)
                      CheckboxListTile(
                        value: enabled.contains(member.genre),
                        title: Text(context.tr(member.genre)),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          final next = {...enabled};
                          if (value ?? false) {
                            next.add(member.genre);
                          } else {
                            next.remove(member.genre);
                          }
                          ref
                              .read(categorySubjectsProvider.notifier)
                              .setEnabled(categoryId, next);
                        },
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
