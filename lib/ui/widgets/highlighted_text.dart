import 'package:flutter/material.dart';

import '../../core/search.dart';

/// Texte avec les occurrences de [query] surlignées
/// (insensible à la casse et aux accents).
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
    if (query.trim().isEmpty) {
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
    final needle = foldForSearch(query);
    if (needle.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final lower = text.toLowerCase();
    final mapped = foldForSearchMapped(text);
    final spans = <TextSpan>[];
    var start = 0;
    var foldStart = 0;
    while (true) {
      final index = mapped.folded.indexOf(needle, foldStart);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: style));
        }
        break;
      }
      final matchStart = mapped.origins[index];
      final matchEnd = foldedMatchEndExclusive(
        lower,
        mapped.origins,
        index,
        needle.length,
      );
      // toLowerCase() conserve la longueur pour les titres FR courants.
      final origStart = matchStart.clamp(0, text.length);
      final origEnd = matchEnd.clamp(0, text.length);
      if (origStart > start) {
        spans.add(
          TextSpan(text: text.substring(start, origStart), style: style),
        );
      }
      if (origEnd > origStart) {
        spans.add(
          TextSpan(
            text: text.substring(origStart, origEnd),
            style: highlightStyle,
          ),
        );
      }
      start = origEnd;
      foldStart = index + needle.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
