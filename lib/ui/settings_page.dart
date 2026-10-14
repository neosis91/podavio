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
import 'widgets/brand.dart';
import 'widgets/choice_dialog.dart';
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
        ],
      ),
    );
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

class PlaybackPage extends ConsumerWidget {
  const PlaybackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Lecture')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _SectionTitle('Commandes'),
          ListTile(
            title: const Text('Retour rapide'),
            subtitle: Text('${settings.skipBackSeconds} secondes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickIntSetting(
              context,
              title: 'Retour rapide',
              selected: settings.skipBackSeconds,
              values: const [5, 10, 15, 30],
              label: (seconds) => '$seconds s',
              onChanged: notifier.setSkipBack,
            ),
          ),
          ListTile(
            title: const Text('Avance rapide'),
            subtitle: Text('${settings.skipForwardSeconds} secondes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickIntSetting(
              context,
              title: 'Avance rapide',
              selected: settings.skipForwardSeconds,
              values: const [10, 15, 30, 45, 60],
              label: (seconds) => '$seconds s',
              onChanged: notifier.setSkipForward,
            ),
          ),
          ListTile(
            title: const Text('Hors de l’application'),
            subtitle: Text(_outsideAppSubtitle(settings)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickOutsideApp(context, ref),
          ),
          const _SectionTitle('Lecteur'),
          SwitchListTile(
            title: const Text('Temps restant'),
            subtitle: const Text(
              'Affiche le temps restant à droite de la barre de lecture',
            ),
            value: settings.showRemainingTime,
            onChanged: notifier.setShowRemainingTime,
          ),
          SwitchListTile(
            title: const Text('Temps selon la vitesse'),
            subtitle: const Text(
              'Ajuste la position et la durée affichées selon la vitesse de lecture',
            ),
            value: settings.timeRespectsSpeed,
            onChanged: notifier.setTimeRespectsSpeed,
          ),
          SwitchListTile(
            title: const Text('Écran allumé'),
            subtitle: const Text(
              'Empêche la mise en veille pendant la lecture',
            ),
            value: settings.keepScreenOn,
            onChanged: notifier.setKeepScreenOn,
          ),
          ListTile(
            leading: const Icon(Icons.keyboard_alt_outlined),
            title: const Text('Aide du lecteur'),
            subtitle: const Text(
              'Gestes couverture, Espace, J, L, volume… — aussi via ?',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showPlayerKeyboardHelp(context),
          ),
          const _SectionTitle('Mini player'),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Gestion des boutons'),
            subtitle: Text(settings.miniPlayerButtons.summary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showMiniPlayerButtonsSheet(context, ref),
          ),
          const _SectionTitle('Épisodes'),
          SwitchListTile(
            title: const Text('Jaquette du podcast'),
            subtitle: const Text(
              'Affiche la couverture du podcast plutôt que celle de l’épisode',
            ),
            value: settings.preferPodcastCover,
            onChanged: notifier.setPreferPodcastCover,
          ),
          const ListTile(
            title: Text('Densité des listes'),
            subtitle: Text('Espace entre les lignes des listes d’épisodes'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<EpisodeListDensity>(
              segments: [
                for (final density in EpisodeListDensity.values)
                  ButtonSegment(value: density, label: Text(density.label)),
              ],
              selected: {settings.episodeListDensity},
              onSelectionChanged: (selection) =>
                  notifier.setEpisodeListDensity(selection.first),
            ),
          ),
          const _SectionTitle('Actualisation'),
          ListTile(
            title: const Text('Intervalle d’actualisation'),
            subtitle: Text(
              settings.refreshIntervalMinutes == 0
                  ? 'Pas de limite entre deux actualisations'
                  : 'Minimum ${settings.refreshIntervalMinutes} min entre deux actualisations',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickIntSetting(
              context,
              title: 'Intervalle d’actualisation',
              selected: settings.refreshIntervalMinutes,
              values: const [0, 1, 5, 15, 30, 60],
              label: _refreshIntervalLabel,
              onChanged: notifier.setRefreshIntervalMinutes,
            ),
          ),
          const _SectionTitle('Téléchargements'),
          SwitchListTile(
            title: const Text('Ajouter à la playlist'),
            subtitle: const Text(
              'Place l’épisode dans la playlist dès la fin du téléchargement',
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

String _outsideAppSubtitle(AppSettings settings) {
  return switch (settings.outsideApp) {
    OutsideAppControl.skip =>
      '${settings.skipBackSeconds} s en arrière, '
          '${settings.skipForwardSeconds} s en avant',
    OutsideAppControl.episode => OutsideAppControl.episode.label,
  };
}

Future<void> _pickOutsideApp(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  final choice = await showChoiceDialog<OutsideAppControl>(
    context,
    title: 'Hors de l’application',
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
    0 => 'Aucune',
    60 => '1 h',
    _ => '$minutes min',
  };
}

Future<void> _showMiniPlayerButtonsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
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
              'Boutons du mini player',
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
            message: 'Déplacer',
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
              title: Text(_miniPlayerButtonTitle(id)),
              subtitle: switch (id) {
                'play' => const Text('Toujours affiché'),
                'nextEpisode' => const Text('Dans la file d’attente'),
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
    'play' => 'Lecture / pause',
    'favorite' => 'Favoris',
    'skipBack' => 'Retour rapide',
    'skipForward' => 'Avance rapide',
    'nextEpisode' => 'Épisode suivant',
    'close' => 'Fermer le lecteur',
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
