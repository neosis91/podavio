import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/search.dart';
import '../data/discover_languages.dart';
import '../l10n/l10n.dart';
import '../settings/settings_controller.dart';
import 'widgets/frosted_header.dart';
import 'widgets/highlighted_text.dart';
import 'widgets/language_flag.dart';
import 'widgets/messages.dart';
import 'widgets/selection_chip.dart';

class DiscoverLanguagesPage extends ConsumerStatefulWidget {
  const DiscoverLanguagesPage({super.key});

  @override
  ConsumerState<DiscoverLanguagesPage> createState() =>
      _DiscoverLanguagesPageState();
}

class _DiscoverLanguagesPageState extends ConsumerState<DiscoverLanguagesPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _open = <String>{};
  var _searching = false;
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(
      settingsProvider.select((settings) => settings.discoverLanguages),
    );
    final all = discoverLanguagesAreAll(selected);
    final groups = _shownGroups();
    final warn = !all && appleStoresExceedLimit(selected);
    final chips = !all && selected.isNotEmpty;
    final inset = belowFrostedBar(context, const EdgeInsets.only(bottom: 32));

    return FrostedScaffold(
      appBar: FrostedAppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.tr('Search for a language'),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
              )
            : Text(context.tr('Languages')),
        leading: _searching
            ? IconButton(
                tooltip: 'Fermer la recherche',
                onPressed: _closeSearch,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          if (!all && _searching)
            IconButton(
              tooltip: context.tr('Clear'),
              onPressed: _query.isEmpty
                  ? _closeSearch
                  : () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
              icon: const Icon(Icons.close),
            )
          else if (!all)
            IconButton(
              tooltip: context.tr('Search for a language'),
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            ),
        ],
        bottom: all || selected.isEmpty
            ? null
            : _SelectedLanguageChips(
                codes: selected,
                onRemove: (code) => _toggle(selected, code, false),
              ),
      ),
      body: ListView.builder(
        padding: chips
            ? inset.copyWith(top: inset.top + _SelectedLanguageChips.barHeight)
            : inset,
        itemCount: all
            ? 1
            : 1 + (warn ? 1 : 0) + (groups.isEmpty ? 1 : groups.length),
        itemBuilder: (context, index) {
          if (index == 0) {
            return SwitchListTile(
              value: all,
              title: Text(context.tr('All languages')),
              onChanged: (checked) {
                if (checked) _closeSearch();
                ref
                    .read(settingsProvider.notifier)
                    .setDiscoverAllLanguages(checked);
              },
            );
          }
          var cursor = 1;
          if (warn) {
            if (index == cursor) return const _AppleLimitNote();
            cursor++;
          }
          if (groups.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(context.tr('No matching language'))),
            );
          }
          final shown = groups[index - cursor];
          return _LanguageGroupTile(
            shown: shown,
            selected: selected,
            query: _query,
            open: shown.forceOpen || _open.contains(shown.code),
            onToggle: (code, checked) => _toggle(selected, code, checked),
            onExpand: shown.variants.isEmpty || shown.forceOpen
                ? null
                : () => setState(() {
                    if (_open.contains(shown.code)) {
                      _open.remove(shown.code);
                    } else {
                      _open.add(shown.code);
                    }
                  }),
          );
        },
      ),
    );
  }

  List<_ShownGroup> _shownGroups() {
    final filtering = _query.trim().isNotEmpty;
    final shown = <_ShownGroup>[];
    for (final group in discoverLanguageGroups) {
      if (!filtering) {
        shown.add(
          _ShownGroup(group: group, variants: group.variants, forceOpen: false),
        );
        continue;
      }
      final parentMatches = searchMatch(
        '${group.language.label} ${group.language.code}',
        _query,
      );
      final variants = [
        for (final variant in group.variants)
          if (searchMatch('${variant.label} ${variant.code}', _query)) variant,
      ];
      if (!parentMatches && variants.isEmpty) continue;
      shown.add(
        _ShownGroup(
          group: group,
          variants: variants,
          forceOpen: variants.isNotEmpty,
        ),
      );
    }
    return shown;
  }

  void _toggle(List<String> selected, String code, bool? checked) {
    final next = [...selected];
    if (checked ?? false) {
      if (!next.contains(code)) next.add(code);
      next.removeWhere((other) => other != code && other.startsWith('$code-'));
    } else {
      if (next.length <= 1) {
        showMessage(
          context,
          context.tr('Keep at least one language, or turn on All languages.'),
        );
        return;
      }
      next.remove(code);
    }
    ref.read(settingsProvider.notifier).setDiscoverLanguages(next);
  }
}

class _AppleLimitNote extends StatelessWidget {
  const _AppleLimitNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        context.tr(
          'Apple opens at most 8 stores. Further languages do not change those results.',
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SelectedLanguageChips extends StatelessWidget
    implements PreferredSizeWidget {
  const _SelectedLanguageChips({required this.codes, required this.onRemove});

  final List<String> codes;
  final ValueChanged<String> onRemove;

  static const barHeight = 48.0;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        itemCount: codes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final code = codes[index];
          final hasFlag =
              languageFlagAsset(code) != null || languageFlagIso(code) != null;
          return SelectionChip(
            label: discoverLanguageLabel(code),
            selected: true,
            avatar: hasFlag
                ? LanguageFlag(languageCode: code, size: 18, placeholder: false)
                : null,
            onSelected: () => onRemove(code),
          );
        },
      ),
    );
  }
}

class _ShownGroup {
  const _ShownGroup({
    required this.group,
    required this.variants,
    required this.forceOpen,
  });

  final DiscoverLanguageGroup group;
  final List<DiscoverLanguage> variants;
  final bool forceOpen;

  String get code => group.language.code;
}

class _LanguageGroupTile extends StatelessWidget {
  const _LanguageGroupTile({
    required this.shown,
    required this.selected,
    required this.query,
    required this.open,
    required this.onToggle,
    required this.onExpand,
  });

  final _ShownGroup shown;
  final List<String> selected;
  final String query;
  final bool open;
  final void Function(String code, bool? checked) onToggle;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final language = shown.group.language;
    final baseChecked = selected.contains(language.code);
    return Column(
      children: [
        _LanguageCheckRow(
          label: language.label,
          code: language.code,
          query: query,
          checked: baseChecked,
          open: open,
          onChanged: (checked) => onToggle(language.code, checked),
          onExpand: onExpand,
        ),
        if (open)
          for (final variant in shown.variants)
            _LanguageCheckRow(
              label: variant.label,
              code: variant.code,
              query: query,
              checked: baseChecked || selected.contains(variant.code),
              indent: true,
              onChanged: baseChecked
                  ? null
                  : (checked) => onToggle(variant.code, checked),
            ),
      ],
    );
  }
}

class _LanguageCheckRow extends StatelessWidget {
  const _LanguageCheckRow({
    required this.label,
    required this.code,
    required this.query,
    required this.checked,
    required this.onChanged,
    this.open = false,
    this.indent = false,
    this.onExpand,
  });

  final String label;
  final String code;
  final String query;
  final bool checked;
  final bool open;
  final bool indent;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: indent ? 32 : 16,
        end: 8,
      ),
      leading: LanguageFlag(languageCode: code),
      title: HighlightedText(text: label, query: query, maxLines: 1),
      subtitle: HighlightedText(text: code, query: query, maxLines: 1),
      onTap: onChanged == null ? null : () => onChanged!(!checked),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onExpand != null)
            IconButton(
              tooltip: open
                  ? context.tr('Hide variants')
                  : context.tr('Show variants'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              onPressed: onExpand,
              icon: Icon(open ? Icons.expand_less : Icons.expand_more),
            ),
          Checkbox(value: checked, onChanged: onChanged),
        ],
      ),
    );
  }
}
