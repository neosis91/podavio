import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import 'messages.dart';

/// Notes d’épisode : HTML aplati avec liens `<a>` / URLs nues cliquables.
class ShowNotes extends StatefulWidget {
  const ShowNotes({super.key, required this.html, this.style});

  final String html;
  final TextStyle? style;

  @override
  State<ShowNotes> createState() => _ShowNotesState();
}

class _ShowNotesState extends State<ShowNotes> {
  final List<TapGestureRecognizer> _recognizers = [];
  late List<ShowNotesSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = showNotesSpans(widget.html);
    _syncRecognizers();
  }

  @override
  void didUpdateWidget(covariant ShowNotes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _spans = showNotesSpans(widget.html);
      _syncRecognizers();
    }
  }

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

  void _syncRecognizers() {
    _disposeRecognizers();
    for (final span in _spans) {
      if (!span.isLink) continue;
      final url = span.url!;
      _recognizers.add(
        TapGestureRecognizer()..onTap = () => _openLink(url),
      );
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showMessage(context, 'Impossible d’ouvrir le lien');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = widget.style ?? theme.textTheme.bodyMedium;
    final linkStyle = (style ?? const TextStyle()).copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );
    if (_spans.isEmpty) return const SizedBox.shrink();

    var linkIndex = 0;
    final children = <InlineSpan>[];
    for (final span in _spans) {
      if (span.isLink) {
        children.add(
          TextSpan(
            text: span.text,
            style: linkStyle,
            recognizer: _recognizers[linkIndex++],
          ),
        );
      } else {
        children.add(TextSpan(text: span.text, style: style));
      }
    }

    return SelectableText.rich(TextSpan(children: children));
  }
}
