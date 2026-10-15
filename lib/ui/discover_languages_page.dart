import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/search.dart';
import '../data/discover_languages.dart';
import '../l10n/l10n.dart';
import '../settings/settings_controller.dart';
import 'widgets/highlighted_text.dart';
import 'widgets/messages.dart';

class DiscoverLanguagesPage extends ConsumerStatefulWidget {
  const DiscoverLanguagesPage({super.key});

  @override
  ConsumerState<DiscoverLanguagesPage> createState() =>
      _DiscoverLanguagesPageState();
}

class _DiscoverLanguagesPageState extends ConsumerState<DiscoverLanguagesPage> {
  final _searchController = TextEditingController();
  final _open = <String>{};
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(
      settingsProvider.select((settings) => settings.discoverLanguages),
    );
    final all = discoverLanguagesAreAll(selected);
    final theme = Theme.of(context);
    final groups = _shownGroups();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Languages'))),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            value: all,
            title: Text(context.tr('All languages')),
            onChanged: (checked) {
              ref
                  .read(settingsProvider.notifier)
                  .setDiscoverAllLanguages(checked);
            },
          ),
          if (!all && appleStoresExceedLimit(selected))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.tr(
                  'Apple opens at most 8 stores. Further languages do not change those results.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (!all) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.tr('Search for a language'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.tr('Clear'),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            if (selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final code in selected)
                      InputChip(
                        label: Text(discoverLanguageLabel(code)),
                        onDeleted: () => _toggle(selected, code, false),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: groups.isEmpty
                  ? Center(child: Text(context.tr('No matching language')))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final shown = groups[index];
                        return _LanguageGroupTile(
                          shown: shown,
                          selected: selected,
                          query: _query,
                          open: shown.forceOpen || _open.contains(shown.code),
                          onToggle: (code, checked) =>
                              _toggle(selected, code, checked),
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
            ),
          ],
        ],
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
