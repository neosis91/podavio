import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/build_info.dart';
import '../l10n/l10n.dart';
import '../data/app_release.dart';
import '../data/discover_languages.dart';
import '../data/feed_refresh_controller.dart';
import '../data/opml.dart';
import '../data/providers.dart';
import '../settings/settings_controller.dart';
import '../sync/sync_controller.dart';
import 'episodes_page.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/messages.dart';
import 'widgets/update_prompt.dart';

final _packageInfo = PackageInfo.fromPlatform();

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('About'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
            subtitle: const Text(
              'Logiciels et bibliothèques utilisés par Podavio',
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
    final languages = ref.watch(
      settingsProvider.select((settings) => settings.discoverLanguages),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.tr('Interface')),
            onTap: () => context.push(AppRoutes.appearance),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.tr('Explore')),
            subtitle: Text(_discoverLanguagesSubtitle(context, languages)),
            onTap: () => context.push(AppRoutes.discoverLanguages),
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
            leading: const Icon(Icons.archive_outlined),
            title: Text(context.tr('Backup and restore')),
            onTap: () => context.push(AppRoutes.backupRestore),
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

class BackupRestorePage extends ConsumerWidget {
  const BackupRestorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Backup and restore'))),
      body: ListView(
        children: [
          const _SectionTitle('OPML'),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Importer un fichier OPML'),
            subtitle: const Text(
              'Abonnements exportés depuis une autre application',
            ),
            onTap: () => importOpmlFile(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Exporter les abonnements'),
            subtitle: const Text('Fichier OPML'),
            onTap: () => _exportOpml(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {
    final podcasts = await ref.read(databaseProvider).listPodcasts();
    if (podcasts.isEmpty) {
      if (context.mounted) showMessage(context, 'Aucun abonnement à exporter');
      return;
    }
    final xml = buildOpml(podcasts);
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Exporter les abonnements',
      fileName: 'podavio.opml',
      bytes: Uint8List.fromList(utf8.encode(xml)),
      mimeType: 'text/x-opml',
    );
    if (saved != null && context.mounted) {
      showMessage(context, 'Abonnements exportés');
    }
  }
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
