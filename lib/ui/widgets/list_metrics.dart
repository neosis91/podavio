import 'package:flutter/material.dart';

import '../../settings/settings_controller.dart';

/// Paliers de largeur utiles pour les listes (alignés sur les abonnements).
enum ListWidthTier {
  narrow,
  phone,
  tablet,
  large,
}

/// Largeur max du contenu des listes d’épisodes sur grand écran.
const double kEpisodeListMaxWidth = 800;

ListWidthTier listWidthTier(double width) {
  if (width < 360) return ListWidthTier.narrow;
  if (width < 600) return ListWidthTier.phone;
  if (width < 900) return ListWidthTier.tablet;
  return ListWidthTier.large;
}

/// Padding horizontal de la tuile selon le palier de largeur utile.
double listHorizontalPadding(double width) {
  switch (listWidthTier(width)) {
    case ListWidthTier.narrow:
      return 12;
    case ListWidthTier.phone:
      return 16;
    case ListWidthTier.tablet:
      return 20;
    case ListWidthTier.large:
      return 24;
  }
}

/// Sur grand écran, limite la largeur utile pour éviter des lignes trop longues.
double? episodeListMaxWidthFor(double width) {
  return listWidthTier(width) == ListWidthTier.large
      ? kEpisodeListMaxWidth
      : null;
}

/// Insets latéraux pour centrer une liste plafonnée à [kEpisodeListMaxWidth].
EdgeInsets episodeListViewportInsets(double width) {
  final maxWidth = episodeListMaxWidthFor(width);
  if (maxWidth == null) return EdgeInsets.zero;
  final side = ((width - maxWidth) / 2).clamp(0.0, double.infinity);
  return EdgeInsets.symmetric(horizontal: side);
}

/// Métriques typographiques et de jaquette pour une tuile d’épisode.
class EpisodeTileMetrics {
  const EpisodeTileMetrics({
    required this.tier,
    required this.density,
    required this.titleStyle,
    required this.metaStyle,
    required this.coverSize,
    required this.gap,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.progressBarHeight,
    required this.showDownloadPercent,
    required this.trailingVisualDensity,
    required this.trailingMinSize,
    required this.progressRingSize,
  });

  final ListWidthTier tier;
  final EpisodeListDensity density;
  final TextStyle titleStyle;
  final TextStyle metaStyle;
  final double coverSize;
  final double gap;
  final double horizontalPadding;
  final double verticalPadding;

  /// Hauteur de la barre de progression sous la jaquette (2–3).
  final double progressBarHeight;

  /// Afficher le % à côté de l’anneau de téléchargement (masqué sous 360).
  final bool showDownloadPercent;

  /// Densité des boutons trailing (compact sur étroit/téléphone).
  final VisualDensity trailingVisualDensity;

  /// Côté min des boutons trailing / menu (32–48 selon palier).
  final double trailingMinSize;

  /// Taille de l’anneau de progression de téléchargement.
  final double progressRingSize;

  BoxConstraints get trailingConstraints => BoxConstraints.tightFor(
        width: trailingMinSize,
        height: trailingMinSize,
      );

  /// Calcule les styles et la jaquette selon largeur utile, densité et textScaler.
  factory EpisodeTileMetrics.resolve({
    required double width,
    required TextTheme textTheme,
    required TextScaler textScaler,
    required EpisodeListDensity density,
    required bool played,
    required Color onSurface,
    required Color muted,
  }) {
    final tier = listWidthTier(width);
    final compact = density == EpisodeListDensity.compact;

    final baseTitle = compact
        ? (textTheme.titleSmall ?? const TextStyle(fontSize: 14))
        : (textTheme.titleMedium ?? const TextStyle(fontSize: 16));
    final baseMeta = compact
        ? (textTheme.bodySmall ?? const TextStyle(fontSize: 12))
        : (textTheme.bodyMedium ?? const TextStyle(fontSize: 14));

    final titleSize = _scaledFontSize(
      width,
      baseTitle.fontSize ?? (compact ? 14.0 : 16.0),
    );
    final metaSize = _scaledFontSize(
      width,
      baseMeta.fontSize ?? (compact ? 12.0 : 14.0),
      meta: true,
    );

    final titleHeight = baseTitle.height ?? 1.25;
    final metaHeight = baseMeta.height ?? 1.25;

    final titleStyle = baseTitle.copyWith(
      fontSize: titleSize,
      height: titleHeight,
      fontWeight: played ? FontWeight.w500 : FontWeight.w700,
      color: played ? muted : onSurface,
    );
    final metaStyle = baseMeta.copyWith(
      fontSize: metaSize,
      height: metaHeight,
      color: muted,
    );

    final gap = _gapFor(tier, compact);
    final titleExtent = _lineExtent(titleSize, titleHeight, textScaler);
    final metaExtent = _lineExtent(metaSize, metaHeight, textScaler);
    // 2 lignes titre + 1 ligne méta + 2 écarts.
    final rawCover = titleExtent * 2 + metaExtent + gap * 2;
    final clamp = _coverClamp(tier, compact);
    final coverSize = rawCover.roundToDouble().clamp(clamp.$1, clamp.$2);
    final trailing = _trailingMetrics(tier, compact);

    return EpisodeTileMetrics(
      tier: tier,
      density: density,
      titleStyle: titleStyle,
      metaStyle: metaStyle,
      coverSize: coverSize,
      gap: gap,
      horizontalPadding: listHorizontalPadding(width),
      verticalPadding: compact ? (tier == ListWidthTier.narrow ? 4.0 : 6.0) : 8.0,
      progressBarHeight: _progressBarHeight(tier, compact),
      showDownloadPercent: trailing.showPercent,
      trailingVisualDensity: trailing.density,
      trailingMinSize: trailing.minSize,
      progressRingSize: trailing.ringSize,
    );
  }
}

/// Centre et plafonne le contenu des listes d’épisodes sur grand écran.
class EpisodeListViewport extends StatelessWidget {
  const EpisodeListViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = episodeListViewportInsets(constraints.maxWidth);
        if (insets == EdgeInsets.zero) return child;
        return Padding(padding: insets, child: child);
      },
    );
  }
}

/// Densité / hit-target des actions trailing selon palier × densité liste.
({
  bool showPercent,
  VisualDensity density,
  double minSize,
  double ringSize,
}) _trailingMetrics(ListWidthTier tier, bool compact) {
  switch (tier) {
    case ListWidthTier.narrow:
      return (
        showPercent: false,
        density: VisualDensity.compact,
        minSize: compact ? 32.0 : 34.0,
        ringSize: compact ? 22.0 : 24.0,
      );
    case ListWidthTier.phone:
      return (
        showPercent: true,
        density: VisualDensity.compact,
        minSize: compact ? 32.0 : 36.0,
        ringSize: compact ? 24.0 : 26.0,
      );
    case ListWidthTier.tablet:
      return (
        showPercent: true,
        density: compact ? VisualDensity.compact : VisualDensity.standard,
        minSize: compact ? 40.0 : 44.0,
        ringSize: compact ? 26.0 : 28.0,
      );
    case ListWidthTier.large:
      return (
        showPercent: true,
        density: compact ? VisualDensity.compact : VisualDensity.standard,
        minSize: compact ? 44.0 : 48.0,
        ringSize: compact ? 28.0 : 30.0,
      );
  }
}

double _scaledFontSize(double width, double baseSize, {bool meta = false}) {
  // Même logique que `_listTitleFontSize` (abonnements), un cran plus bas pour la méta.
  final double scaled;
  if (width < 360) {
    scaled = baseSize * 0.9;
  } else if (width < 600) {
    scaled = baseSize * (meta ? 0.96 : 0.94);
  } else if (width < 900) {
    scaled = baseSize * (meta ? 1.0 : 1.02);
  } else {
    scaled = baseSize * (meta ? 1.02 : 1.06);
  }

  if (meta) {
    if (width < 360) return scaled.clamp(11.0, 14.0);
    if (width < 600) return scaled.clamp(12.0, 15.0);
    if (width < 900) return scaled.clamp(12.5, 16.0);
    return scaled.clamp(13.0, 17.0);
  }

  if (width < 360) return scaled.clamp(13.0, 16.0);
  if (width < 600) return scaled.clamp(14.0, 17.0);
  if (width < 900) return scaled.clamp(15.0, 18.0);
  return scaled.clamp(16.0, 19.0);
}

double _gapFor(ListWidthTier tier, bool compact) {
  if (compact) {
    return tier == ListWidthTier.narrow ? 2.0 : 3.0;
  }
  return tier == ListWidthTier.narrow ? 2.0 : 4.0;
}

/// Compact + étroit → 2 ; sinon 2 sur étroit/compact, 3 sur le reste.
double _progressBarHeight(ListWidthTier tier, bool compact) {
  if (compact || tier == ListWidthTier.narrow) return 2.0;
  return 3.0;
}

(double, double) _coverClamp(ListWidthTier tier, bool compact) {
  switch (tier) {
    case ListWidthTier.narrow:
      return compact ? (48.0, 68.0) : (52.0, 72.0);
    case ListWidthTier.phone:
      return compact ? (52.0, 80.0) : (56.0, 88.0);
    case ListWidthTier.tablet:
      return compact ? (56.0, 88.0) : (60.0, 92.0);
    case ListWidthTier.large:
      return compact ? (60.0, 92.0) : (64.0, 96.0);
  }
}

double _lineExtent(double fontSize, double height, TextScaler textScaler) {
  return textScaler.scale(fontSize) * height;
}
