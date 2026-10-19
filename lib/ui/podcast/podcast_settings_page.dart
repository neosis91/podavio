import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../data/feed_service.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../player/player_controller.dart';
import '../../settings/settings_controller.dart';
import '../podcasts/podcast_feed_actions.dart';
import '../widgets/choice_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/list_metrics.dart';
import '../widgets/messages.dart';

class PodcastSettingsPage extends ConsumerWidget {
  const PodcastSettingsPage({super.key, required this.podcastId});

  final int podcastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcast = ref.watch(podcastProvider(podcastId));
    return podcast.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          title: 'Podcast introuvable',
          message: error.toString(),
        ),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              title: 'Podcast introuvable',
              message: 'Cet abonnement n’est plus dans la bibliothèque.',
            ),
          );
        }
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paramètres du podcast',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: underChrome(context, const EdgeInsets.only(bottom: 32)),
            children: [
              const _PodcastSettingsSection('Lecture'),
              _PodcastSpeedTile(
                speed: item.playbackSpeed,
                globalSpeed: ref.watch(
                  settingsProvider.select((settings) => settings.speed),
                ),
                onChanged: (speed) => ref
                    .read(playerProvider.notifier)
                    .setPodcastSpeed(item.id, speed),
              ),
              _SkipSecondsTile(
                title: 'Sauter le début',
                seconds: item.skipIntroSeconds,
                activeLabel: (seconds) =>
                    'Les $seconds premières secondes ne sont pas lues',
                onChanged: (seconds) => ref
                    .read(databaseProvider)
                    .setPodcastSkipBounds(item.id, skipIntroSeconds: seconds),
              ),
              _SkipSecondsTile(
                title: 'Sauter la fin',
                seconds: item.skipOutroSeconds,
                activeLabel: (seconds) =>
                    'Les $seconds dernières secondes sont passées',
                onChanged: (seconds) => ref
                    .read(databaseProvider)
                    .setPodcastSkipBounds(item.id, skipOutroSeconds: seconds),
              ),
              _PodcastSettingsSection(context.tr('Notifications')),
              SwitchListTile(
                title: Text(context.tr('Notify about new episodes')),
                subtitle: Text(
                  context.tr(_podcastNotificationSubtitle(item, ref)),
                ),
                value: item.episodeNotification,
                onChanged: item.keepUpdated
                    ? (enabled) => ref
                          .read(databaseProvider)
                          .setPodcastEpisodeNotification(
                            item.id,
                            enabled: enabled,
                          )
                    : null,
              ),
              const _PodcastSettingsSection('Authentification'),
              _PodcastAuthSection(podcast: item),
            ],
          ),
        );
      },
    );
  }
}

const _skipSecondChoices = [0, 5, 10, 15, 20, 30, 45, 60, 90, 120];
const _podcastSpeedChoices = [0.8, 1.0, 1.2, 1.5, 1.8, 2.0, 2.5, 3.0];
const _defaultPodcastSpeed = -1.0;

String _podcastNotificationSubtitle(Podcast item, WidgetRef ref) {
  if (!item.keepUpdated) return 'The podcast is not kept up to date.';
  final enabled = ref.watch(
    settingsProvider.select((settings) => settings.notifyNewEpisodes),
  );
  if (!enabled) return 'Turn on New episodes in Notifications.';
  return 'Shows a notification when this podcast publishes an episode.';
}

String _formatPlaybackSpeed(double speed) {
  final text = speed == speed.roundToDouble()
      ? speed.toInt().toString()
      : speed.toString();
  return '$text×';
}

class _PodcastSettingsSection extends StatelessWidget {
  const _PodcastSettingsSection(this.label);

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

class _PodcastAuthSection extends ConsumerStatefulWidget {
  const _PodcastAuthSection({required this.podcast});

  final Podcast podcast;

  @override
  ConsumerState<_PodcastAuthSection> createState() =>
      _PodcastAuthSectionState();
}

class _PodcastAuthSectionState extends ConsumerState<_PodcastAuthSection> {
  var _saving = false;

  Future<void> _edit() async {
    if (_saving) return;
    final podcast = widget.podcast;
    final stored = _hasCredentials(podcast);
    final credentials = await askFeedCredentials(
      context,
      username: podcast.authUsername,
      password: podcast.authPassword,
      title: 'Identifiants',
      message:
          'Pour un flux privé qui demande un identifiant HTTP. '
          'La plupart des podcasts n’en ont pas besoin.',
      confirmLabel: 'Enregistrer',
      canClear: stored,
    );
    if (!mounted || credentials == null) return;
    setState(() => _saving = true);
    final username = credentials.username;
    final password = credentials.password;
    try {
      await ref
          .read(databaseProvider)
          .setPodcastCredentials(
            podcast.id,
            username: username,
            password: password,
          );
      if (!mounted) return;
      final cleared = username.trim().isEmpty && password.isEmpty;
      if (!cleared) {
        try {
          await ref.read(feedServiceProvider).refresh(podcast.feedUrl);
        } catch (error) {
          if (!mounted) return;
          showMessage(context, describeFeedError(error));
          return;
        }
      }
      if (!mounted) return;
      showMessage(
        context,
        cleared ? 'Authentification retirée' : 'Identifiants enregistrés',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stored = _hasCredentials(widget.podcast);
    final subtitle = _saving
        ? 'Enregistrement…'
        : stored
        ? 'Renseigné'
        : 'Aucun';
    return ListTile(
      title: const Text('Identifiants'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      enabled: !_saving,
      onTap: _saving ? null : _edit,
    );
  }
}

bool _hasCredentials(Podcast podcast) {
  return (podcast.authUsername ?? '').isNotEmpty ||
      (podcast.authPassword ?? '').isNotEmpty;
}

class _PodcastSpeedTile extends StatelessWidget {
  const _PodcastSpeedTile({
    required this.speed,
    required this.globalSpeed,
    required this.onChanged,
  });

  final double? speed;
  final double globalSpeed;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final custom = speed;
    final choices = [
      ..._podcastSpeedChoices,
      if (custom != null &&
          !_podcastSpeedChoices.any((preset) => (preset - custom).abs() < 0.05))
        custom,
    ]..sort();
    final rawSelected = custom ?? _defaultPodcastSpeed;
    var selected = rawSelected;
    for (final preset in choices) {
      if ((preset - rawSelected).abs() < 0.05) {
        selected = preset;
        break;
      }
    }
    return ListTile(
      title: const Text('Vitesse de lecture'),
      subtitle: Text(
        custom == null
            ? 'Réglage général (${_formatPlaybackSpeed(globalSpeed)})'
            : '${_formatPlaybackSpeed(custom)} pour les épisodes de ce podcast',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final choice = await showChoiceDialog<double>(
          context,
          title: 'Vitesse de lecture',
          selected: selected,
          options: [
            (value: _defaultPodcastSpeed, label: 'Défaut'),
            for (final preset in choices)
              (value: preset, label: _formatPlaybackSpeed(preset)),
          ],
        );
        if (choice == null) return;
        onChanged(choice == _defaultPodcastSpeed ? null : choice);
      },
    );
  }
}

class _SkipSecondsTile extends StatelessWidget {
  const _SkipSecondsTile({
    required this.title,
    required this.seconds,
    required this.activeLabel,
    required this.onChanged,
  });

  final String title;
  final int seconds;
  final String Function(int seconds) activeLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final choices = [
      ..._skipSecondChoices,
      if (!_skipSecondChoices.contains(seconds)) seconds,
    ]..sort();
    return ListTile(
      title: Text(title),
      subtitle: Text(seconds == 0 ? 'Désactivé' : activeLabel(seconds)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final choice = await showChoiceDialog<int>(
          context,
          title: title,
          selected: seconds,
          options: [
            for (final choice in choices)
              (value: choice, label: choice == 0 ? 'Non' : '$choice s'),
          ],
        );
        if (choice != null) onChanged(choice);
      },
    );
  }
}
