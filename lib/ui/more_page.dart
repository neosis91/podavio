import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/build_info.dart';
import '../data/feed_refresh_controller.dart';
import '../data/opml.dart';
import '../data/providers.dart';
import 'episodes_page.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/messages.dart';

final _packageInfo = PackageInfo.fromPlatform();

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
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
                title: const Text('Version'),
                subtitle: Text(label),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Lecteur de podcasts pour Android, iOS, Windows, macOS et Linux.',
              style: muted,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Vos abonnements restent des flux RSS, '
              'sans compte obligatoire et sans publicité.',
              style: muted,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Licences'),
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

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refreshing = ref.watch(
      feedRefreshProvider.select((s) => s.isRunning),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Préférences')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.refresh,
              color: refreshing ? Theme.of(context).disabledColor : null,
            ),
            title: Text(
              refreshing
                  ? 'Actualisation en cours…'
                  : 'Actualiser tous les abonnements',
            ),
            enabled: !refreshing,
            onTap: refreshing ? null : () => refreshSubscriptions(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Interface utilisateur'),
            onTap: () => context.push(AppRoutes.appearance),
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Lecture'),
            onTap: () => context.push(AppRoutes.playback),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Gestion des téléchargements'),
            onTap: () => context.push(AppRoutes.downloadSettings),
          ),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Statistiques'),
            onTap: () => context.push(AppRoutes.stats),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Sauvegarde et restauration'),
            onTap: () => context.push(AppRoutes.backupRestore),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde et restauration')),
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
