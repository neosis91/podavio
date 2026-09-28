import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_search/podcast_search.dart' as remote;

import '../data/providers.dart';
import 'podcasts_page.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/messages.dart';

final discoverProvider =
    AsyncNotifierProvider<DiscoverNotifier, List<remote.Item>>(
      DiscoverNotifier.new,
    );

class DiscoverNotifier extends AsyncNotifier<List<remote.Item>> {
  var _query = '';

  @override
  Future<List<remote.Item>> build() => _load('');

  Future<void> search(String query) async {
    _query = query.trim();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(_query));
  }

  Future<List<remote.Item>> _load(String query) async {
    final service = ref.read(feedServiceProvider);
    final result = query.isEmpty
        ? await service.charts()
        : await service.search(query);
    if (!result.successful) {
      throw Exception(
        result.lastError.isEmpty ? 'La recherche a échoué.' : result.lastError,
      );
    }
    return result.items;
  }
}

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _controller = TextEditingController();
  final _subscribing = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(discoverProvider);
    final podcasts = ref.watch(podcastsProvider).value ?? const [];
    final subscribed = podcasts.map((podcast) => podcast.feedUrl).toSet();
    final searching = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Explorer')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Titre, auteur, sujet',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                          ref.read(discoverProvider.notifier).search('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) =>
                  ref.read(discoverProvider.notifier).search(value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                searching ? 'Résultats' : 'Tendances en France',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                title: 'Explorer est indisponible',
                message: errorText(error),
                action: FilledButton(
                  onPressed: () => ref
                      .read(discoverProvider.notifier)
                      .search(_controller.text),
                  child: const Text('Réessayer'),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'Aucun podcast trouvé',
                    message: 'Essayez un autre mot-clé.',
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final feedUrl = item.feedUrl?.trim();
                    final appleId = item.collectionId ?? item.trackId;
                    final subscribeKey = (feedUrl != null && feedUrl.isNotEmpty)
                        ? feedUrl
                        : (appleId == null ? null : 'apple:$appleId');
                    final title =
                        item.trackName ?? item.collectionName ?? 'Podcast';
                    final already =
                        feedUrl != null &&
                        feedUrl.isNotEmpty &&
                        subscribed.contains(feedUrl);
                    final busy =
                        subscribeKey != null &&
                        _subscribing.contains(subscribeKey);
                    return ListTile(
                      leading: PodcastCover(
                        url: item.bestArtworkUrl,
                        radius: 8,
                      ),
                      title: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if ((item.artistName ?? '').isNotEmpty)
                            item.artistName!,
                          if ((item.primaryGenreName ?? '').isNotEmpty)
                            item.primaryGenreName!,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              tooltip: already
                                  ? 'Déjà abonné'
                                  : subscribeKey == null
                                  ? 'Pas de flux RSS public'
                                  : 'S’abonner',
                              onPressed: subscribeKey == null
                                  ? null
                                  : () => _subscribe(item, subscribeKey),
                              icon: Icon(
                                already ? Icons.check_circle : Icons.add_circle,
                              ),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _subscribe(remote.Item item, String key) async {
    setState(() => _subscribing.add(key));
    try {
      final direct = item.feedUrl?.trim() ?? '';
      final url = direct.isNotEmpty
          ? direct
          : await ref
                .read(feedServiceProvider)
                .feedUrlForAppleShow(item.collectionId ?? item.trackId!);
      if (!mounted) return;
      await subscribeToFeed(context, ref, url);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _subscribing.remove(key));
    }
  }
}
