import 'dart:async';

import 'package:flutter/material.dart';

import 'highlighted_text.dart';

/// Titre sur une ligne : s’il dépasse, il défile pour pouvoir tout lire.
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.query = '',
    this.velocity = 36,
    this.startPause = const Duration(milliseconds: 1000),
    this.endPause = const Duration(milliseconds: 700),
    this.gap = 48,
  });

  final String text;
  final TextStyle? style;

  /// Surlignage optionnel (recherche), comme [HighlightedText].
  final String query;

  /// Vitesse en pixels logiques par seconde.
  final double velocity;

  final Duration startPause;
  final Duration endPause;

  /// Espace entre la fin du texte et sa reprise en boucle.
  final double gap;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  double _viewWidth = 0;
  double _lineHeight = 0;
  var _running = false;
  var _loopId = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _loopId++;
    _running = false;
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.query != widget.query ||
        oldWidget.velocity != widget.velocity) {
      _loopId++;
      _running = false;
      _controller.stop();
      _controller.value = 0;
    }
  }

  TextPainter _painter(BuildContext context) {
    return TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
  }

  void _scheduleLoop() {
    final id = ++_loopId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || id != _loopId) return;
      unawaited(_runLoop(id));
    });
  }

  Future<void> _runLoop(int id) async {
    if (_running) return;
    _running = true;
    try {
      while (mounted && id == _loopId) {
        final overflow = _textWidth - _viewWidth;
        if (overflow <= 1 || _viewWidth <= 0 || _textWidth <= 0) {
          _controller.value = 0;
          break;
        }
        await Future<void>.delayed(widget.startPause);
        if (!mounted || id != _loopId) break;

        final distance = _textWidth + widget.gap;
        final ms = (distance / widget.velocity * 1000)
            .round()
            .clamp(600, 45000);
        _controller.duration = Duration(milliseconds: ms);
        try {
          await _controller.forward(from: 0);
        } on TickerCanceled {
          break;
        }
        if (!mounted || id != _loopId) break;

        await Future<void>.delayed(widget.endPause);
        if (!mounted || id != _loopId) break;
        _controller.value = 0;
      }
    } finally {
      if (id == _loopId) _running = false;
    }
  }

  Widget _label() {
    if (widget.query.trim().isEmpty) {
      return Text(
        widget.text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: widget.style,
      );
    }
    return HighlightedText(
      text: widget.text,
      query: widget.query,
      style: widget.style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = constraints.maxWidth;
        if (!viewW.isFinite || viewW <= 0) {
          return _label();
        }

        final painter = _painter(context);
        final textW = painter.width;
        final lineH = painter.height;
        final needsScroll = textW > viewW + 1;

        if ((viewW - _viewWidth).abs() > 0.5 ||
            (textW - _textWidth).abs() > 0.5 ||
            (lineH - _lineHeight).abs() > 0.5) {
          _viewWidth = viewW;
          _textWidth = textW;
          _lineHeight = lineH;
          if (needsScroll) {
            _scheduleLoop();
          } else {
            _loopId++;
            _running = false;
            _controller.stop();
            _controller.value = 0;
          }
        }

        if (!needsScroll) {
          return SizedBox(
            width: viewW,
            child: _label(),
          );
        }

        return ClipRect(
          child: SizedBox(
            width: viewW,
            height: lineH > 0 ? lineH : null,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final dx = -_controller.value * (textW + widget.gap);
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Transform.translate(
                      offset: Offset(dx, 0),
                      child: _label(),
                    ),
                    Transform.translate(
                      offset: Offset(dx + textW + widget.gap, 0),
                      child: _label(),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
