import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saf_util/saf_util.dart';

import '../core/theme.dart';
import '../core/wallpaper_colors.dart';
import '../l10n/interface_locale.dart';
import '../l10n/l10n.dart';
import '../data/discover_languages.dart';
import '../data/download_controller.dart';
import '../data/download_service.dart';
import '../data/providers.dart';
import '../data/catalog_categories.dart';
import '../data/discover_providers.dart';
import '../settings/settings_controller.dart';
import '../sync/sync_controller.dart';
import 'interface_language_page.dart';
import 'router.dart';
import 'widgets/app_bottom_sheet.dart';
import 'widgets/brand.dart';
import 'widgets/choice_dialog.dart';
import 'widgets/messages.dart';
import 'widgets/language_flag.dart';
import 'widgets/list_metrics.dart';
import 'widgets/player_keyboard_shortcuts.dart';

class EcoModePage extends ConsumerWidget {
  const EcoModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settingsProvider.select((settings) => settings.ecoMode),
    );
    final idle = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Eco mode'))),
      body: ListView(
        padding: underChrome(context, const EdgeInsets.only(bottom: 32)),
        children: [
          SwitchListTile(
            secondary: EcoIcon(color: enabled ? podavioGreen : idle),
            title: Text(context.tr('Eco mode')),
            value: enabled,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setEcoMode(value),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              context.tr(
                'Eco mode limits network requests. Covers already saved or cached stay visible. New covers are not downloaded: the name appears in a square that follows the theme, with its own color for the border and the text. Pure black turns on to save battery. Automatic cover downloads stop, and the player no longer fetches a cover only to tint the screen.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final wallpaperOption = defaultTargetPlatform != TargetPlatform.iOS;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Interface'))),
      body: ListView(
        padding: underChrome(context, const EdgeInsets.only(bottom: 32)),
        children: [
          ListTile(title: Text(context.tr('Appearance'))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(context.tr('System')),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(context.tr('Light')),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(context.tr('Dark')),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) =>
                  notifier.setThemeMode(selection.first),
            ),
          ),
          SwitchListTile(
            title: Text(context.tr('Pure black')),
            subtitle: Text(
              context.tr(
                settings.ecoMode
                    ? 'Pure black stays on while Eco mode is on'
                    : 'Black background in dark mode',
              ),
            ),
            value: settings.pureBlack || settings.ecoMode,
            onChanged: settings.ecoMode ? null : notifier.setPureBlack,
          ),
          if (wallpaperOption)
            SwitchListTile(
              title: Text(context.tr('Wallpaper')),
              subtitle: Text(_wallpaperSubtitle(context, ref)),
              value: settings.wallpaperColors,
              onChanged: notifier.setWallpaperColors,
            ),
          if (!wallpaperOption || !settings.wallpaperColors) ...[
            const SizedBox(height: 8),
            ListTile(title: Text(context.tr('Color'))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final accent in AppAccent.values)
                    _AccentChoice(
                      accent: accent,
                      selected: settings.accent == accent,
                      onTap: () => notifier.setAccent(accent),
                    ),
                ],
              ),
            ),
          ],
          SwitchListTile(
            title: Text(context.tr('Cover tint')),
            subtitle: Text(
              context.tr('The player and the top of the home follow the cover'),
            ),
            value: settings.tintFromCover,
            onChanged: notifier.setTintFromCover,
          ),
          ListTile(
            title: Text(context.tr('Shelves')),
            subtitle: Text(context.tr('Order and hide the home shelves')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showHomeShelvesSheet(context, ref),
          ),
          ListTile(
            title: Text(context.tr('Categories')),
            subtitle: Text(
              context.tr(
                'Until you choose, the home follows the most played categories this month.',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showHomeCategoriesSheet(context, ref),
          ),
        ],
      ),
    );
  }
}

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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

String _wallpaperSubtitle(BuildContext context, WidgetRef ref) {
  final palette = ref.watch(wallpaperPaletteProvider);
  final enabled = ref.watch(
    settingsProvider.select((settings) => settings.wallpaperColors),
  );
  if (!enabled) {
    return context.tr('Match colors to the wallpaper');
  }
  if (palette.isLoading) return context.tr('Reading the wallpaper…');
  if (palette.hasError || palette.asData?.value == null) {
    return context.tr('The wallpaper could not be read');
  }
  return context.tr('Colors follow the wallpaper');
}

class NetworkSettingsPage extends ConsumerWidget {
  const NetworkSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Network'))),
      body: ListView(
        children: [
          _SectionTitle(context.tr('Data usage')),
          SwitchListTile(
            title: Text(context.tr('Episode downloads')),
            subtitle: Text(
              _networkModeLabel(context, settings.allowMobileData),
            ),
            value: settings.allowMobileData,
            onChanged: notifier.setAllowMobileData,
          ),
          SwitchListTile(
            title: Text(context.tr('Streaming')),
            subtitle: Text(
              _networkModeLabel(context, settings.allowMobileStreaming),
            ),
            value: settings.allowMobileStreaming,
            onChanged: notifier.setAllowMobileStreaming,
          ),
          SwitchListTile(
            title: Text(context.tr('Refresh')),
            subtitle: Text(
              _networkModeLabel(context, settings.allowMobileRefresh),
            ),
            value: settings.allowMobileRefresh,
            onChanged: notifier.setAllowMobileRefresh,
          ),
        ],
      ),
    );
  }
}

String _networkModeLabel(BuildContext context, bool unrestricted) {
  return context.tr(unrestricted ? 'Wi-Fi and mobile data' : 'Wi-Fi only');
}

class DownloadSettingsPage extends ConsumerWidget {
  const DownloadSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final directory = settings.downloadDirectory;
    final fallback = ref.watch(defaultDownloadDirectoryProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Download manager'))),
      body: ListView(
        children: [
          const _SectionTitle('Dossiers'),
          ListTile(
            title: const Text('Dossier des téléchargements'),
            subtitle: Text(
              directory == null
                  ? (fallback ?? '…')
                  : downloadDirectoryLabel(directory),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _chooseDownloadDirectory(context, ref),
          ),
          if (directory != null)
            ListTile(
              title: const Text('Utiliser le dossier de l’application'),
              onTap: () => _relocateDownloads(context, ref, null),
            ),
          const _SectionTitle('Automatisation'),
          SwitchListTile(
            title: Text(context.tr('Automatic download')),
            subtitle: Text(
              context.tr(
                'Includes every subscription. Each podcast can be excluded from its menu. Turning this off keeps those choices.',
              ),
            ),
            value: settings.automaticDownload,
            onChanged: (enabled) =>
                _setAutomaticDownload(context, ref, enabled),
          ),
          ListTile(
            title: Text(context.tr('Download limit')),
            subtitle: Text(
              '${context.tr('Maximum number of episodes to download per podcast during an automatic download.')}\n'
              '${context.tr(automaticDownloadLimitLabel(settings.automaticDownloadLimit))}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickAutomaticDownloadLimit(context, ref),
          ),
          ListTile(
            title: Text(context.tr('Episode cache')),
            subtitle: Text(
              context.tr(episodeCacheSizeLabel(settings.episodeCacheSize)),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickEpisodeCacheSize(context, ref),
          ),
          SwitchListTile(
            title: const Text('Retirer de la playlist'),
            subtitle: const Text(
              'Enlève l’épisode de la playlist quand son téléchargement est supprimé',
            ),
            value: settings.dequeueDeletedDownloads,
            onChanged: ref
                .read(settingsProvider.notifier)
                .setDequeueDeletedDownloads,
          ),
          _SectionTitle(context.tr('Automatic deletion')),
          SwitchListTile(
            title: Text(context.tr('Delete after playback')),
            subtitle: Text(
              context.tr(
                'Deletes the file when playback finishes. Favorites are kept.',
              ),
            ),
            value: settings.deleteAfterPlayback,
            onChanged: ref
                .read(settingsProvider.notifier)
                .setDeleteAfterPlayback,
          ),
          ListTile(
            title: Text(context.tr('Free up space')),
            subtitle: Text(
              '${context.tr(settings.episodeCacheCleanup.label)}\n'
              '${context.tr('Only when the cache is full, before an automatic download. Favorites are kept.')}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickEpisodeCacheCleanup(context, ref),
          ),
          const _SectionTitle('Actions'),
          ListTile(
            title: const Text('Supprimer tous les téléchargements'),
            subtitle: const Text(
              'Efface les fichiers locaux de tous les épisodes téléchargés',
            ),
            onTap: () => _confirmDeleteAllDownloads(context, ref),
          ),
        ],
      ),
    );
  }
}

Future<void> _setNotifyNewEpisodes(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  if (enabled) {
    try {
      await ref
          .read(databaseProvider)
          .enableEpisodeNotificationForSubscriptions();
    } catch (error) {
      if (context.mounted) showMessage(context, errorText(error));
      return;
    }
  }
  await ref.read(settingsProvider.notifier).setNotifyNewEpisodes(enabled);
}

Future<void> _setAutomaticDownload(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  if (enabled) {
    try {
      await ref.read(databaseProvider).enableAutoDownloadForSubscriptions();
    } catch (error) {
      if (context.mounted) showMessage(context, errorText(error));
      return;
    }
  }
  await ref.read(settingsProvider.notifier).setAutomaticDownload(enabled);
}

Future<void> _pickAutomaticDownloadLimit(
  BuildContext context,
  WidgetRef ref,
) async {
  final current = ref.read(settingsProvider).automaticDownloadLimit;
  final choice = await showRadioChoiceDialog<int>(
    context,
    title: 'Download limit',
    selected: current ?? 0,
    options: [
      (value: 0, label: automaticDownloadLimitLabel(null)),
      for (final limit in automaticDownloadLimits)
        (value: limit, label: automaticDownloadLimitLabel(limit)),
    ],
  );
  if (choice == null) return;
  await ref
      .read(settingsProvider.notifier)
      .setAutomaticDownloadLimit(choice == 0 ? null : choice);
}

Future<void> _pickEpisodeCacheSize(BuildContext context, WidgetRef ref) async {
  final selected = ref.read(settingsProvider).episodeCacheSize ?? 0;
  final choice = await showChoiceDialog<int>(
    context,
    title: 'Episode cache',
    selected: selected,
    options: [
      (value: 0, label: episodeCacheSizeLabel(null)),
      for (final size in episodeCacheSizes)
        (value: size, label: episodeCacheSizeLabel(size)),
    ],
  );
  if (choice == null) return;
  await ref
      .read(settingsProvider.notifier)
      .setEpisodeCacheSize(choice == 0 ? null : choice);
}

Future<void> _pickEpisodeCacheCleanup(
  BuildContext context,
  WidgetRef ref,
) async {
  final selected = ref.read(settingsProvider).episodeCacheCleanup;
  final choice = await showChoiceDialog<EpisodeCacheCleanup>(
    context,
    title: 'Free up space',
    selected: selected,
    options: [
      for (final policy in EpisodeCacheCleanup.values)
        (value: policy, label: policy.label),
    ],
  );
  if (choice == null) return;
  await ref.read(settingsProvider.notifier).setEpisodeCacheCleanup(choice);
}

Future<void> _confirmDeleteAllDownloads(
  BuildContext context,
  WidgetRef ref,
) async {
  if (ref.read(downloadProgressProvider).isNotEmpty) {
    showMessage(context, 'Attendez la fin des téléchargements en cours.');
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer tous les téléchargements ?'),
      content: const Text(
        'Tous les fichiers téléchargés seront effacés. Cette action est irréversible.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await _deleteAllDownloads(context, ref);
}

Future<void> _deleteAllDownloads(BuildContext context, WidgetRef ref) async {
  if (ref.read(downloadProgressProvider).isNotEmpty) {
    showMessage(context, 'Attendez la fin des téléchargements en cours.');
    return;
  }
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Expanded(child: Text('Suppression des téléchargements…')),
          ],
        ),
      ),
    ),
  );
  try {
    final count = await ref
        .read(downloadProgressProvider.notifier)
        .deleteAllDownloads();
    if (context.mounted) {
      showMessage(
        context,
        count == 0
            ? 'Aucun téléchargement à supprimer'
            : count == 1
            ? '1 téléchargement supprimé'
            : '$count téléchargements supprimés',
      );
    }
  } catch (error) {
    if (context.mounted) showMessage(context, errorText(error));
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

Future<void> _chooseDownloadDirectory(
  BuildContext context,
  WidgetRef ref,
) async {
  if (ref.read(downloadProgressProvider).isNotEmpty) {
    showMessage(context, 'Attendez la fin des téléchargements en cours.');
    return;
  }
  final current = ref.read(settingsProvider).downloadDirectory;
  final String? picked;
  try {
    if (Platform.isAndroid) {
      final folder = await SafUtil().pickDirectory(
        initialUri: current != null && isContentUri(current) ? current : null,
        writePermission: true,
        persistablePermission: true,
      );
      picked = folder?.uri;
    } else {
      final initial =
          current ??
          await ref
              .read(downloadServiceProvider)
              .resolveDownloadDirectory(null);
      picked = await FilePicker.getDirectoryPath(
        dialogTitle: 'Dossier des téléchargements',
        initialDirectory: initial,
      );
    }
  } catch (error) {
    if (context.mounted) showMessage(context, errorText(error));
    return;
  }
  if (picked == null || !context.mounted) return;
  await _relocateDownloads(context, ref, picked);
}

Future<void> _relocateDownloads(
  BuildContext context,
  WidgetRef ref,
  String? destination,
) async {
  if (ref.read(downloadProgressProvider).isNotEmpty) {
    showMessage(context, 'Attendez la fin des téléchargements en cours.');
    return;
  }
  final service = ref.read(downloadServiceProvider);
  final current = ref.read(settingsProvider).downloadDirectory;
  final source = await service.resolveDownloadDirectory(current);
  final target = await service.resolveDownloadDirectory(destination);
  if (!context.mounted) return;
  if (sameDownloadLocation(source, target)) {
    showMessage(context, 'Ce dossier est déjà utilisé.');
    return;
  }
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Expanded(child: Text('Déplacement des fichiers…')),
          ],
        ),
      ),
    ),
  );
  try {
    final result = await service.relocateDownloads(
      from: current,
      to: destination,
    );
    await ref.read(settingsProvider.notifier).setDownloadDirectory(destination);
    if (context.mounted) showMessage(context, _relocationMessage(result));
  } catch (error) {
    if (context.mounted) showMessage(context, errorText(error));
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

String _relocationMessage(DownloadRelocation result) {
  if (result.failed > 0) {
    return result.moved == 0
        ? 'Le dossier est modifié, mais les fichiers n’ont pas pu être déplacés'
        : 'Le dossier est modifié. ${result.moved} déplacés, ${result.failed} en échec';
  }
  return result.moved == 0
      ? 'Dossier des téléchargements modifié'
      : 'Fichiers déplacés';
}

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final syncConnected = ref.watch(
      syncStatusProvider.select((status) => status.connected),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Notifications'))),
      body: ListView(
        children: [
          _SectionTitle(context.tr('Downloads')),
          SwitchListTile(
            title: Text(context.tr('Download progress')),
            subtitle: Text(
              context.tr(
                'Shows a notification while an episode downloads, and when it finishes.',
              ),
            ),
            value: settings.notifyDownloadActivity,
            onChanged: notifier.setNotifyDownloadActivity,
          ),
          SwitchListTile(
            title: Text(context.tr('Download errors')),
            subtitle: Text(
              context.tr('Shows a notification when a download fails.'),
            ),
            value: settings.notifyDownloadErrors,
            onChanged: notifier.setNotifyDownloadErrors,
          ),
          _SectionTitle(context.tr('Synchronization')),
          SwitchListTile(
            title: Text(context.tr('Synchronization errors')),
            subtitle: Text(
              context.tr(
                syncConnected
                    ? 'Shows a notification when synchronization fails.'
                    : 'Connect a synchronization service to enable this.',
              ),
            ),
            value: settings.notifySyncErrors,
            onChanged: syncConnected ? notifier.setNotifySyncErrors : null,
          ),
          _SectionTitle(context.tr('New episodes')),
          SwitchListTile(
            title: Text(context.tr('Notify about new episodes')),
            subtitle: Text(
              context.tr(
                'Notifies when a subscription publishes. Each podcast can be turned off in its settings. Turning this off keeps those choices.',
              ),
            ),
            value: settings.notifyNewEpisodes,
            onChanged: (enabled) =>
                _setNotifyNewEpisodes(context, ref, enabled),
          ),
        ],
      ),
    );
  }
}

class PlaybackPage extends ConsumerWidget {
  const PlaybackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Playback'))),
      body: ListView(
        padding: underChrome(context, const EdgeInsets.only(bottom: 32)),
        children: [
          _SectionTitle(context.tr('Controls')),
          ListTile(
            title: Text(context.tr('Rewind')),
            subtitle: Text(
              context.tr('{seconds} seconds', {
                'seconds': '${settings.skipBackSeconds}',
              }),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickIntSetting(
              context,
              title: 'Rewind',
              selected: settings.skipBackSeconds,
              values: const [5, 10, 15, 30],
              label: (seconds) => '$seconds s',
              onChanged: notifier.setSkipBack,
            ),
          ),
          ListTile(
            title: Text(context.tr('Fast forward')),
            subtitle: Text(
              context.tr('{seconds} seconds', {
                'seconds': '${settings.skipForwardSeconds}',
              }),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickIntSetting(
              context,
              title: 'Fast forward',
              selected: settings.skipForwardSeconds,
              values: const [10, 15, 30, 45, 60],
              label: (seconds) => '$seconds s',
              onChanged: notifier.setSkipForward,
            ),
          ),
          ListTile(
            title: Text(context.tr('Outside the app')),
            subtitle: Text(_outsideAppSubtitle(context, settings)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickOutsideApp(context, ref),
          ),
          _SectionTitle(context.tr('Player')),
          SwitchListTile(
            title: Text(context.tr('Time remaining')),
            subtitle: Text(
              context.tr(
                'Shows the remaining time on the right of the progress bar',
              ),
            ),
            value: settings.showRemainingTime,
            onChanged: notifier.setShowRemainingTime,
          ),
          SwitchListTile(
            title: Text(context.tr('Time follows speed')),
            subtitle: Text(
              context.tr(
                'Adjusts the displayed position and duration to the playback speed',
              ),
            ),
            value: settings.timeRespectsSpeed,
            onChanged: notifier.setTimeRespectsSpeed,
          ),
          SwitchListTile(
            title: Text(context.tr('Keep screen on')),
            subtitle: Text(context.tr('Prevents sleep during playback')),
            value: settings.keepScreenOn,
            onChanged: notifier.setKeepScreenOn,
          ),
          ListTile(
            leading: const Icon(Icons.keyboard_alt_outlined),
            title: Text(context.tr('Player help')),
            subtitle: const Text(
              'Gestes couverture, Espace, J, L, volume… — aussi via ?',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showPlayerKeyboardHelp(context),
          ),
          _SectionTitle(context.tr('Mini player')),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(context.tr('Button layout')),
            subtitle: Text(settings.miniPlayerButtons.summary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showMiniPlayerButtonsSheet(context, ref),
          ),
          _SectionTitle(context.tr('Episodes')),
          SwitchListTile(
            title: Text(context.tr('Podcast artwork')),
            subtitle: Text(
              context.tr(
                'Shows the podcast cover instead of the episode cover',
              ),
            ),
            value: settings.preferPodcastCover,
            onChanged: notifier.setPreferPodcastCover,
          ),
          ListTile(
            title: Text(context.tr('List density')),
            subtitle: Text(context.tr('Spacing between episode rows')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<EpisodeListDensity>(
              segments: [
                for (final density in EpisodeListDensity.values)
                  ButtonSegment(
                    value: density,
                    label: Text(context.tr(density.label)),
                  ),
              ],
              selected: {settings.episodeListDensity},
              onSelectionChanged: (selection) =>
                  notifier.setEpisodeListDensity(selection.first),
            ),
          ),
          _SectionTitle(context.tr('Refresh')),
          ListTile(
            title: Text(context.tr('Refresh interval')),
            subtitle: Text(
              settings.refreshIntervalMinutes == 0
                  ? context.tr('No limit between refreshes')
                  : context.tr('At least {minutes} min between refreshes', {
                      'minutes': '${settings.refreshIntervalMinutes}',
                    }),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickIntSetting(
              context,
              title: 'Refresh interval',
              selected: settings.refreshIntervalMinutes,
              values: const [0, 1, 5, 15, 30, 60],
              label: _refreshIntervalLabel,
              onChanged: notifier.setRefreshIntervalMinutes,
            ),
          ),
          _SectionTitle(context.tr('Downloads')),
          SwitchListTile(
            title: Text(context.tr('Add to playlist')),
            subtitle: Text(
              context.tr(
                'Adds the episode to the playlist when the download finishes',
              ),
            ),
            value: settings.enqueueDownloads,
            onChanged: notifier.setEnqueueDownloads,
          ),
        ],
      ),
    );
  }
}

Future<void> _pickIntSetting(
  BuildContext context, {
  required String title,
  required int selected,
  required List<int> values,
  required String Function(int value) label,
  required ValueChanged<int> onChanged,
}) async {
  final choices = [...values];
  if (!choices.contains(selected)) {
    choices
      ..add(selected)
      ..sort();
  }
  final choice = await showChoiceDialog<int>(
    context,
    title: title,
    selected: selected,
    options: [for (final value in choices) (value: value, label: label(value))],
  );
  if (choice != null) onChanged(choice);
}

String _outsideAppSubtitle(BuildContext context, AppSettings settings) {
  return switch (settings.outsideApp) {
    OutsideAppControl.skip => context.tr('{back} s back, {forward} s forward', {
      'back': '${settings.skipBackSeconds}',
      'forward': '${settings.skipForwardSeconds}',
    }),
    OutsideAppControl.episode => context.tr(OutsideAppControl.episode.label),
  };
}

Future<void> _pickOutsideApp(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  final choice = await showChoiceDialog<OutsideAppControl>(
    context,
    title: 'Outside the app',
    selected: settings.outsideApp,
    options: [
      for (final mode in OutsideAppControl.values)
        (value: mode, label: mode.label),
    ],
  );
  if (choice != null) {
    await ref.read(settingsProvider.notifier).setOutsideApp(choice);
  }
}

String _refreshIntervalLabel(int minutes) {
  return switch (minutes) {
    0 => 'None',
    60 => '1 h',
    _ => '$minutes min',
  };
}

Future<void> _showHomeShelvesSheet(BuildContext context, WidgetRef ref) {
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _HomeShelvesSheet(),
  );
}

class _HomeShelvesSheet extends ConsumerWidget {
  const _HomeShelvesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelves = ref.watch(
      settingsProvider.select((settings) => settings.homeShelves),
    );
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    Future<void> update(HomeShelves next) {
      return notifier.setHomeShelves(next);
    }

    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              context.tr('Shelves'),
              style: theme.textTheme.titleMedium,
            ),
          ),
          onReorderItem: (oldIndex, newIndex) {
            final order = [...shelves.order];
            final moved = order.removeAt(oldIndex);
            order.insert(newIndex, moved);
            update(shelves.copyWith(order: order));
          },
          children: [
            for (final entry in shelves.order.indexed)
              _HomeShelfRow(
                key: ValueKey(entry.$2),
                id: entry.$2,
                index: entry.$1,
                visible: shelves.isOn(entry.$2),
                onChanged: (value) {
                  final id = entry.$2;
                  final enabled = {...shelves.enabled};
                  if (value) {
                    enabled.add(id);
                  } else {
                    enabled.remove(id);
                  }
                  update(shelves.copyWith(enabled: enabled));
                },
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showHomeCategoriesSheet(BuildContext context, WidgetRef ref) {
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _HomeCategoriesSheet(),
  );
}

class _HomeCategoriesSheet extends ConsumerWidget {
  const _HomeCategoriesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(displayedHomeCategoriesProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    Future<void> update(HomeCategories next) {
      return notifier.setHomeCategories(next);
    }

    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              context.tr('Categories'),
              style: theme.textTheme.titleMedium,
            ),
          ),
          onReorderItem: (oldIndex, newIndex) {
            final order = [...categories.order];
            final moved = order.removeAt(oldIndex);
            order.insert(newIndex, moved);
            update(categories.copyWith(order: order));
          },
          children: [
            for (final entry in categories.order.indexed)
              _HomeShelfRow(
                key: ValueKey(entry.$2),
                id: entry.$2,
                index: entry.$1,
                visible: categories.isOn(entry.$2),
                title: homeCategoryTitle(entry.$2),
                onChanged: (value) {
                  final id = entry.$2;
                  final enabled = {...categories.enabled};
                  if (value) {
                    enabled.add(id);
                  } else {
                    enabled.remove(id);
                  }
                  update(categories.copyWith(enabled: enabled));
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeShelfRow extends StatelessWidget {
  const _HomeShelfRow({
    super.key,
    required this.id,
    required this.index,
    required this.visible,
    required this.onChanged,
    this.title,
  });

  final String id;
  final int index;
  final bool visible;
  final ValueChanged<bool> onChanged;

  /// Clé anglaise du libellé. Sans valeur, c’est le titre d’une étagère.
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Row(
        children: [
          Tooltip(
            message: context.tr('Move'),
            child: ReorderableDragStartListener(
              index: index,
              child: const SizedBox(
                width: 48,
                height: 56,
                child: Center(child: DragIndicatorIcon()),
              ),
            ),
          ),
          Expanded(
            child: SwitchListTile(
              value: visible,
              onChanged: onChanged,
              title: Text(context.tr(title ?? homeShelfTitle(id))),
              contentPadding: const EdgeInsets.only(right: 8),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showMiniPlayerButtonsSheet(BuildContext context, WidgetRef ref) {
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _MiniPlayerButtonsSheet(),
  );
}

class _MiniPlayerButtonsSheet extends ConsumerWidget {
  const _MiniPlayerButtonsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttons = ref.watch(
      settingsProvider.select((s) => s.miniPlayerButtons),
    );
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    Future<void> update(MiniPlayerButtons next) {
      return notifier.setMiniPlayerButtons(next);
    }

    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              context.tr('Mini player buttons'),
              style: theme.textTheme.titleMedium,
            ),
          ),
          onReorderItem: (oldIndex, newIndex) {
            final order = [...buttons.order];
            final moved = order.removeAt(oldIndex);
            order.insert(newIndex, moved);
            update(buttons.copyWith(order: order));
          },
          children: [
            for (final entry in buttons.order.indexed)
              _MiniPlayerButtonRow(
                key: ValueKey(entry.$2),
                id: entry.$2,
                index: entry.$1,
                checked: buttons.isOn(entry.$2),
                onChanged: entry.$2 == 'play'
                    ? null
                    : (value) {
                        final id = entry.$2;
                        final enabled = {...buttons.enabled};
                        if (value) {
                          enabled.add(id);
                        } else {
                          enabled.remove(id);
                        }
                        enabled.add('play');
                        update(buttons.copyWith(enabled: enabled));
                      },
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayerButtonRow extends StatelessWidget {
  const _MiniPlayerButtonRow({
    super.key,
    required this.id,
    required this.index,
    required this.checked,
    required this.onChanged,
  });

  final String id;
  final int index;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Row(
        children: [
          Tooltip(
            message: context.tr('Move'),
            child: ReorderableDragStartListener(
              index: index,
              child: const SizedBox(
                width: 48,
                height: 56,
                child: Center(child: DragIndicatorIcon()),
              ),
            ),
          ),
          Expanded(
            child: CheckboxListTile(
              value: checked,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value ?? false),
              title: Text(context.tr(_miniPlayerButtonTitle(id))),
              subtitle: switch (id) {
                'play' => Text(context.tr('Always shown')),
                'nextEpisode' => Text(context.tr('In the queue')),
                _ => null,
              },
              secondary: _miniPlayerButtonIcon(id),
              contentPadding: const EdgeInsets.only(right: 8),
            ),
          ),
        ],
      ),
    );
  }
}

String _miniPlayerButtonTitle(String id) {
  return switch (id) {
    'play' => 'Play / pause',
    'favorite' => 'Favorites',
    'skipBack' => 'Rewind',
    'skipForward' => 'Fast forward',
    'nextEpisode' => 'Next episode',
    'close' => 'Close the player',
    _ => id,
  };
}

Widget _miniPlayerButtonIcon(String id) {
  return switch (id) {
    'play' => const Icon(Icons.play_arrow),
    'favorite' => const Icon(Icons.favorite_border),
    'skipBack' => SkipIcon.back(size: 24),
    'skipForward' => SkipIcon.forward(size: 24),
    'nextEpisode' => SkipIcon.next(size: 24),
    'close' => const Icon(Icons.close),
    _ => const SizedBox.shrink(),
  };
}

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final check = accent.seed.computeLuminance() < 0.45
        ? Colors.white
        : Colors.black;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.seed,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: selected ? Icon(Icons.check, color: check) : null,
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(accent.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
