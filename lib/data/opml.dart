import 'package:xml/xml.dart';

import 'app_database.dart';

class OpmlEntry {
  const OpmlEntry({required this.title, required this.feedUrl, this.imageUrl});

  final String title;
  final String feedUrl;
  final String? imageUrl;
}

String buildOpml(List<Podcast> podcasts) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element(
    'opml',
    attributes: {'version': '2.0'},
    nest: () {
      builder.element(
        'head',
        nest: () {
          builder.element('title', nest: 'Podavio');
        },
      );
      builder.element(
        'body',
        nest: () {
          for (final podcast in podcasts) {
            final attributes = <String, String>{
              'text': podcast.title,
              'title': podcast.title,
              'type': 'rss',
              'xmlUrl': podcast.feedUrl,
            };
            final image = podcast.imageUrl?.trim();
            if (image != null && image.isNotEmpty) {
              attributes['imageUrl'] = image;
            }
            builder.element('outline', attributes: attributes);
          }
        },
      );
    },
  );
  return builder.buildDocument().toXmlString(pretty: true);
}

/// Normalise une URL de flux pour comparer les abonnements.
String normalizeFeedUrl(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return trimmed.toLowerCase();
  }
  var path = uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  // Rebuild without fragment — Uri.replace(fragment: '') leaves a trailing '#'.
  return Uri(
    scheme: uri.scheme.toLowerCase(),
    userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    path: path,
    query: uri.hasQuery ? uri.query : null,
  ).toString();
}

List<String> parseOpml(String xmlText) {
  return [for (final entry in parseOpmlEntries(xmlText)) entry.feedUrl];
}

List<OpmlEntry> parseOpmlEntries(String xmlText) {
  final document = XmlDocument.parse(xmlText);
  final entries = <OpmlEntry>[];
  final seen = <String>{};
  for (final node in document.findAllElements('outline')) {
    final url = _attribute(node, 'xmlUrl') ?? _attribute(node, 'url');
    if (url == null) continue;
    final trimmed = url.trim();
    if (trimmed.isEmpty) continue;
    final key = normalizeFeedUrl(trimmed);
    if (!seen.add(key)) continue;
    final title =
        (_attribute(node, 'title') ?? _attribute(node, 'text') ?? trimmed)
            .trim();
    final image =
        _attribute(node, 'imageUrl') ??
        _attribute(node, 'image') ??
        _attribute(node, 'icon');
    final imageUrl = image?.trim();
    entries.add(
      OpmlEntry(
        title: title.isEmpty ? trimmed : title,
        feedUrl: trimmed,
        imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
      ),
    );
  }
  return entries;
}

String? _attribute(XmlElement node, String name) {
  final direct = node.getAttribute(name);
  if (direct != null) return direct;
  final lower = name.toLowerCase();
  for (final attribute in node.attributes) {
    if (attribute.name.local.toLowerCase() == lower) return attribute.value;
  }
  return null;
}
