import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/cover_cache.dart';

/// Jaquettes toujours affichées dans un cadre carré, jamais étirées
/// (`BoxFit.cover` : recadrage éventuel, ratio d’origine conservé).
class PodcastCover extends StatelessWidget {
  const PodcastCover({
    super.key,
    this.url,
    this.localPath,
    this.size = 56,
    this.radius = 8,
  });

  final String? url;
  final String? localPath;

  /// Côté du carré. Si `null`, le widget prend le plus grand carré
  /// possible dans les contraintes du parent (`AspectRatio` 1:1).
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.podcasts, size: 36)),
    );
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final memPixels = ((size ?? 180) * ratio)
        .ceil()
        .clamp(64, CoverCache.maxMemPixels);

    final local = localPath?.trim();
    final imageUrl = url?.trim();
    final Widget image;
    if (local != null && local.isNotEmpty) {
      // Pas de existsSync ici : trop coûteux en liste. En cas d’échec,
      // errorBuilder bascule sur le réseau ou le placeholder.
      image = Image.file(
        File(local),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: memPixels,
        cacheHeight: memPixels,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          if (imageUrl == null || imageUrl.isEmpty) return placeholder;
          return CachedNetworkImage(
            imageUrl: imageUrl,
            cacheManager: CoverCache.manager,
            cacheKey: imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: memPixels,
            memCacheHeight: memPixels,
            filterQuality: FilterQuality.low,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
        },
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: imageUrl,
        cacheManager: CoverCache.manager,
        cacheKey: imageUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: memPixels,
        memCacheHeight: memPixels,
        filterQuality: FilterQuality.low,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      );
    } else {
      image = placeholder;
    }

    final square = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );

    if (size != null) {
      return SizedBox(width: size, height: size, child: square);
    }
    return AspectRatio(aspectRatio: 1, child: square);
  }
}
