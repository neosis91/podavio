import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/discover_hit.dart';
import '../../data/discover_providers.dart';
import '../../data/providers.dart';
import '../podcasts/podcast_feed_actions.dart';
import 'cover.dart';
import 'messages.dart';

/// Ligne de podcast dans une catégorie (style liste type Podcast Addict).
class DiscoverCategoryTile extends ConsumerStatefulWidget {
  const DiscoverCategoryTile({
    super.key,
    required this.rank,
    required this.hit,
  });

  final int rank;
  final DiscoverHit hit;

  @override
  ConsumerState<DiscoverCategoryTile> createState() =>
      _DiscoverCategoryTileState();
}

class _DiscoverCategoryTileState extends ConsumerState<DiscoverCategoryTile> {
  var _busy = false;

  DiscoverHit get hit => widget.hit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final authorColor = scheme.primary;
    final subscribed = ref.watch(
      podcastsProvider.select(
        (async) => isSubscribedDiscoverHit(
          hit,
          subscribedFeedUrls(async.asData?.value ?? const []),
        ),
      ),
    );

    final episodeLine = _episodeLine();
    final lastLine = hit.lastEpisodeAt == null
        ? null
        : 'Dernier épisode : ${formatListDate(hit.lastEpisodeAt)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : _open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.rank}. ${hit.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PodcastCover(url: hit.imageUrl, size: 64, radius: 6),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hit.author.isNotEmpty)
                          Text(
                            hit.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: authorColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (episodeLine != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.volume_up_outlined,
                                size: 14,
                                color: muted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  episodeLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (lastLine != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            lastLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _SubscribeCheck(
                    busy: _busy,
                    subscribed: subscribed,
                    onPressed: _busy ? null : _subscribe,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _episodeLine() {
    final count = hit.episodeCount;
    if (count == null || count <= 0) return null;
    final countLabel = count == 1 ? '1 épisode' : '$count épisodes';
    final minutes = hit.averageDurationMinutes;
    if (minutes == null || minutes <= 0) return countLabel;
    return '$countLabel ($minutes mins)';
  }

  Future<String?> _resolveUrl() async {
    final direct = hit.feedUrl.trim();
    if (direct.isNotEmpty) return direct;
    final appleId = hit.appleId;
    if (appleId == null) return null;
    return ref.read(feedServiceProvider).feedUrlForAppleShow(appleId);
  }

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final url = await _resolveUrl();
      if (!mounted) return;
      if (url == null) {
        showMessage(context, 'Pas de flux RSS public');
        return;
      }
      await openPodcastFromFeedUrl(context, ref, url);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      final url = await _resolveUrl();
      if (!mounted) return;
      if (url == null) {
        showMessage(context, 'Pas de flux RSS public');
        return;
      }
      await subscribeToFeed(context, ref, url);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SubscribeCheck extends StatelessWidget {
  const _SubscribeCheck({
    required this.busy,
    required this.subscribed,
    required this.onPressed,
  });

  final bool busy;
  final bool subscribed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (busy) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: subscribed ? 'Abonné' : 'S’abonner',
      onPressed: subscribed ? null : onPressed,
      icon: Icon(
        Icons.check_circle,
        size: 28,
        color: subscribed
            ? const Color(0xFF2E895D)
            : scheme.outline.withValues(alpha: 0.55),
      ),
    );
  }
}
