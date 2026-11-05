import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/discover_languages.dart';
import '../../l10n/interface_locale.dart';
import '../../l10n/l10n.dart';
import '../../settings/settings_controller.dart';
import '../interface_language_page.dart';
import '../router.dart';
import '../widgets/language_flag.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final languages = settings.discoverLanguages;
    final interfaceLocale = resolveInterfaceLocale(
      stored: settings.interfaceLanguage,
      system: View.of(context).platformDispatcher.locale,
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Language'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(context.tr('Interface language')),
            subtitle: Text(
              _interfaceLanguageSubtitle(context, settings, interfaceLocale),
            ),
            trailing: _SelectedLanguageFlags([
              interfaceFlagCode(interfaceLocale.languageCode),
            ]),
            onTap: () => context.push(AppRoutes.interfaceLanguage),
          ),
          ListTile(
            title: Text(context.tr('Listening language')),
            subtitle: Text(_discoverLanguagesSubtitle(context, languages)),
            trailing: _SelectedLanguageFlags(
              discoverLanguagesAreAll(languages) ? const [] : languages,
            ),
            onTap: () => context.push(AppRoutes.discoverLanguages),
          ),
        ],
      ),
    );
  }
}

class _SelectedLanguageFlags extends StatelessWidget {
  const _SelectedLanguageFlags(this.codes);

  final List<String> codes;

  static const _size = 22.0;
  static const _overlap = 8.0;
  static const _max = 6;

  @override
  Widget build(BuildContext context) {
    final flags = [
      for (final code in codes)
        if (languageFlagAsset(code) != null || languageFlagIso(code) != null)
          code,
    ];
    final shown = flags.take(_max).toList();
    final extra = flags.length - shown.length;
    final width = shown.isEmpty
        ? 0.0
        : _size + (shown.length - 1) * (_size - _overlap);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shown.isNotEmpty)
          SizedBox(
            width: width,
            height: _size,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  PositionedDirectional(
                    start: i * (_size - _overlap),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                      child: LanguageFlag(
                        languageCode: shown[i],
                        size: _size - 3,
                        placeholder: false,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (extra > 0) ...[
          const SizedBox(width: 4),
          Text('+$extra', style: Theme.of(context).textTheme.labelMedium),
        ],
        const Icon(Icons.chevron_right),
      ],
    );
  }
}

String _discoverLanguagesSubtitle(
  BuildContext context,
  List<String> languages,
) {
  if (discoverLanguagesAreAll(languages)) {
    return context.tr('All languages');
  }
  if (languages.length > 2) {
    return context.tr('{count} languages', {'count': '${languages.length}'});
  }
  return discoverLanguagesSummary(languages);
}

String _interfaceLanguageSubtitle(
  BuildContext context,
  AppSettings settings,
  Locale interfaceLocale,
) {
  final stored = settings.interfaceLanguage;
  if (stored == null) {
    return '${context.tr('System')} · ${interfaceLanguageEndonym(interfaceLocale.languageCode)}';
  }
  return interfaceLanguageEndonym(stored);
}
