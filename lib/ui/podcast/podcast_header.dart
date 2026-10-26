import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/feed_service.dart';
import '../podcasts/podcast_feed_actions.dart';
import '../widgets/brand.dart';
import '../widgets/cover.dart';

class PodcastHeader extends ConsumerWidget {
  const PodcastHeader({
    super.key,
    required this.podcast,
    this.onInfo,
    this.onSettings,
  });

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
            label: podcast.title,
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
