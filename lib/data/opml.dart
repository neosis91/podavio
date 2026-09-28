import 'package:xml/xml.dart';

import 'app_database.dart';

String buildOpml(List<Podcast> podcasts) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element('opml', attributes: {'version': '2.0'}, nest: () {
    builder.element('head', nest: () {
      builder.element('title', nest: 'Podavio');
    });
    builder.element('body', nest: () {
      for (final podcast in podcasts) {
        builder.element('outline', attributes: {
          'text': podcast.title,
          'title': podcast.title,
          'type': 'rss',
          'xmlUrl': podcast.feedUrl,
        });
      }
    });
  });
  return builder.buildDocument().toXmlString(pretty: true);
}

List<String> parseOpml(String xmlText) {
  final document = XmlDocument.parse(xmlText);
  final urls = <String>[];
  for (final node in document.findAllElements('outline')) {
    final url = node.getAttribute('xmlUrl') ?? node.getAttribute('url');
    if (url == null) continue;
    final trimmed = url.trim();
    if (trimmed.isEmpty || urls.contains(trimmed)) continue;
    urls.add(trimmed);
  }
  return urls;
}
