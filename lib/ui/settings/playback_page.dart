import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../settings/settings_controller.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/brand.dart';
import '../widgets/choice_dialog.dart';
import '../widgets/list_metrics.dart';
import '../widgets/player_keyboard_shortcuts.dart';
import 'settings_section_title.dart';

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
          SettingsSectionTitle(context.tr('Controls')),
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
          SettingsSectionTitle(context.tr('Player')),
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
          SettingsSectionTitle(context.tr('Mini player')),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(context.tr('Button layout')),
            subtitle: Text(settings.miniPlayerButtons.summary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showMiniPlayerButtonsSheet(context, ref),
          ),
          SettingsSectionTitle(context.tr('Episodes')),
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
          SettingsSectionTitle(context.tr('Refresh')),
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
          SettingsSectionTitle(context.tr('Downloads')),
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
