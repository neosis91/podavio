import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_controller.dart';
import 'cover.dart';

/// Jaquette d’épisode. Pendant la lecture, les barres passent sur l’image
/// assombrie. En pause, seule la jaquette reste.
class PlayingEpisodeCover extends ConsumerWidget {
  const PlayingEpisodeCover({
    super.key,
    required this.episodeId,
    this.url,
    this.localPath,
    this.httpHeaders,
    this.label,
    this.colorKey,
    this.size = 48,
    this.radius = 4,
  });

  final int episodeId;
  final String? url;
  final String? localPath;
  final Map<String, String>? httpHeaders;
  final String? label;
  final String? colorKey;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(
      playerProvider.select(
        (state) => state.playing && state.episodeId == episodeId,
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PodcastCover(
            url: url,
            localPath: localPath,
            httpHeaders: httpHeaders,
            label: label,
            colorKey: colorKey,
            size: size,
            radius: radius,
            ecoTintFromImage: true,
          ),
          if (playing) ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x73000000),
                  borderRadius: BorderRadius.all(Radius.circular(radius)),
                ),
              ),
            ),
            _PlayingBars(size: size),
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
