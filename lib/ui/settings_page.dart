import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf_util/saf_util.dart';

import '../core/theme.dart';
import '../core/wallpaper_colors.dart';
import '../data/download_controller.dart';
import '../data/download_service.dart';
import '../data/providers.dart';
import '../settings/settings_controller.dart';
import 'nav_catalog.dart';
import 'widgets/brand.dart';
import 'widgets/messages.dart';
import 'widgets/player_keyboard_shortcuts.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final wallpaperOption = defaultTargetPlatform != TargetPlatform.iOS;
    return Scaffold(
      appBar: AppBar(title: const Text('Interface utilisateur')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const ListTile(title: Text('Apparence')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Système')),
                ButtonSegment(value: ThemeMode.light, label: Text('Clair')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Sombre')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) =>
                  notifier.setThemeMode(selection.first),
            ),
          ),
          SwitchListTile(
            title: const Text('Noir pur'),
            subtitle: const Text('Fond noir en mode sombre'),
            value: settings.pureBlack,
            onChanged: notifier.setPureBlack,
          ),
          if (wallpaperOption)
            SwitchListTile(
              title: const Text('Fond d’écran'),
              subtitle: Text(_wallpaperSubtitle(ref)),
              value: settings.wallpaperColors,
              onChanged: notifier.setWallpaperColors,
            ),
          if (!wallpaperOption || !settings.wallpaperColors) ...[
            const SizedBox(height: 8),
            const ListTile(title: Text('Couleur')),
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
          const _SectionTitle('Préférences du volet'),
          ListTile(
            leading: const Icon(Icons.reorder),
            title: const Text('Ordre des pages'),
            subtitle: const Text('L’ordre utilisé par le menu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPanelOrder(context),
          ),
        ],
      ),
    );
  }
}

void _showPanelOrder(BuildContext context) {
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (context) => const _PanelOrderDialog(),
  );
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

class _PanelOrderDialog extends ConsumerStatefulWidget {
  const _PanelOrderDialog();

  @override
  ConsumerState<_PanelOrderDialog> createState() => _PanelOrderDialogState();
}

class _PanelOrderDialogState extends ConsumerState<_PanelOrderDialog> {
  late final List<String> _order;

  @override
  void initState() {
    super.initState();
    _order = List<String>.of(ref.read(settingsProvider).navOrder);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final availableWidth = size.width - 80;
    final dialogWidth = availableWidth < 420 ? availableWidth : 420.0;
    final dialogHeight = size.height - 96 > 640 ? 640.0 : size.height - 96;
    return Dialog(
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'Ordre des pages',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Les pages s’affichent dans cet ordre. Celles qui ne tiennent pas restent dans Plus.',
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _order.length,
                onReorderItem: _reorder,
                itemBuilder: (context, index) {
                  final page = navPageByPath(_order[index])!;
                  return ListTile(
                    key: ValueKey(page.path),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Tooltip(
                        message: 'Déplacer',
                        child: SizedBox(
                          width: 40,
                          height: 48,
                          child: Center(child: DragIndicatorIcon()),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        page.buildIcon(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(page.label)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final path = _order.removeAt(oldIndex);
      _order.insert(newIndex, path);
    });
    ref.read(settingsProvider.notifier).setNavOrder(_order);
  }
}

String _wallpaperSubtitle(WidgetRef ref) {
  final palette = ref.watch(wallpaperPaletteProvider);
  final enabled = ref.watch(
    settingsProvider.select((settings) => settings.wallpaperColors),
  );
  if (!enabled) {
    return 'Adapter les couleurs à celles du fond d’écran';
  }
  if (palette.isLoading) return 'Lecture du fond d’écran…';
  if (palette.hasError || palette.asData?.value == null) {
    return 'Le fond d’écran n’a pas pu être lu';
  }
  return 'Les couleurs suivent le fond d’écran';
}

class DownloadSettingsPage extends ConsumerWidget {
  const DownloadSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final directory = settings.downloadDirectory;
    final fallback = ref.watch(defaultDownloadDirectoryProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des téléchargements')),
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
            title: const Text('Retirer de la playlist'),
            subtitle: const Text(
              'Enlève l’épisode de la playlist quand son téléchargement est supprimé',
            ),
            value: settings.dequeueDeletedDownloads,
            onChanged: ref
                .read(settingsProvider.notifier)
                .setDequeueDeletedDownloads,
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

Future<void> _deleteAllDownloads(
  BuildContext context,
  WidgetRef ref,
) async {
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

class PlaybackPage extends ConsumerWidget {
  const PlaybackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Lecture')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Retour rapide'),
            subtitle: Text('${settings.skipBackSeconds} secondes'),
            trailing: DropdownButton<int>(
              value: settings.skipBackSeconds,
              items: const [5, 10, 15, 30]
                  .map(
                    (seconds) => DropdownMenuItem(
                      value: seconds,
                      child: Text('$seconds s'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) notifier.setSkipBack(value);
              },
            ),
          ),
          ListTile(
            title: const Text('Avance rapide'),
            subtitle: Text('${settings.skipForwardSeconds} secondes'),
            trailing: DropdownButton<int>(
              value: settings.skipForwardSeconds,
              items: const [10, 15, 30, 45, 60]
                  .map(
                    (seconds) => DropdownMenuItem(
                      value: seconds,
                      child: Text('$seconds s'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) notifier.setSkipForward(value);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Temps restant'),
            subtitle: const Text(
              'Affiche le temps restant à droite de la barre de lecture',
            ),
            value: settings.showRemainingTime,
            onChanged: notifier.setShowRemainingTime,
          ),
          SwitchListTile(
            title: const Text('Écran allumé'),
            subtitle: const Text(
              'Empêche la mise en veille pendant la lecture',
            ),
            value: settings.keepScreenOn,
            onChanged: notifier.setKeepScreenOn,
          ),
          SwitchListTile(
            title: const Text('Ajouter à la playlist'),
            subtitle: const Text(
              'Place l’épisode dans la playlist dès la fin du téléchargement',
            ),
            value: settings.enqueueDownloads,
            onChanged: notifier.setEnqueueDownloads,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.keyboard_alt_outlined),
            title: const Text('Aide du lecteur'),
            subtitle: const Text(
              'Gestes couverture, Espace, J, L, volume… — aussi via ?',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showPlayerKeyboardHelp(context),
          ),
        ],
      ),
    );
  }
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
              accent.label,
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
