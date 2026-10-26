import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cover_cache.dart';
import '../../core/theme.dart';
import '../../settings/settings_controller.dart';
import 'brand.dart';

/// Jaquettes toujours affichées dans un cadre carré, jamais étirées
/// (`BoxFit.cover` : recadrage éventuel, ratio d’origine conservé).
class PodcastCover extends ConsumerWidget {
  const PodcastCover({
    super.key,
    this.url,
    this.localPath,
    this.httpHeaders,
    this.label,
    this.colorKey,
    this.size = 56,
    this.radius = 8,
    this.expand = false,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final String? localPath;
  final Map<String, String>? httpHeaders;

  /// Nom affiché à la place d’une jaquette absente, en mode éco.
  final String? label;

  /// Chaîne dont est tirée la couleur. Par défaut, [label].
  /// Pour un épisode, passer le nom du podcast.
  final String? colorKey;

  /// Côté du carré. Si `null`, le widget prend le plus grand carré
  /// possible dans les contraintes du parent (`AspectRatio` 1:1).
  final double? size;
  final double radius;

  /// Remplit le parent au lieu du carré [size].
  final bool expand;

  /// `cover` pour les listes, `contain` pour voir toute la jaquette.
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eco = ref.watch(
      settingsProvider.select((settings) => settings.ecoMode),
    );
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
    final name = label?.trim() ?? '';
    final key = colorKey?.trim() ?? '';
    final seed = key.isNotEmpty
        ? key
        : (name.isNotEmpty
              ? name
              : (imageUrl != null && imageUrl.isNotEmpty
                    ? imageUrl
                    : (local ?? '')));
    final Widget image;
    if (local != null && local.isNotEmpty) {
      // Pas de existsSync ici : trop coûteux en liste. En cas d’échec,
      // errorBuilder bascule sur le réseau, le cache, ou le carré.
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
        frameBuilder: (context, child, frame, _) {
          if (!eco || child is EcoNameCover || child is _CachedOrNamedCover) {
            return child;
          }
          return _cornerLeaf(child);
        },
        errorBuilder: (_, _, _) {
          if (eco) {
            return _CachedOrNamedCover(
              url: imageUrl,
              label: name,
              seed: seed,
              side: size,
              fit: fit,
              memPixels: memPixels,
              quality: quality,
            );
          }
          if (imageUrl == null || imageUrl.isEmpty) return placeholder;
          return _networkImage(
            imageUrl: imageUrl,
            fit: fit,
            memPixels: memPixels,
            quality: quality,
            placeholder: placeholder,
          );
        },
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      image = eco
          ? _CachedOrNamedCover(
              url: imageUrl,
              label: name,
              seed: seed,
              side: size,
              fit: fit,
              memPixels: memPixels,
              quality: quality,
            )
          : _networkImage(
              imageUrl: imageUrl,
              fit: fit,
              memPixels: memPixels,
              quality: quality,
              placeholder: placeholder,
            );
    } else {
      image = eco ? EcoNameCover(label: name, seed: seed) : placeholder;
    }

    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );

    if (expand) return framed;
    if (size != null) {
      return SizedBox(width: size, height: size, child: framed);
    }
    return AspectRatio(aspectRatio: 1, child: framed    );
  }

  Widget _cornerLeaf(Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: _leafInset(size),
          bottom: _leafInset(size),
          child: IgnorePointer(child: _EcoLeaf(side: size)),
        ),
      ],
    );
  }

  Widget _networkImage({
    required String imageUrl,
    required BoxFit fit,
    required int memPixels,
    required FilterQuality quality,
    required Widget placeholder,
  }) {
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
  }
}

double _leafInset(double? side) => side != null && side < 48 ? 2 : 6;

class _EcoLeaf extends StatelessWidget {
  const _EcoLeaf({required this.side});

  final double? side;

  @override
  Widget build(BuildContext context) {
    final mark = side != null && side! < 48 ? 11.0 : 16.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: EcoIcon(size: mark, color: podavioGreen),
      ),
    );
  }
}

/// Carré du thème. Bord, texte et feuille prennent la couleur de [seed].
class EcoNameCover extends StatelessWidget {
  const EcoNameCover({super.key, required this.label, required this.seed});

  final String label;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final accent = ecoAccentColor(seed);
    final surface = Theme.of(context).colorScheme.surface;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final finite = side.isFinite && side > 0 ? side : 56.0;
        final border = _ecoBorderWidth(finite);
        final compact = finite <= 80;
        final square = DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: accent, width: border),
          ),
          child: ColoredBox(
            color: surface,
            child: compact
                ? Padding(
                    padding: EdgeInsets.all(border),
                    child: Center(
                      child: EcoIcon(
                        size: (finite - border * 2) * 0.62,
                        color: accent,
                      ),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.all(border + 8),
                    child: Center(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: (finite * 0.16).clamp(12.0, 22.0),
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
          ),
        );
        if (compact) return square;
        return Stack(
          fit: StackFit.expand,
          children: [
            square,
            Positioned(
              left: 8,
              bottom: 8,
              child: IgnorePointer(child: _EcoLeaf(side: finite)),
            ),
          ],
        );
      },
    );
  }
}

/// Fichier déjà dans le cache des jaquettes, sinon le carré au nom.
class _CachedOrNamedCover extends StatefulWidget {
  const _CachedOrNamedCover({
    required this.url,
    required this.label,
    required this.seed,
    required this.side,
    required this.fit,
    required this.memPixels,
    required this.quality,
  });

  final String? url;
  final String label;
  final String seed;
  final double? side;
  final BoxFit fit;
  final int memPixels;
  final FilterQuality quality;

  @override
  State<_CachedOrNamedCover> createState() => _CachedOrNamedCoverState();
}

class _CachedOrNamedCoverState extends State<_CachedOrNamedCover> {
  static final _hits = <String, File>{};

  File? _file;

  @override
  void initState() {
    super.initState();
    final url = widget.url;
    if (url == null || url.isEmpty) return;
    final known = _hits[url];
    if (known != null) {
      _file = known;
      return;
    }
    _lookup(url);
  }

  @override
  void didUpdateWidget(_CachedOrNamedCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    final url = widget.url;
    _file = null;
    if (url == null || url.isEmpty) return;
    final known = _hits[url];
    if (known != null) {
      _file = known;
      return;
    }
    _lookup(url);
  }

  Future<void> _lookup(String url) async {
    try {
      final info = await CoverCache.manager.getFileFromCache(url);
      final file = info?.file;
      if (file != null) _hits[url] = file;
      if (!mounted || widget.url != url) return;
      setState(() => _file = file);
    } catch (_) {
      if (!mounted || widget.url != url) return;
      setState(() => _file = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) {
      return EcoNameCover(label: widget.label, seed: widget.seed);
    }
    return Image.file(
      file,
      fit: widget.fit,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: widget.memPixels,
      cacheHeight: widget.memPixels,
      filterQuality: widget.quality,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          EcoNameCover(label: widget.label, seed: widget.seed),
      frameBuilder: (context, child, frame, _) {
        if (child is EcoNameCover) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              left: _leafInset(widget.side),
              bottom: _leafInset(widget.side),
              child: IgnorePointer(child: _EcoLeaf(side: widget.side)),
            ),
          ],
        );
      },
    );
  }
}

double _ecoBorderWidth(double side) => (side * 0.085).clamp(3.0, 7.0);

/// Couleur vive et stable, déduite de [seed].
Color ecoAccentColor(String seed) {
  var hash = 0x811c9dc5;
  for (final unit in seed.trim().toLowerCase().codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final hue = (hash % 360).toDouble();
  final saturation = 0.78 + ((hash >> 8) & 0x3f) / 400;
  final lightness = 0.54 + ((hash >> 16) & 0x3f) / 500;
  return HSLColor.fromAHSL(
    1,
    hue,
    saturation.clamp(0.78, 0.94),
    lightness.clamp(0.54, 0.66),
  ).toColor();
}
