import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/platform.dart';
import '../data/app_database.dart';
import '../data/feed_service.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'podcasts/podcast_feed_actions.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_tile.dart';
import 'widgets/messages.dart';

class PodcastPage extends ConsumerStatefulWidget {
  const PodcastPage({super.key, required this.podcastId});

  final int podcastId;

  @override
  ConsumerState<PodcastPage> createState() => _PodcastPageState();
}

class _PodcastPageState extends ConsumerState<PodcastPage> {
  @override
  Widget build(BuildContext context) {
    final podcast = ref.watch(podcastProvider(widget.podcastId));
    final query = EpisodeQuery(podcastId: widget.podcastId);
    final episodes = ref.watch(episodesProvider(query));
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
        return Scaffold(
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is! ScrollUpdateNotification &&
                  notification is! ScrollEndNotification) {
                return false;
              }
              if (notification.metrics.extentAfter < 800) {
                ref.read(episodesProvider(query).notifier).loadMore();
              }
              return false;
            },
            child: supportsPullToRefresh
                ? RefreshIndicator(
                    onRefresh: () => _refresh(context, ref, item.feedUrl),
                    child: _podcastScrollView(
                      item: item,
                      episodes: episodes,
                      pullToRefresh: true,
                    ),
                  )
                : _podcastScrollView(
                    item: item,
                    episodes: episodes,
                    pullToRefresh: false,
                  ),
          ),
        );
      },
    );
  }

  Widget _podcastScrollView({
    required Podcast item,
    required AsyncValue<EpisodeWindow> episodes,
    required bool pullToRefresh,
  }) {
    return CustomScrollView(
      physics: pullToRefresh ? const AlwaysScrollableScrollPhysics() : null,
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(item.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Actualiser ce flux',
              onPressed: () => _refresh(context, ref, item.feedUrl),
              icon: const Icon(Icons.refresh),
            ),
            if (item.subscribed)
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'preferred':
                      ref
                          .read(databaseProvider)
                          .setPodcastPreferred(
                            item.id,
                            preferred: !item.preferred,
                          );
                    case 'autoDownload':
                      ref
                          .read(databaseProvider)
                          .setPodcastAutoDownload(
                            item.id,
                            autoDownload: !item.autoDownload,
                          );
                    case 'keepUpdated':
                      ref
                          .read(databaseProvider)
                          .setPodcastKeepUpdated(
                            item.id,
                            keepUpdated: !item.keepUpdated,
                          );
                    case 'unsubscribe':
                      _unsubscribe(context, ref, item);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'preferred',
                    child: Text(
                      item.preferred
                          ? 'Retirer des préférés'
                          : 'Marquer comme préféré',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'autoDownload',
                    child: Text(
                      item.autoDownload
                          ? 'Désactiver les téléchargements automatiques'
                          : 'Activer les téléchargements automatiques',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'keepUpdated',
                    child: Text(
                      item.keepUpdated
                          ? 'Ne plus maintenir à jour'
                          : 'Maintenir à jour',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'unsubscribe',
                    child: Text('Se désabonner'),
                  ),
                ],
              )
            else
              IconButton(
                tooltip: 'Retirer l’aperçu',
                onPressed: () => _unsubscribe(context, ref, item),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: _PodcastHeader(
            podcast: item,
            onInfo: () => context.push(AppRoutes.podcastAbout(item.id)),
            onSettings: () => context.push(AppRoutes.podcastSettings(item.id)),
          ),
        ),
        ..._episodeSlivers(episodes),
      ],
    );
  }

  List<Widget> _episodeSlivers(AsyncValue<EpisodeWindow> episodes) {
    return episodes.when(
      loading: () => [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: 'Épisodes indisponibles',
            message: error.toString(),
          ),
        ),
      ],
      data: (window) => [
        if (window.entries.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              title: 'Aucun épisode',
              message: 'Ce flux ne contient pas encore d’épisode audio.',
            ),
          )
        else
          ..._episodeListSlivers(window),
      ],
    );
  }

  List<Widget> _episodeListSlivers(EpisodeWindow window) {
    return [
      SliverList.separated(
        itemCount: window.entries.length + (window.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= window.entries.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final entry = window.entries[index];
          return EpisodeTile(
            key: ValueKey(entry.episode.id),
            entry: entry,
            showPodcast: false,
          );
        },
      ),
    ];
  }

  Future<void> _refresh(
    BuildContext context,
    WidgetRef ref,
    String feedUrl,
  ) async {
    try {
      await ref.read(feedServiceProvider).refresh(feedUrl);
      if (context.mounted) showMessage(context, 'Flux actualisé');
    } catch (error) {
      if (context.mounted) showMessage(context, errorText(error));
    }
  }

  Future<void> _unsubscribe(
    BuildContext context,
    WidgetRef ref,
    Podcast item,
  ) async {
    final isPreview = !item.subscribed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPreview ? 'Retirer cet aperçu ?' : 'Se désabonner ?'),
        content: Text(
          isPreview
              ? '« ${item.title} » et ses épisodes seront retirés. Les fichiers téléchargés seront aussi supprimés.'
              : '« ${item.title} » et ses épisodes seront retirés de Podavio. Les fichiers téléchargés seront aussi supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isPreview ? 'Retirer' : 'Se désabonner'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final paths = await ref.read(databaseProvider).deletePodcast(item.id);
    await ref.read(downloadServiceProvider).deleteFiles(paths);
    if (context.mounted) Navigator.pop(context);
  }
}

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
            padding: const EdgeInsets.only(bottom: 32),
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
                    .setPodcastSkipBounds(
                      item.id,
                      skipIntroSeconds: seconds,
                    ),
              ),
              _SkipSecondsTile(
                title: 'Sauter la fin',
                seconds: item.skipOutroSeconds,
                activeLabel: (seconds) =>
                    'Les $seconds dernières secondes sont passées',
                onChanged: (seconds) => ref
                    .read(databaseProvider)
                    .setPodcastSkipBounds(
                      item.id,
                      skipOutroSeconds: seconds,
                    ),
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
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
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
  late final TextEditingController _username;
  late final TextEditingController _password;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.podcast.authUsername ?? '');
    _password = TextEditingController(text: widget.podcast.authPassword ?? '');
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final username = _username.text;
    final password = _password.text;
    try {
      await ref
          .read(databaseProvider)
          .setPodcastCredentials(
            widget.podcast.id,
            username: username,
            password: password,
          );
      if (!mounted) return;
      final cleared = username.trim().isEmpty && password.isEmpty;
      if (!cleared) {
        try {
          await ref.read(feedServiceProvider).refresh(widget.podcast.feedUrl);
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
    final theme = Theme.of(context);
    final stored =
        (widget.podcast.authUsername ?? '').isNotEmpty ||
        (widget.podcast.authPassword ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pour un flux privé qui demande un identifiant HTTP. '
            'La plupart des podcasts n’en ont pas besoin.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Identifiant',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: 'Mot de passe',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (stored)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          _username.clear();
                          _password.clear();
                          _save();
                        },
                  child: const Text('Effacer'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
    final selected = custom ?? _defaultPodcastSpeed;
    return ListTile(
      title: const Text('Vitesse de lecture'),
      subtitle: Text(
        custom == null
            ? 'Réglage général (${_formatPlaybackSpeed(globalSpeed)})'
            : '${_formatPlaybackSpeed(custom)} pour les épisodes de ce podcast',
      ),
      trailing: DropdownButton<double>(
        value: choices.any((preset) => (preset - selected).abs() < 0.05)
            ? choices.firstWhere((preset) => (preset - selected).abs() < 0.05)
            : selected,
        items: [
          const DropdownMenuItem(
            value: _defaultPodcastSpeed,
            child: Text('Défaut'),
          ),
          for (final choice in choices)
            DropdownMenuItem(
              value: choice,
              child: Text(_formatPlaybackSpeed(choice)),
            ),
        ],
        onChanged: (value) {
          if (value == null) return;
          onChanged(value == _defaultPodcastSpeed ? null : value);
        },
      ),
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
      trailing: DropdownButton<int>(
        value: seconds,
        items: [
          for (final choice in choices)
            DropdownMenuItem(
              value: choice,
              child: Text(choice == 0 ? 'Non' : '$choice s'),
            ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class PodcastAboutPage extends ConsumerWidget {
  const PodcastAboutPage({super.key, required this.podcastId});

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
        final description = plainText(item.description);
        final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(item.title, overflow: TextOverflow.ellipsis),
          ),
          body: ListView(
            children: [
              _PodcastHeader(podcast: item),
              _PodcastStatsSection(
                podcastId: item.id,
                subscribedAt: item.subscribedAt,
              ),
              if (description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Description', style: titleStyle),
                      const SizedBox(height: 8),
                      SelectableText(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PodcastHeader extends ConsumerWidget {
  const _PodcastHeader({required this.podcast, this.onInfo, this.onSettings});

  final Podcast podcast;
  final VoidCallback? onInfo;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PodcastCover(
            url: podcast.imageUrl,
            localPath: podcast.imagePath,
            httpHeaders: podcastAuthHeaders(
              username: podcast.authUsername,
              password: podcast.authPassword,
            ),
            size: 112,
            radius: 16,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  podcast.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (podcast.author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(podcast.author),
                ],
                if (podcast.refreshedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Actualisé le ${formatDate(podcast.refreshedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (onInfo != null || onSettings != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onInfo != null)
                          IconButton(
                            tooltip: 'À propos du podcast',
                            onPressed: onInfo,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.info_outline),
                          ),
                        if (onSettings != null)
                          IconButton(
                            tooltip: 'Paramètres du podcast',
                            onPressed: onSettings,
                            visualDensity: VisualDensity.compact,
                            icon: const SettingsIcon(),
                          ),
                      ],
                    ),
                  ),
                ],
                if (!podcast.subscribed) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => subscribeToFeed(
                      context,
                      ref,
                      podcast.feedUrl,
                      openPodcast: false,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('S’abonner'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastStatsSection extends ConsumerWidget {
  const _PodcastStatsSection({
    required this.podcastId,
    required this.subscribedAt,
  });

  final int podcastId;
  final DateTime subscribedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(podcastStatsProvider(podcastId));
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.primary,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistiques', style: titleStyle),
          const SizedBox(height: 12),
          stats.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Impossible de charger les statistiques.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            data: (value) => _PodcastStatsBody(
              stats: value,
              subscribedAt: subscribedAt,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastStatsBody extends StatelessWidget {
  const _PodcastStatsBody({
    required this.stats,
    required this.subscribedAt,
  });

  final PodcastStats stats;
  final DateTime subscribedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = stats.episodeCount == 0
        ? 0.0
        : (stats.completedCount / stats.episodeCount).clamp(0.0, 1.0);
    final progressLabel = '${(progress * 100).round()} %';

    final completed = stats.completedCount.toDouble();
    final inProgress = stats.inProgressCount.toDouble();
    final unread = stats.unreadCount.toDouble();
    final totalSlices = completed + inProgress + unread;
    final hasSlices = totalSlices > 0;

    final completedColor = scheme.primary;
    final inProgressColor = scheme.tertiary;
    final unreadColor = scheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: hasSlices ? 2 : 0,
                      centerSpaceRadius: 42,
                      sections: hasSlices
                          ? [
                              if (completed > 0)
                                PieChartSectionData(
                                  value: completed,
                                  color: completedColor,
                                  radius: 18,
                                  showTitle: false,
                                ),
                              if (inProgress > 0)
                                PieChartSectionData(
                                  value: inProgress,
                                  color: inProgressColor,
                                  radius: 18,
                                  showTitle: false,
                                ),
                              if (unread > 0)
                                PieChartSectionData(
                                  value: unread,
                                  color: unreadColor,
                                  radius: 18,
                                  showTitle: false,
                                ),
                            ]
                          : [
                              PieChartSectionData(
                                value: 1,
                                color: scheme.surfaceContainerHighest,
                                radius: 18,
                                showTitle: false,
                              ),
                            ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        progressLabel,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'terminés',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatListeningTime(stats.listenedSeconds),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'd’écoute cumulée',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LegendDot(
                    color: completedColor,
                    label: 'Terminés · ${stats.completedCount}',
                  ),
                  if (stats.inProgressCount > 0) ...[
                    const SizedBox(height: 4),
                    _LegendDot(
                      color: inProgressColor,
                      label: 'En cours · ${stats.inProgressCount}',
                    ),
                  ],
                  const SizedBox(height: 4),
                  _LegendDot(
                    color: unreadColor,
                    label: 'Non lus · ${stats.unreadCount}',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = _statColumnCount(constraints.maxWidth);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 112,
              ),
              itemBuilder: (context, index) {
                return switch (index) {
                  0 => _MetricTile(
                    icon: Icons.play_circle_outline,
                    label: 'Épisodes lancés',
                    value: '${stats.startedCount}',
                    hint: 'sur ${stats.episodeCount}',
                  ),
                  1 => _MetricTile(
                    icon: Icons.download_outlined,
                    label: 'Téléchargements',
                    value: stats.downloadCount == 0
                        ? 'Aucun'
                        : '${stats.downloadCount}',
                    hint: stats.downloadCount == 0
                        ? null
                        : formatBytes(stats.downloadBytes),
                  ),
                  2 => _MetricTile(
                    icon: Icons.schedule_outlined,
                    label: 'Rythme',
                    value: formatReleaseCadence(stats.releaseInterval),
                    hint: stats.lastPublishedAt == null
                        ? null
                        : 'Dernier · ${formatDate(stats.lastPublishedAt)}',
                  ),
                  _ => _MetricTile(
                    icon: Icons.upcoming_outlined,
                    label: 'Prochain épisode',
                    value: formatRelativeFuture(stats.nextEpisodeAt),
                    hint: stats.averageDurationSeconds == null
                        ? null
                        : '≈ ${formatListeningTime(stats.averageDurationSeconds!)}',
                  ),
                };
              },
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.library_music_outlined,
              label: 'Catalogue ${formatListeningTime(stats.totalDurationSeconds)}',
            ),
            if (stats.favoriteCount > 0)
              _InfoChip(
                icon: Icons.favorite_outline,
                label: '${stats.favoriteCount} favoris',
              ),
            _InfoChip(
              icon: Icons.event_available_outlined,
              label: 'Abonné ${formatDate(subscribedAt)}',
            ),
          ],
        ),
      ],
    );
  }
}

int _statColumnCount(double width) {
  const minTileWidth = 150.0;
  return (width / minTileWidth).floor().clamp(1, 4);
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 2),
              Text(
                hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

