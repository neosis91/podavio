import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/build_info.dart';
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
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: PodavioLogo()),
          const SizedBox(height: 16),
          Text(
            'Lecteur de podcasts pour Android, iOS, Windows, macOS et Linux. '
            'Vos abonnements restent des flux RSS, '
            'sans compte obligatoire et sans publicité.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) {
              final packaged = snapshot.data?.version;
              final version = (BuildInfo.version.isNotEmpty)
                  ? BuildInfo.version
                  : packaged;
              if (version == null || version.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  Text(
                    'Version $version',
                    textAlign: TextAlign.center,
                    style: muted,
                  ),
                  if (BuildInfo.hasGitlabId) ...[
                    const SizedBox(height: 4),
                    Text(
                      'GitLab #${BuildInfo.gitlabPipelineId}',
                      textAlign: TextAlign.center,
                      style: muted,
                    ),
                  ],
                ],
              );
            },
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
    return Scaffold(
      appBar: AppBar(title: const Text('Préférences')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Actualiser tous les abonnements'),
            onTap: () => refreshSubscriptions(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Importer un fichier OPML'),
            subtitle: const Text(
              'Abonnements exportés depuis une autre application',
            ),
            onTap: () => _importOpml(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Exporter les abonnements'),
            subtitle: const Text('Fichier OPML'),
            onTap: () => _exportOpml(context, ref),
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
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos'),
            onTap: () => context.push(AppRoutes.about),
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

  Future<void> _importOpml(BuildContext context, WidgetRef ref) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Importer un OPML',
      type: FileType.custom,
      allowedExtensions: ['opml', 'xml'],
    );
    if (file == null) return;
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Impossible de lire ce fichier');
      }
      return;
    }
    List<String> urls;
    try {
      urls = parseOpml(utf8.decode(bytes));
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Ce fichier OPML est illisible');
      }
      return;
    }
    if (urls.isEmpty) {
      if (context.mounted) {
        showMessage(context, 'Aucun flux trouvé dans ce fichier');
      }
      return;
    }
    if (!context.mounted) return;
    var done = 0;
    var failed = 0;
    final progress = ValueNotifier(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Importation'),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (context, value, _) => Text('$value / ${urls.length} flux'),
        ),
      ),
    );
    final service = ref.read(feedServiceProvider);
    for (final url in urls) {
      try {
        await service.subscribe(url);
      } catch (_) {
        failed++;
      }
      done++;
      progress.value = done;
    }
    progress.dispose();
    if (!context.mounted) return;
    Navigator.pop(context);
    showMessage(
      context,
      failed == 0
          ? '$done abonnements importés'
          : '${done - failed} importés, $failed en échec',
    );
  }
}
