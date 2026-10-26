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
    this.httpHeaders,
    this.size = 56,
    this.radius = 8,
    this.expand = false,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final String? localPath;
  final Map<String, String>? httpHeaders;

  /// Côté du carré. Si `null`, le widget prend le plus grand carré
  /// possible dans les contraintes du parent (`AspectRatio` 1:1).
  final double? size;
  final double radius;

  /// Remplit le parent au lieu du carré [size].
  final bool expand;

  /// `cover` pour les listes, `contain` pour voir toute la jaquette.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.podcasts, size: 36)),
    );
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final logical = expand
        ? MediaQuery.sizeOf(context).shortestSide
        : (size ?? 180);
    final maxPixels = expand
        ? CoverCache.maxHeroMemPixels
        : CoverCache.maxMemPixels;
    final memPixels = (logical * ratio).ceil().clamp(64, maxPixels);
    final quality = expand || (size ?? 0) >= 160
        ? FilterQuality.medium
        : FilterQuality.low;

    final local = localPath?.trim();
    final imageUrl = url?.trim();
    final Widget image;
    if (local != null && local.isNotEmpty) {
      // Pas de existsSync ici : trop coûteux en liste. En cas d’échec,
      // errorBuilder bascule sur le réseau ou le placeholder.
      image = Image.file(
        File(local),
        fit: fit,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: memPixels,
        cacheHeight: memPixels,
        filterQuality: quality,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          if (imageUrl == null || imageUrl.isEmpty) return placeholder;
          return CachedNetworkImage(
            imageUrl: imageUrl,
            httpHeaders: httpHeaders,
            cacheManager: CoverCache.manager,
            cacheKey: imageUrl,
            fit: fit,
            alignment: Alignment.center,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: memPixels,
            memCacheHeight: memPixels,
            filterQuality: quality,
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
        httpHeaders: httpHeaders,
        cacheManager: CoverCache.manager,
        cacheKey: imageUrl,
        fit: fit,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: memPixels,
        memCacheHeight: memPixels,
        filterQuality: quality,
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

    if (expand) return square;
    if (size != null) {
      return SizedBox(width: size, height: size, child: square);
    }
    return AspectRatio(aspectRatio: 1, child: square);
  }
}
