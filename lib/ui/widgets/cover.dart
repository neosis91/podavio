import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PodcastCover extends StatelessWidget {
  const PodcastCover({super.key, this.url, this.size = 56, this.radius = 8});

  final String? url;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.podcasts, size: 36)),
    );
    final imageUrl = url;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final cachePixels = ((size ?? 180) * ratio).ceil().clamp(64, 800);
    final image = imageUrl == null || imageUrl.isEmpty
        ? placeholder
        : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: cachePixels,
            memCacheHeight: cachePixels,
            maxWidthDiskCache: cachePixels,
            maxHeightDiskCache: cachePixels,
            filterQuality: FilterQuality.low,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
    final side = size;
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: side == null ? SizedBox.expand(child: image) : image,
    );
    if (side == null) return clipped;
    return SizedBox(width: side, height: side, child: clipped);
  }
}
