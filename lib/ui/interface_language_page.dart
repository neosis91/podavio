import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/search.dart';
import '../l10n/interface_locale.dart';
import '../l10n/l10n.dart';
import '../settings/settings_controller.dart';
import 'widgets/frosted_header.dart';
import 'widgets/highlighted_text.dart';
import 'widgets/language_flag.dart';
import 'widgets/selection_chip.dart';

class InterfaceLanguagePage extends ConsumerStatefulWidget {
  const InterfaceLanguagePage({super.key});

  @override
  ConsumerState<InterfaceLanguagePage> createState() =>
      _InterfaceLanguagePageState();
}

class _InterfaceLanguagePageState extends ConsumerState<InterfaceLanguagePage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
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
    final stored = ref.watch(
      settingsProvider.select((settings) => settings.interfaceLanguage),
    );
    final systemCode = normalizeInterfaceLanguage(
      View.of(context).platformDispatcher.locale.languageCode,
    );
    final groupValue = stored == null || stored == systemCode
        ? (systemCode == null ? null : '')
        : stored;
    final languages = [
      for (final language in supportedInterfaceLanguages)
        if (_visible(language, systemCode)) language,
    ];
    final selectedCode = _selectedCode(groupValue, systemCode);
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
            : Text(context.tr('Language')),
        leading: _searching
            ? IconButton(
                tooltip: 'Fermer la recherche',
                onPressed: _closeSearch,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          if (_searching)
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
          else
            IconButton(
              tooltip: context.tr('Search for a language'),
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            ),
        ],
        bottom: selectedCode == null
            ? null
            : _SelectedInterfaceChip(code: selectedCode),
      ),
      body: RadioGroup<String>(
        groupValue: groupValue,
        onChanged: (value) {
          if (value == null) return;
          _select(value);
        },
        child: ListView(
          padding: selectedCode == null
              ? inset
              : inset.copyWith(
                  top: inset.top + _SelectedInterfaceChip.barHeight,
                ),
          children: [
            if (languages.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(context.tr('No matching language'))),
              )
            else
              for (final language in languages)
                _InterfaceLanguageRow(
                  language: language,
                  systemCode: systemCode,
                  query: _query,
                  value: _tileValue(language, systemCode),
                  onSelect: () => _select(_tileValue(language, systemCode)),
                ),
          ],
        ),
      ),
    );
  }

  bool _visible(InterfaceLanguage language, String? systemCode) {
    if (_query.trim().isEmpty) return true;
    return searchMatch(
      '${language.endonym} ${_subtitleFor(context, language, systemCode)}',
      _query,
    );
  }

  void _select(String value) {
    ref
        .read(settingsProvider.notifier)
        .setInterfaceLanguage(value.isEmpty ? null : value);
  }
}

String _tileValue(InterfaceLanguage language, String? systemCode) {
  return systemCode == language.code ? '' : language.code;
}

String _subtitleFor(
  BuildContext context,
  InterfaceLanguage language,
  String? systemCode,
) {
  return systemCode == language.code
      ? '${language.code} - ${context.tr('System')}'
      : language.code;
}

String? _selectedCode(String? groupValue, String? systemCode) {
  if (groupValue == null) return null;
  return groupValue.isEmpty ? systemCode : groupValue;
}

/// L’indonésien d’interface est `id` ; le catalogue Explorer le note `in`.
String interfaceFlagCode(String code) => code == 'id' ? 'in' : code;

class _InterfaceLanguageRow extends StatelessWidget {
  const _InterfaceLanguageRow({
    required this.language,
    required this.systemCode,
    required this.query,
    required this.value,
    required this.onSelect,
  });

  final InterfaceLanguage language;
  final String? systemCode;
  final String query;
  final String value;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitleFor(context, language, systemCode);
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      leading: LanguageFlag(languageCode: interfaceFlagCode(language.code)),
      title: HighlightedText(text: language.endonym, query: query, maxLines: 1),
      subtitle: HighlightedText(text: subtitle, query: query, maxLines: 1),
      onTap: onSelect,
      trailing: Radio<String>(value: value),
    );
  }
}

class _SelectedInterfaceChip extends StatelessWidget
    implements PreferredSizeWidget {
  const _SelectedInterfaceChip({required this.code});

  final String code;

  static const barHeight = 48.0;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context) {
    final flagCode = interfaceFlagCode(code);
    final hasFlag =
        languageFlagAsset(flagCode) != null ||
        languageFlagIso(flagCode) != null;
    return SizedBox(
      height: preferredSize.height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: [
          SelectionChip(
            label: interfaceLanguageEndonym(code),
            selected: true,
            avatar: hasFlag
                ? LanguageFlag(
                    languageCode: flagCode,
                    size: 18,
                    placeholder: false,
                  )
                : null,
            onSelected: () {},
          ),
        ],
      ),
    );
  }
}
