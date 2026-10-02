import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/discover_hit.dart';
import '../../data/providers.dart';
import '../podcasts_page.dart';
import '../widgets/messages.dart';

/// Open / subscribe sur un [DiscoverHit] (Explorer + Suggestions).
mixin DiscoverHitActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final busyHits = <String>{};

  Future<String?> resolveFeedUrl(DiscoverHit hit) async {
    final direct = hit.feedUrl.trim();
    if (direct.isNotEmpty) return direct;
    final appleId = hit.appleId;
    if (appleId == null) return null;
    return ref.read(feedServiceProvider).feedUrlForAppleShow(appleId);
  }

  Future<void> openHit(DiscoverHit hit, String key) async {
    setState(() => busyHits.add(key));
    try {
      final url = await resolveFeedUrl(hit);
      if (!mounted) return;
      if (url == null) {
        showMessage(context, 'Pas de flux RSS public');
        return;
      }
      await openPodcastFromFeedUrl(context, ref, url);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => busyHits.remove(key));
    }
  }

  Future<void> subscribeHit(DiscoverHit hit, String key) async {
    setState(() => busyHits.add(key));
    try {
      final url = await resolveFeedUrl(hit);
      if (!mounted) return;
      if (url == null) {
        showMessage(context, 'Pas de flux RSS public');
        return;
      }
      await subscribeToFeed(context, ref, url);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => busyHits.remove(key));
    }
  }
}
