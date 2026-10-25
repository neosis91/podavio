import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saf_util/saf_util.dart';

import '../core/build_info.dart';
import '../l10n/l10n.dart';
import '../data/app_release.dart';
import '../data/database_backup.dart';
import '../data/download_service.dart';
import '../data/feed_refresh_controller.dart';
import '../data/html_export.dart';
import '../data/opml.dart';
import '../data/providers.dart';
import '../nearby/nearby_apk_source.dart';
import '../settings/settings_controller.dart';
import '../sync/sync_controller.dart';
import 'episodes_page.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/frosted_header.dart';
import 'widgets/messages.dart';
import 'widgets/update_prompt.dart';

final _packageInfo = PackageInfo.fromPlatform();

/// Même import que « Importer la base de données ». Vrai si le fichier est lu.
Future<bool> importLibraryDatabase(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('Import database')),
      content: Text(
        context.tr(
          'This replaces your current subscriptions, queue, favorites, and playback progress. Downloaded audio files are not restored. Continue?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.tr('Import')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final file = await FilePicker.pickFile(
    dialogTitle: context.tr('Import database'),
    type: FileType.any,
  );
  if (file == null || !context.mounted) return false;
  final name = file.name.toLowerCase();
  if (!name.endsWith('.sqlite') &&
      !name.endsWith('.db') &&
      !name.endsWith('.sqlite3')) {
    showMessage(context, context.tr('Choose a .sqlite or .db database file'));
    return false;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final bytes = await file.readAsBytes();
    await importDatabaseBytes(ref, bytes);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showMessage(context, context.tr('Database imported'));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showMessage(
        context,
        errorText(error).isEmpty
            ? context.tr('Could not import the database')
            : errorText(error),
      );
    }
    return false;
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FrostedScaffold(
      appBar: FrostedAppBar(title: Text(context.tr('About'))),
      body: ListView(
        padding: belowFrostedBar(
          context,
          const EdgeInsets.fromLTRB(24, 24, 24, 24),
        ),
        children: [
          const Center(child: PodavioLogo()),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) {
              final packaged = snapshot.data?.version;
              final version = BuildInfo.version.isNotEmpty
                  ? BuildInfo.version
                  : packaged;
              if (version == null || version.isEmpty) {
                return const SizedBox.shrink();
              }
              final commit = BuildInfo.hasCommit ? BuildInfo.commit : null;
              final label = commit == null ? version : '$version ($commit)';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Version')),
                subtitle: Text(label),
              );
            },
          ),
          const _CheckUpdateTile(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Licenses')),
            subtitle: Text(
              context.tr('Software and libraries used by Podavio'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.licenses),
          ),
        ],
      ),
    );
  }
}

class _CheckUpdateTile extends ConsumerStatefulWidget {
  const _CheckUpdateTile();

  @override
  ConsumerState<_CheckUpdateTile> createState() => _CheckUpdateTileState();
}

class _CheckUpdateTileState extends ConsumerState<_CheckUpdateTile> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final checkedAt = ref.watch(appUpdateCheckedAtProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !_busy,
      title: Text(context.tr('Check for an application update')),
      subtitle: Text(_checkedAtLabel(context, checkedAt)),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _busy ? null : _check,
    );
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final lookup = await lookupAppUpdate();
      if (appUpdateWasChecked(lookup)) {
        await ref
            .read(appUpdateCheckedAtProvider.notifier)
            .mark(DateTime.now());
      }
      if (!mounted) return;
      switch (lookup) {
        case AppUpdateNewer(:final release):
          await promptAppUpdate(context, release);
        case AppUpdateCurrent():
          showMessage(context, context.tr('Podavio is up to date'));
        case AppUpdateUnversioned(:final published):
          showMessage(
            context,
            context.tr('Published version: {version}', {
              'version': published.version,
            }),
          );
        case AppUpdateFailed():
          showMessage(context, context.tr('The update check failed'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

String _checkedAtLabel(BuildContext context, DateTime? checkedAt) {
  if (checkedAt == null) return context.tr('Not checked yet');
  final local = checkedAt.toLocal();
  final when = DateFormat.yMMMd().add_Hm().format(local);
  return context.tr('Last check: {when}', {'when': when});
}

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refreshing = ref.watch(
      feedRefreshProvider.select((s) => s.isRunning),
    );
    final sync = ref.watch(syncStatusProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.refresh,
              color: refreshing ? Theme.of(context).disabledColor : null,
            ),
            title: Text(
              refreshing
                  ? context.tr('Refreshing…')
                  : context.tr('Refresh all subscriptions'),
            ),
            enabled: !refreshing,
            onTap: refreshing ? null : () => refreshSubscriptions(context, ref),
          ),
          ListTile(
            leading: const TranslateIcon(),
            title: Text(context.tr('Language')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.languages),
          ),
          const Divider(),
          _SectionTitle(context.tr('Advanced')),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.tr('Interface')),
            onTap: () => context.push(AppRoutes.appearance),
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: Text(context.tr('Playback')),
            onTap: () => context.push(AppRoutes.playback),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(context.tr('Synchronization')),
            subtitle: Text(
              sync.connected
                  ? context.tr(sync.provider?.titleKey ?? 'Synchronization')
                  : context.tr('Synchronization is off'),
            ),
            onTap: () => context.push(AppRoutes.sync),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(context.tr('Notifications')),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(context.tr('Download manager')),
            onTap: () => context.push(AppRoutes.downloadSettings),
          ),
          ListTile(
            leading: const Icon(Icons.wifi),
            title: Text(context.tr('Network')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.network),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(context.tr('Backup and restore')),
            onTap: () => context.push(AppRoutes.backupRestore),
          ),
          _SectionTitle(context.tr('Miscellaneous')),
          if (NearbyApkSource().isSupported)
            ListTile(
              leading: const Icon(Icons.qr_code_2_outlined),
              title: Text(context.tr('Share Podavio nearby')),
              subtitle: Text(
                context.tr(
                  'Install on another phone over Wi-Fi, without internet',
                ),
              ),
              onTap: () => context.push(AppRoutes.nearbyShare),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.tr('About')),
            onTap: () => context.push(AppRoutes.about),
          ),
        ],
      ),
    );
  }
}

class BackupRestorePage extends ConsumerWidget {
  const BackupRestorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final autoFolder = settings.automaticDatabaseBackupFolder;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Backup and restore'))),
      body: ListView(
        children: [
          _SectionTitle(context.tr('Database')),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(context.tr('Export database')),
            subtitle: Text(
              context.tr(
                'Subscriptions, queue, favorites, and playback progress. Not the downloaded audio files.',
              ),
            ),
            onTap: () => _exportDatabase(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.schedule_outlined),
            title: Text(context.tr('Automatic database export')),
            subtitle: Text(
              settings.automaticDatabaseBackup
                  ? context.tr(
                      'Every 3 days. Keeps the 5 most recent backups.{folder}',
                      {
                        'folder': autoFolder == null || autoFolder.isEmpty
                            ? ''
                            : '\n${downloadDirectoryLabel(autoFolder)}',
                      },
                    )
                  : context.tr(
                      'Saves a copy every 3 days and keeps the 5 most recent.',
                    ),
            ),
            value: settings.automaticDatabaseBackup,
            onChanged: (enabled) =>
                _setAutomaticDatabaseBackup(context, ref, enabled),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: Text(context.tr('Import database')),
            subtitle: Text(
              context.tr(
                'Replaces the current database. Downloaded episodes must be re-downloaded.',
              ),
            ),
            onTap: () => _importDatabase(context, ref),
          ),
          const _SectionTitle('OPML'),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: Text(context.tr('Import an OPML file')),
            subtitle: Text(
              context.tr('Subscriptions exported from another app'),
            ),
            onTap: () => importOpmlFile(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(context.tr('Export subscriptions')),
            subtitle: Text(context.tr('OPML file')),
            onTap: () => _exportOpml(context, ref),
          ),
          const _SectionTitle('HTML'),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(context.tr('Export subscriptions')),
            subtitle: Text(
              context.tr('HTML page to open or share (cannot be re-imported)'),
            ),
            onTap: () => _exportSubscriptionsHtml(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: Text(context.tr('Export favorites')),
            subtitle: Text(
              context.tr(
                'HTML page grouped by podcast (cannot be re-imported)',
              ),
            ),
            onTap: () => _exportFavoritesHtml(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDatabase(BuildContext context, WidgetRef ref) async {
    final dialogTitle = context.tr('Export database');
    final doneMsg = context.tr('Database exported');
    final failedMsg = context.tr('Could not export the database');
    try {
      final bytes = await exportDatabaseBytes(ref.read(databaseProvider));
      final saved = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: databaseBackupFileName(),
        bytes: bytes,
        mimeType: 'application/x-sqlite3',
      );
      if (saved != null && context.mounted) {
        showMessage(context, doneMsg);
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          errorText(error).isEmpty ? failedMsg : errorText(error),
        );
      }
    }
  }

  Future<void> _setAutomaticDatabaseBackup(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (!enabled) {
      await ref
          .read(settingsProvider.notifier)
          .setAutomaticDatabaseBackup(false);
      return;
    }
    final folder = await _pickBackupFolder(context, ref);
    if (folder == null) return;
    await ref
        .read(settingsProvider.notifier)
        .setAutomaticDatabaseBackupFolder(folder);
    await ref.read(settingsProvider.notifier).setAutomaticDatabaseBackup(true);
    if (context.mounted) {
      showMessage(context, context.tr('Automatic database export is on'));
    }
  }

  Future<String?> _pickBackupFolder(BuildContext context, WidgetRef ref) async {
    final current = ref.read(settingsProvider).automaticDatabaseBackupFolder;
    try {
      if (Platform.isAndroid) {
        final folder = await SafUtil().pickDirectory(
          initialUri: current != null && isContentUri(current) ? current : null,
          writePermission: true,
          persistablePermission: true,
        );
        return folder?.uri;
      }
      return await FilePicker.getDirectoryPath(
        dialogTitle: context.tr('Backup folder'),
        initialDirectory: current != null && !isContentUri(current)
            ? current
            : null,
      );
    } catch (error) {
      if (context.mounted) {
        showMessage(context, errorText(error));
      }
      return null;
    }
  }

  Future<void> _importDatabase(BuildContext context, WidgetRef ref) async {
    final imported = await importLibraryDatabase(context, ref);
    if (imported && context.mounted) context.go(AppRoutes.home);
  }

  Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {
    final emptyMsg = context.tr('No subscriptions to export');
    final dialogTitle = context.tr('Export subscriptions');
    final doneMsg = context.tr('Subscriptions exported');
    final podcasts = await ref.read(databaseProvider).listPodcasts();
    if (podcasts.isEmpty) {
      if (context.mounted) showMessage(context, emptyMsg);
      return;
    }
    final xml = buildOpml(podcasts);
    final saved = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: 'podavio.opml',
      bytes: Uint8List.fromList(utf8.encode(xml)),
      mimeType: 'text/x-opml',
    );
    if (saved != null && context.mounted) {
      showMessage(context, doneMsg);
    }
  }

  Future<void> _exportSubscriptionsHtml(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final emptyMsg = context.tr('No subscriptions to export');
    final dialogTitle = context.tr('Export subscriptions (HTML)');
    final doneMsg = context.tr('Subscriptions exported as HTML');
    final podcasts = await ref.read(databaseProvider).listPodcasts();
    if (podcasts.isEmpty) {
      if (context.mounted) showMessage(context, emptyMsg);
      return;
    }
    final html = await buildSubscriptionsHtml(podcasts);
    final saved = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: 'podavio-subscriptions-${_exportStamp()}.html',
      bytes: Uint8List.fromList(utf8.encode(html)),
      mimeType: 'text/html',
    );
    if (saved != null && context.mounted) {
      showMessage(context, doneMsg);
    }
  }

  Future<void> _exportFavoritesHtml(BuildContext context, WidgetRef ref) async {
    final emptyMsg = context.tr('No favorites to export');
    final dialogTitle = context.tr('Export favorites (HTML)');
    final doneMsg = context.tr('Favorites exported as HTML');
    final favorites = await ref
        .read(databaseProvider)
        .watchEpisodes(favoritesOnly: true)
        .first;
    if (favorites.isEmpty) {
      if (context.mounted) showMessage(context, emptyMsg);
      return;
    }
    final html = await buildFavoritesHtml(favorites);
    final saved = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: 'podavio-favorites-${_exportStamp()}.html',
      bytes: Uint8List.fromList(utf8.encode(html)),
      mimeType: 'text/html',
    );
    if (saved != null && context.mounted) {
      showMessage(context, doneMsg);
    }
  }
}

String _exportStamp() {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

/// Sélectionne un fichier OPML et ouvre l’écran d’import.
Future<void> importOpmlFile(BuildContext context, WidgetRef ref) async {
  // Sur Android, FileType.custom + extension « opml » est filtré via MimeTypeMap
  // (inconnu → seul text/xml reste). Les .opml s’affichent alors sans pouvoir
  // être sélectionnés. On laisse choisir n’importe quel fichier, puis on valide.
  final file = await FilePicker.pickFile(
    dialogTitle: 'Importer un OPML',
    type: FileType.any,
  );
  if (file == null) return;
  final name = (file.name).toLowerCase();
  if (!name.endsWith('.opml') && !name.endsWith('.xml')) {
    if (context.mounted) {
      showMessage(context, 'Choisissez un fichier .opml ou .xml');
    }
    return;
  }
  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Impossible de lire ce fichier');
    }
    return;
  }
  List<OpmlEntry> entries;
  try {
    final text = _decodeOpmlBytes(bytes);
    entries = parseOpmlEntries(text);
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Ce fichier OPML est illisible');
    }
    return;
  }
  if (entries.isEmpty) {
    if (context.mounted) {
      showMessage(context, 'Aucun flux trouvé dans ce fichier');
    }
    return;
  }
  if (!context.mounted) return;
  await context.push(AppRoutes.opmlImport, extra: entries);
}

String _decodeOpmlBytes(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
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
