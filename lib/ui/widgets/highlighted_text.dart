import 'package:flutter/material.dart';

/// Texte avec les occurrences de [query] surlignées (insensible à la casse).
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.maxLines = 2,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final highlightStyle = (style ?? const TextStyle()).copyWith(
      color: scheme.onSecondaryContainer,
      backgroundColor: scheme.secondaryContainer,
      fontWeight: FontWeight.w800,
    );
    final needle = query.toLowerCase();
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lower.indexOf(needle, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: style));
        }
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + needle.length),
          style: highlightStyle,
        ),
      );
      start = index + needle.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
