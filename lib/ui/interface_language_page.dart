import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/search.dart';
import '../l10n/interface_locale.dart';
import '../l10n/l10n.dart';
import '../settings/settings_controller.dart';

class InterfaceLanguagePage extends ConsumerStatefulWidget {
  const InterfaceLanguagePage({super.key});

  @override
  ConsumerState<InterfaceLanguagePage> createState() =>
      _InterfaceLanguagePageState();
}

class _InterfaceLanguagePageState extends ConsumerState<InterfaceLanguagePage> {
  final _searchController = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final chip = _chipLabel(groupValue, systemCode);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Language'))),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
          if (chip != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Chip(label: Text(chip)),
              ),
            ),
          Expanded(
            child: languages.isEmpty
                ? Center(child: Text(context.tr('No matching language')))
                : RadioGroup<String>(
                    groupValue: groupValue,
                    onChanged: (value) {
                      if (value == null) return;
                      ref
                          .read(settingsProvider.notifier)
                          .setInterfaceLanguage(value.isEmpty ? null : value);
                    },
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        for (final language in languages)
                          RadioListTile<String>(
                            value: systemCode == language.code
                                ? ''
                                : language.code,
                            controlAffinity: ListTileControlAffinity.trailing,
                            contentPadding: const EdgeInsetsDirectional.only(
                              start: 16,
                              end: 8,
                            ),
                            title: Text(language.endonym),
                            subtitle: Text(
                              systemCode == language.code
                                  ? '${language.code} - ${context.tr('System')}'
                                  : language.code,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _visible(InterfaceLanguage language, String? systemCode) {
    if (_query.trim().isEmpty) return true;
    final systemMark = systemCode == language.code
        ? '${language.code} - ${context.tr('System')}'
        : language.code;
    return searchMatch('${language.endonym} $systemMark', _query);
  }

  String? _chipLabel(String? groupValue, String? systemCode) {
    if (groupValue == null) return null;
    final code = groupValue.isEmpty ? systemCode : groupValue;
    if (code == null) return null;
    return interfaceLanguageEndonym(code);
  }
}
