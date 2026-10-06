part of '../podcasts_page.dart';

const _gridPadding = 16.0;
const _gridSpacing = 16.0;
const _phoneMaxColumns = 5;
const _tabletMaxColumns = 8;
const _tabletBreakpoint = 600.0;

int maxPodcastColumnsFor(double width) {
  return width >= _tabletBreakpoint ? _tabletMaxColumns : _phoneMaxColumns;
}

/// Taille lisible du titre en grille, selon la largeur de jaquette.
double _gridTitleFontSize(double tileWidth) {
  // ~12 % de la jaquette : assez grand sur peu de colonnes, compact si dense.
  return (tileWidth * 0.12).clamp(10.0, 14.5);
}

double _gridTitleGap(double fontSize) => fontSize >= 12.5 ? 8.0 : 6.0;

/// Taille lisible du titre en liste, selon la largeur d’écran.
double _listTitleFontSize(double screenWidth, double baseSize) {
  if (screenWidth < 360) return (baseSize * 0.88).clamp(13.0, 16.0);
  if (screenWidth < _tabletBreakpoint) {
    return (baseSize * 0.94).clamp(14.0, 17.0);
  }
  if (screenWidth < 900) return baseSize.clamp(15.0, 18.0);
  return (baseSize * 1.05).clamp(16.0, 19.0);
}

class _HighlightedTitle extends StatelessWidget {
  const _HighlightedTitle({
    required this.text,
    required this.query,
    required this.style,
  });

  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return HighlightedText(text: text, query: query, style: style);
  }
}

class _PodcastGrid extends StatelessWidget {
  const _PodcastGrid({
    required this.items,
    required this.columns,
    required this.showNames,
    required this.highlightQuery,
    required this.counts,
  });

  final List<Podcast> items;
  final int columns;
  final bool showNames;
  final String highlightQuery;
  final Map<int, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    const lineHeight = 1.2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth -
                _gridPadding * 2 -
                _gridSpacing * (columns - 1)) /
            columns;
        final fontSize = _gridTitleFontSize(tileWidth);
        final gap = _gridTitleGap(fontSize);
        final titleStyle = theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          height: lineHeight,
          fontSize: fontSize,
          letterSpacing: fontSize < 11.5 ? -0.1 : 0,
        );
        final titleHeight = showNames
            ? textScaler.scale(fontSize) * lineHeight * 2
            : 0.0;
        final textHeight = showNames ? gap + titleHeight : 0.0;
        return GridView.builder(
          padding: const EdgeInsets.all(_gridPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _gridSpacing,
            crossAxisSpacing: _gridSpacing,
            mainAxisExtent: tileWidth + textHeight,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final podcast = items[index];
            final count = counts[podcast.id] ?? 0;
            return KeyedSubtree(
              key: ValueKey(podcast.id),
              child: _PodcastGridTile(
                podcast: podcast,
                showName: showNames,
                highlightQuery: highlightQuery,
                count: count,
                titleHeight: titleHeight,
                gap: gap,
                titleStyle: titleStyle,
                tileWidth: tileWidth,
              ),
            );
          },
        );
      },
    );
  }
}

class _PodcastGridTile extends StatelessWidget {
  const _PodcastGridTile({
    required this.podcast,
    required this.showName,
    required this.highlightQuery,
    required this.count,
    required this.titleHeight,
    required this.gap,
    required this.titleStyle,
    required this.tileWidth,
  });

  final Podcast podcast;
  final bool showName;
  final String highlightQuery;
  final int count;
  final double titleHeight;
  final double gap;
  final TextStyle? titleStyle;
  final double tileWidth;

  @override
  Widget build(BuildContext context) {
    final cover = _CoverWithCount(
      url: podcast.imageUrl,
      localPath: podcast.imagePath,
      httpHeaders: podcastAuthHeaders(
        username: podcast.authUsername,
        password: podcast.authPassword,
      ),
      radius: 16,
      count: count,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(AppRoutes.podcast(podcast.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: showName
                ? cover
                : Semantics(
                    label: podcast.title,
                    button: true,
                    child: cover,
                  ),
          ),
          if (showName) ...[
            SizedBox(height: gap),
            SizedBox(
              height: titleHeight,
              width: tileWidth,
              child: _HighlightedTitle(
                text: podcast.title,
                query: highlightQuery,
                style: titleStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PodcastListTile extends StatelessWidget {
  const _PodcastListTile({
    super.key,
    required this.podcast,
    required this.showName,
    required this.highlightQuery,
    required this.count,
  });

  final Podcast podcast;
  final bool showName;
  final String highlightQuery;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final baseSize = theme.textTheme.titleMedium?.fontSize ?? 16;
    final listStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.25,
      fontSize: _listTitleFontSize(screenWidth, baseSize),
    );
    final cover = _CoverWithCount(
      url: podcast.imageUrl,
      localPath: podcast.imagePath,
      httpHeaders: podcastAuthHeaders(
        username: podcast.authUsername,
        password: podcast.authPassword,
      ),
      size: 72,
      radius: 12,
      count: count,
    );
    return InkWell(
      onTap: () => context.push(AppRoutes.podcast(podcast.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: showName
                    ? cover
                    : Semantics(
                        label: podcast.title,
                        button: true,
                        child: cover,
                      ),
              ),
              if (showName) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _HighlightedTitle(
                    text: podcast.title,
                    query: highlightQuery,
                    style: listStyle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverWithCount extends StatelessWidget {
  const _CoverWithCount({
    required this.url,
    this.localPath,
    this.httpHeaders,
    required this.radius,
    required this.count,
    this.size,
  });

  final String? url;
  final String? localPath;
  final Map<String, String>? httpHeaders;
  final double radius;
  final int count;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        PodcastCover(
          url: url,
          localPath: localPath,
          httpHeaders: httpHeaders,
          size: size,
          radius: radius,
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
