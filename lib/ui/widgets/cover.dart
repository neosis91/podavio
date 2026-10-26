import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cover_cache.dart';
import '../../core/cover_tone.dart';
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
    this.ecoTintFromImage = false,
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

  /// En mode éco, le carré prend la teinte d’une image déjà présente,
  /// sans la télécharger.
  final bool ecoTintFromImage;

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
    final plainLeaf = !expand && (size ?? 81) <= 80;
    final Widget image;
    if (eco && ecoTintFromImage) {
      image = _EcoTintedCover(
        localPath: local,
        url: imageUrl,
        label: name,
        seed: seed,
        headers: httpHeaders,
      );
    } else if (local != null && local.isNotEmpty) {
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
          return _cornerLeaf(child, plain: plainLeaf);
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
              plainLeaf: plainLeaf,
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
              plainLeaf: plainLeaf,
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

  Widget _cornerLeaf(Widget child, {required bool plain}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: _leafInset(size),
          bottom: _leafInset(size),
          child: IgnorePointer(child: _EcoLeaf(side: size, plain: plain)),
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

class _EcoMark extends StatelessWidget {
  const _EcoMark({required this.size, this.plain = false});

  final double size;

  /// Blanc, sans ombre : pastille des listes.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    if (plain) return EcoIcon(size: size, color: Colors.white);
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, 1),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
            child: EcoIcon(size: size, color: Colors.white),
          ),
        ),
        EcoIcon(size: size, color: podavioGreen),
      ],
    );
  }
}

class _EcoLeaf extends StatelessWidget {
  const _EcoLeaf({required this.side, this.plain = false});

  final double? side;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final mark = side == null
        ? 14.0
        : side! < 48
        ? 10.0
        : 14.0;
    return _EcoMark(size: mark, plain: plain);
  }
}

/// Carré coloré à partir du nom. Le texte est blanc et suit la taille du carré.
class EcoNameCover extends StatelessWidget {
  const EcoNameCover({
    super.key,
    required this.label,
    required this.seed,
    this.color,
  });

  final String label;
  final String seed;

  /// Teinte déjà déduite d’une image. Sinon, [ecoAccentColor] sert.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? ecoAccentColor(seed);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final finite = side.isFinite && side > 0 ? side : 56.0;
        final compact = finite <= 80;
        final padding = side <= 200 ? 10.0 : 16.0;
        final textWidth = finite - padding * 2;
        final textHeight = finite - padding * 2;
        final base = Theme.of(context).textTheme.titleMedium;
        final fontSize = _fitEcoFont(
          text: label,
          maxWidth: textWidth,
          maxHeight: textHeight,
          cap: side <= 200 ? 18 : 26,
          scaler: MediaQuery.textScalerOf(context),
          direction: Directionality.of(context),
          base: base,
        );
        final square = ColoredBox(
          color: accent,
          child: compact
              ? Center(
                  child: _EcoMark(size: finite * 0.46, plain: true),
                )
              : Padding(
                  padding: EdgeInsets.all(padding),
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: (base ?? const TextStyle()).copyWith(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
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

double _fitEcoFont({
  required String text,
  required double maxWidth,
  required double maxHeight,
  required double cap,
  required TextScaler scaler,
  required TextDirection direction,
  required TextStyle? base,
}) {
  final sample = text.trim().isEmpty ? ' ' : text;
  var low = 1.0;
  var high = cap < maxHeight ? cap : maxHeight;
  if (high < 8) high = 8;
  var best = low;
  for (var i = 0; i < 14; i++) {
    final mid = (low + high) / 2;
    final painter = TextPainter(
      text: TextSpan(
        text: sample,
        style: (base ?? const TextStyle()).copyWith(
          fontSize: mid,
          fontWeight: FontWeight.w700,
          height: 1.05,
          color: Colors.white,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    final fits =
        painter.width <= maxWidth + 0.5 && painter.height <= maxHeight + 0.5;
    if (fits) {
      best = mid;
      low = mid;
    } else {
      high = mid;
    }
  }
  return best;
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
    required this.plainLeaf,
  });

  final String? url;
  final String label;
  final String seed;
  final double? side;
  final BoxFit fit;
  final int memPixels;
  final FilterQuality quality;
  final bool plainLeaf;

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
              child: IgnorePointer(
                child: _EcoLeaf(side: widget.side, plain: widget.plainLeaf),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Carré éco dont la teinte vient d’une image déjà en local ou en cache.
class _EcoTintedCover extends StatefulWidget {
  const _EcoTintedCover({
    required this.localPath,
    required this.url,
    required this.label,
    required this.seed,
    required this.headers,
  });

  final String? localPath;
  final String? url;
  final String label;
  final String seed;
  final Map<String, String>? headers;

  @override
  State<_EcoTintedCover> createState() => _EcoTintedCoverState();
}

class _EcoTintedCoverState extends State<_EcoTintedCover> {
  static final _colors = <String, Color>{};
  static final _pending = <String, Future<Color?>>{};

  Color? _color;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_EcoTintedCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath == widget.localPath &&
        oldWidget.url == widget.url) {
      return;
    }
    _color = null;
    _resolve();
  }

  Future<void> _resolve() async {
    final local = widget.localPath?.trim();
    final remote = widget.url?.trim();
    final hasLocal = local != null && local.isNotEmpty;
    final hasRemote = remote != null && remote.isNotEmpty;
    if (!hasLocal && !hasRemote) return;
    final key = '${local ?? ''}\n${remote ?? ''}';
    final known = _colors[key];
    if (known != null) {
      _color = known;
      return;
    }
    final future = _pending[key] ??= _sample(local, remote);
    final color = await future;
    _pending.remove(key);
    if (!mounted ||
        widget.localPath?.trim() != local ||
        widget.url?.trim() != remote) {
      return;
    }
    if (color == null) return;
    _colors[key] = color;
    if (_colors.length > 64) _colors.remove(_colors.keys.first);
    setState(() => _color = color);
  }

  Future<Color?> _sample(String? local, String? remote) async {
    final dominant = await loadCoverDominantColor(
      path: local,
      url: remote,
      headers: widget.headers,
      allowDownload: false,
    );
    if (dominant == null) return null;
    return coverBackground(dominant);
  }

  @override
  Widget build(BuildContext context) {
    return EcoNameCover(
      label: widget.label,
      seed: widget.seed,
      color: _color,
    );
  }
}

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
