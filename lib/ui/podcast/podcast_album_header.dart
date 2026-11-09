import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/feed_service.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../podcasts/podcast_feed_actions.dart';
import '../widgets/brand.dart';
import '../widgets/cover.dart';
import '../widgets/messages.dart';

/// Haut de page d’une émission, calqué sur la page album : jaquette carrée
/// entière, actions puis description en dessous.
class PodcastAlbumHeader extends ConsumerWidget {
  const PodcastAlbumHeader({
    super.key,
    required this.podcast,
    required this.showPause,
    required this.onPlay,
    required this.onBack,
    required this.onMore,
    required this.onReverse,
    required this.reversed,
    required this.onAutomaticDownload,
    required this.fadeColor,
  });

  final Podcast podcast;
  final bool showPause;
  final VoidCallback? onPlay;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback onReverse;
  final bool reversed;
  final VoidCallback onAutomaticDownload;
  final Color fadeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(podcastEpisodeCountProvider(podcast.id))
        .asData
        ?.value;
    final headers = podcastAuthHeaders(
      username: podcast.authUsername,
      password: podcast.authPassword,
    );
    final top = statusBarInset(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        return Column(
          children: [
            SizedBox(
              height: side,
              width: side,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PodcastCover(
                    url: podcast.imageUrl,
                    localPath: podcast.imagePath,
                    label: podcast.title,
                    httpHeaders: headers,
                    radius: 0,
                    expand: true,
                    fit: BoxFit.contain,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: side * 0.7,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: artworkScrim(fadeColor),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Column(
                      children: [
                        Text(
                          podcast.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.white),
                        ),
                        if (count != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _episodeCountLabel(count),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xC4FFFFFF)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: top + 12,
                    left: 12,
                    child: _CoverIconButton(
                      tooltip: 'Retour',
                      onPressed: onBack,
                      icon: Icons.arrow_back,
                    ),
                  ),
                  Positioned(
                    top: top + 12,
                    right: 12,
                    child: _CoverActionPill(
                      subscribed: podcast.subscribed,
                      preferred: podcast.preferred,
                      onPreferred: () => ref
                          .read(databaseProvider)
                          .setPodcastPreferred(
                            podcast.id,
                            preferred: !podcast.preferred,
                          ),
                      onMore: onMore,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: PodcastActionRow(
                  showPause: showPause,
                  onPlay: onPlay,
                  reversed: reversed,
                  onReverse: onReverse,
                  subscribed: podcast.subscribed,
                  automaticDownload: podcast.autoDownload,
                  onSubscribe: () => subscribeToFeed(
                    context,
                    ref,
                    podcast.feedUrl,
                    openPodcast: false,
                  ),
                  onAutomaticDownload: onAutomaticDownload,
                ),
              ),
            ),
            PodcastDescription(html: podcast.description),
          ],
        );
      },
    );
  }
}

/// Paysage : pochette à gauche, liste à droite.
/// Sous la pochette : les trois actions (inverser, lecture, abonnement).
class PodcastLandscapeFrame extends ConsumerWidget {
  const PodcastLandscapeFrame({
    super.key,
    required this.podcast,
    required this.showPause,
    required this.onPlay,
    required this.onReverse,
    required this.reversed,
    required this.onAutomaticDownload,
    required this.listColor,
    required this.episodes,
  });

  final Podcast podcast;
  final bool showPause;
  final VoidCallback? onPlay;
  final VoidCallback onReverse;
  final bool reversed;
  final VoidCallback onAutomaticDownload;
  final Color listColor;
  final Widget episodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = podcastAuthHeaders(
      username: podcast.authUsername,
      password: podcast.authPassword,
    );
    final media = MediaQuery.of(context);
    final top = statusBarInset(context) + kToolbarHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : media.size.height;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : media.size.width;
        final available = (height - top).clamp(0.0, height);
        // 32 de marge, 12 sous la pochette, 64 pour la rangée d’actions.
        final side = (available - 108).clamp(0.0, width * 0.42);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: side + 24,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, top + 16, 8, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox.square(
                        dimension: side,
                        child: PodcastCover(
                          url: podcast.imageUrl,
                          localPath: podcast.imagePath,
                          label: podcast.title,
                          httpHeaders: headers,
                          radius: 0,
                          expand: true,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: PodcastActionRow(
                        showPause: showPause,
                        onPlay: onPlay,
                        reversed: reversed,
                        onReverse: onReverse,
                        subscribed: podcast.subscribed,
                        automaticDownload: podcast.autoDownload,
                        onSubscribe: () => subscribeToFeed(
                          context,
                          ref,
                          podcast.feedUrl,
                          openPodcast: false,
                        ),
                        onAutomaticDownload: onAutomaticDownload,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: ColoredBox(color: listColor, child: episodes),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// [Inverser] [Lecture] [S’abonner ou téléchargement automatique]. 48 dp, espacés de 12.
class PodcastActionRow extends StatelessWidget {
  const PodcastActionRow({
    super.key,
    required this.showPause,
    required this.onPlay,
    required this.reversed,
    required this.onReverse,
    required this.subscribed,
    required this.automaticDownload,
    required this.onSubscribe,
    required this.onAutomaticDownload,
  });

  final bool showPause;
  final VoidCallback? onPlay;
  final bool reversed;
  final VoidCallback onReverse;
  final bool subscribed;
  final bool automaticDownload;
  final VoidCallback onSubscribe;
  final VoidCallback onAutomaticDownload;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundButton(
            tooltip: 'Inverser l’ordre',
            onTap: onReverse,
            color: reversed
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            child: Icon(
              Icons.swap_vert,
              size: 22,
              color: reversed ? Colors.black : Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: showPause ? 'Pause' : 'Lire',
            child: Material(
              color: Colors.white,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPlay,
                customBorder: const StadiumBorder(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 110,
                    minHeight: 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          showPause ? Icons.pause : Icons.play_arrow,
                          size: 22,
                          color: onPlay == null ? Colors.black38 : Colors.black,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.tr(showPause ? 'Pause' : 'Play'),
                          style: label?.copyWith(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (subscribed)
            _RoundButton(
              tooltip: context.tr('Automatic download'),
              onTap: onAutomaticDownload,
              color: Colors.white.withValues(alpha: 0.12),
              child: Icon(
                Icons.downloading,
                size: 22,
                color: automaticDownload
                    ? const Color(0xff4CAF50)
                    : Colors.white,
              ),
            )
          else
            _RoundButton(
              tooltip: 'S’abonner',
              onTap: onSubscribe,
              color: Colors.white.withValues(alpha: 0.12),
              child: const Icon(
                Icons.person_add_alt_1,
                size: 22,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

/// Description repliée sur 3 lignes, avec les liens cliquables.
class PodcastDescription extends StatefulWidget {
  const PodcastDescription({super.key, required this.html});

  final String html;

  @override
  State<PodcastDescription> createState() => _PodcastDescriptionState();
}

class _PodcastDescriptionState extends State<PodcastDescription> {
  var _expanded = false;
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final spans = showNotesSpans(widget.html);
    if (spans.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Colors.white);
    final linkStyle = style?.copyWith(color: const Color(0xFF00B0FF));
    final text = TextSpan(
      children: [
        for (final span in spans)
          TextSpan(
            text: span.text,
            style: span.isLink ? linkStyle : style,
            recognizer: span.isLink ? _link(span.url!) : null,
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: text,
            textDirection: Directionality.of(context),
            maxLines: 3,
          )..layout(maxWidth: constraints.maxWidth);
          final overflows = painter.didExceedMaxLines;
          painter.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.topCenter,
                child: Text.rich(
                  text,
                  maxLines: _expanded ? null : 3,
                  overflow: TextOverflow.clip,
                ),
              ),
              if (overflows) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Moins' : 'Plus',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: const Color(0xFFD3D3D3)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  TapGestureRecognizer _link(String url) {
    final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
    _recognizers.add(recognizer);
    return recognizer;
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showMessage(context, 'Impossible d’ouvrir le lien');
    }
  }
}

class _CoverActionPill extends StatelessWidget {
  const _CoverActionPill({
    required this.subscribed,
    required this.preferred,
    required this.onPreferred,
    required this.onMore,
  });

  final bool subscribed;
  final bool preferred;
  final VoidCallback onPreferred;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subscribed)
            IconButton(
              tooltip: preferred
                  ? 'Retirer des préférés'
                  : 'Marquer comme préféré',
              onPressed: onPreferred,
              icon: PreferredStarIcon(
                selected: preferred,
                size: 28,
                color: preferred ? preferredStarColor : Colors.white,
              ),
            ),
          IconButton(
            tooltip: 'Plus',
            onPressed: onMore,
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _CoverIconButton extends StatelessWidget {
  const _CoverIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.28),
        foregroundColor: Colors.white,
        fixedSize: const Size(48, 48),
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, color: Colors.white),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.onTap,
    required this.color,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 48, height: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Fondu du bas de jaquette. Vingt-quatre pas, progression `t² (3 − 2t)` :
/// le haut de la zone reste clair, la teinte n’est opaque qu’au bord bas.
LinearGradient artworkScrim(Color color) {
  const steps = 24;
  final from = color.withValues(alpha: 0);
  final colors = <Color>[];
  final stops = <double>[];
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final eased = t * t * (3 - 2 * t);
    stops.add(t);
    colors.add(Color.lerp(from, color, eased)!);
  }
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: colors,
    stops: stops,
  );
}

/// Hauteur de la barre d’état. Le scaffold qui porte une [AppBar] met
/// [MediaQueryData.viewPadding] à zéro dans son corps : il faut lire la vue.
double statusBarInset(BuildContext context) {
  final view = View.of(context);
  return view.padding.top / view.devicePixelRatio;
}

String _episodeCountLabel(int? count) {
  if (count == null) return '';
  if (count == 1) return '1 épisode';
  return '$count épisodes';
}
