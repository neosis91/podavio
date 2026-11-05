import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saf_util/saf_util.dart';

import '../../data/download_controller.dart';
import '../../data/download_service.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../settings/settings_controller.dart';
import '../router.dart';
import '../widgets/choice_dialog.dart';
import '../widgets/messages.dart';
import 'settings_section_title.dart';

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
          const SettingsSectionTitle('Dossiers'),
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
          const SettingsSectionTitle('Automatisation'),
          ListTile(
            title: Text(context.tr('Automatic download')),
            subtitle: Text(
              context.tr(
                'Choose which subscriptions download new episodes, and how many.',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.automaticDownloads),
          ),
          ListTile(
            title: Text(context.tr('Parallel downloads')),
            subtitle: Text(
              '${context.tr('How many files download at the same time, including ones started by hand.')}\n'
              '${context.tr(simultaneousDownloadsLabel(settings.simultaneousDownloads))}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickSimultaneousDownloads(context, ref),
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
          SettingsSectionTitle(context.tr('Automatic deletion')),
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
          const SettingsSectionTitle('Actions'),
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

Future<void> _pickSimultaneousDownloads(
  BuildContext context,
  WidgetRef ref,
) async {
  final current = ref.read(settingsProvider).simultaneousDownloads;
  final choice = await showRadioChoiceDialog<int>(
    context,
    title: 'Parallel downloads',
    selected: current,
    options: [
      for (final count in simultaneousDownloadChoices)
        (value: count, label: simultaneousDownloadsLabel(count)),
    ],
  );
  if (choice == null) return;
  await ref.read(settingsProvider.notifier).setSimultaneousDownloads(choice);
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
