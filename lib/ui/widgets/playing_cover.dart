import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_controller.dart';
import 'cover.dart';

/// Jaquette d’épisode. Pendant la lecture, les barres passent sur l’image
/// assombrie. En pause, seule la jaquette reste.
///
/// Pendant un téléchargement, un anneau (comme le mini-lecteur) entoure la
/// pochette : indéterminé au démarrage, puis progression.
class PlayingEpisodeCover extends ConsumerWidget {
  const PlayingEpisodeCover({
    super.key,
    required this.episodeId,
    this.url,
    this.localPath,
    this.httpHeaders,
    this.size = 48,
    this.radius = 4,
    this.downloadProgress,
  });

  final int episodeId;
  final String? url;
  final String? localPath;
  final Map<String, String>? httpHeaders;
  final double size;
  final double radius;

  /// `null` = pas de téléchargement. `0` = spinner, `]0,1]` = progression.
  final double? downloadProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(
      playerProvider.select(
        (state) => state.playing && state.episodeId == episodeId,
      ),
    );
    final downloading = downloadProgress != null;
    // Même proportion pochette / anneau que le mini-lecteur (26 / 40).
    final coverSize = downloading ? size * 0.65 : size;
    final coverRadius = downloading
        ? (radius * coverSize / size).clamp(2.0, radius)
        : radius;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (downloading)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: downloadProgress == 0 ? null : downloadProgress,
                ),
              ),
            ),
          PodcastCover(
            url: url,
            localPath: localPath,
            httpHeaders: httpHeaders,
            size: coverSize,
            radius: coverRadius,
          ),
          if (playing) ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x73000000),
                  borderRadius: BorderRadius.all(
                    Radius.circular(downloading ? coverRadius : radius),
                  ),
                ),
              ),
            ),
            _PlayingBars(size: coverSize),
          ],
        ],
      ),
    );
  }
}

class _PlayingBars extends StatefulWidget {
  const _PlayingBars({required this.size});

  final double size;

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _px(double at48) => at48 * widget.size / 48;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: _px(4),
                height: _px(10) + _px(18) * _level(i),
                margin: EdgeInsets.symmetric(horizontal: _px(2)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_px(2)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x80000000),
                      blurRadius: _px(4),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  double _level(int index) {
    final t = (_controller.value + index / 3) % 1;
    return t < 0.5 ? t * 2 : (1 - t) * 2;
  }
}
