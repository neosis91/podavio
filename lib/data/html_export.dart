import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_database.dart';

/// Charge le logo Podavio pour l’intégrer dans l’export HTML.
Future<String> _logoDataUri() async {
  final bytes = await rootBundle.load('assets/brand/logo.png');
  final b64 = base64Encode(bytes.buffer.asUint8List());
  return 'data:image/png;base64,$b64';
}

/// Icône onde (même SVG que l’app), en vert Podavio.
const _waveIconSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 88" fill="#2E895D" width="120" height="44" role="img" aria-label="Podavio">
  <rect x="2.40" y="36.96" width="6.63" height="14.08" rx="3.31"/>
  <rect x="13.83" y="32.56" width="6.63" height="22.88" rx="3.31"/>
  <rect x="25.26" y="26.40" width="6.63" height="35.20" rx="3.31"/>
  <rect x="36.69" y="18.48" width="6.63" height="51.04" rx="3.31"/>
  <rect x="48.11" y="11.44" width="6.63" height="65.12" rx="3.31"/>
  <rect x="59.54" y="22.00" width="6.63" height="44.00" rx="3.31"/>
  <rect x="70.97" y="6.16" width="6.63" height="75.68" rx="3.31"/>
  <rect x="82.40" y="15.84" width="6.63" height="56.32" rx="3.31"/>
  <rect x="93.83" y="24.64" width="6.63" height="38.72" rx="3.31"/>
  <rect x="105.26" y="4.40" width="6.63" height="79.20" rx="3.31"/>
  <rect x="116.69" y="16.72" width="6.63" height="54.56" rx="3.31"/>
  <rect x="128.11" y="7.92" width="6.63" height="72.16" rx="3.31"/>
  <rect x="139.54" y="22.88" width="6.63" height="42.24" rx="3.31"/>
  <rect x="150.97" y="2.64" width="6.63" height="82.72" rx="3.31"/>
  <rect x="162.40" y="13.20" width="6.63" height="61.60" rx="3.31"/>
  <rect x="173.83" y="25.52" width="6.63" height="36.96" rx="3.31"/>
  <rect x="185.26" y="14.96" width="6.63" height="58.08" rx="3.31"/>
  <rect x="196.69" y="22.00" width="6.63" height="44.00" rx="3.31"/>
  <rect x="208.11" y="29.92" width="6.63" height="28.16" rx="3.31"/>
  <rect x="219.54" y="34.32" width="6.63" height="19.36" rx="3.31"/>
  <rect x="230.97" y="37.84" width="6.63" height="12.32" rx="3.31"/>
</svg>
''';

/// Export HTML des abonnements (partage / lecture, pas de ré-import).
Future<String> buildSubscriptionsHtml(List<Podcast> podcasts) async {
  final cards = StringBuffer();
  for (final podcast in podcasts) {
    if (!podcast.subscribed) continue;
    cards.write(_subscriptionCard(podcast));
  }
  return _document(
    title: 'Abonnements',
    subtitle: 'Exportés depuis Podavio',
    logoUri: await _logoDataUri(),
    body: cards.isEmpty
        ? '<p class="empty">Aucun abonnement.</p>'
        : '<ul class="cards">$cards</ul>',
  );
}

/// Export HTML des favoris, groupés par podcast.
Future<String> buildFavoritesHtml(List<EpisodeEntry> favorites) async {
  final byPodcast = <int, List<EpisodeEntry>>{};
  for (final entry in favorites) {
    byPodcast.putIfAbsent(entry.podcast.id, () => []).add(entry);
  }
  final sections = StringBuffer();
  final podcasts = byPodcast.values.map((items) => items.first.podcast).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  for (final podcast in podcasts) {
    final items = byPodcast[podcast.id]!;
    sections.write('<li class="group">');
    sections.write(_feedHeader(podcast));
    sections.write('<ul class="episodes">');
    for (final entry in items) {
      sections.write(_favoriteItem(entry));
    }
    sections.write('</ul></li>');
  }
  return _document(
    title: 'Favoris',
    subtitle: 'Exportés depuis Podavio',
    logoUri: await _logoDataUri(),
    body: sections.isEmpty
        ? '<p class="empty">Aucun favori.</p>'
        : '<ul class="cards">$sections</ul>',
  );
}

String _subscriptionCard(Podcast podcast) {
  final image = _esc(podcast.imageUrl?.trim() ?? '');
  final title = _esc(podcast.title);
  final website = podcast.link?.trim();
  final feed = podcast.feedUrl.trim();
  final links = <String>[
    if (website != null && website.isNotEmpty)
      '<a href="${_esc(website)}">Site</a>',
    if (feed.isNotEmpty) '<a href="${_esc(feed)}">Flux</a>',
  ].join(' · ');
  return '''
<li>
  <div class="card">
    ${image.isEmpty ? '<div class="cover placeholder"></div>' : '<img class="cover" src="$image" alt="">'}
    <div class="meta">
      <p class="title">$title</p>
      ${links.isEmpty ? '' : '<p class="links">$links</p>'}
    </div>
  </div>
</li>
''';
}

String _feedHeader(Podcast podcast) {
  final image = _esc(podcast.imageUrl?.trim() ?? '');
  final title = _esc(podcast.title);
  final website = podcast.link?.trim();
  final feed = podcast.feedUrl.trim();
  final links = <String>[
    if (website != null && website.isNotEmpty)
      '<a href="${_esc(website)}">Site</a>',
    if (feed.isNotEmpty) '<a href="${_esc(feed)}">Flux</a>',
  ].join(' · ');
  return '''
<div class="card feed">
  ${image.isEmpty ? '<div class="cover placeholder"></div>' : '<img class="cover" src="$image" alt="">'}
  <div class="meta">
    <p class="title">$title</p>
    ${links.isEmpty ? '' : '<p class="links">$links</p>'}
  </div>
</div>
''';
}

String _favoriteItem(EpisodeEntry entry) {
  final title = _esc(entry.episode.title.trim());
  final media = entry.episode.audioUrl.trim();
  final links = media.isEmpty
      ? ''
      : '<p class="links"><a href="${_esc(media)}">Audio</a></p>';
  return '''
<li class="episode">
  <p class="episode-title">$title</p>
  $links
</li>
''';
}

String _document({
  required String title,
  required String subtitle,
  required String logoUri,
  required String body,
}) {
  final safeTitle = _esc(title);
  final safeSubtitle = _esc(subtitle);
  return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Podavio · $safeTitle</title>
<style>
  :root {
    --green: #2e895d;
    --green-deep: #1f6b48;
    --mint: #b0dac9;
    --mint-light: #d0ebdf;
    --mint-center: #e8f6ef;
    --ink: #1a2e24;
    --muted: #4a6b5c;
    --card: #ffffff;
    --line: #dceee5;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html {
    min-height: 100%;
    /* Fond type bannières Play Store Podavio */
    background:
      radial-gradient(ellipse 90% 70% at 50% 28%, var(--mint-center) 0%, transparent 55%),
      radial-gradient(ellipse 120% 90% at 50% 100%, var(--mint) 0%, var(--mint-light) 45%, #9fd0bb 100%);
    background-color: var(--mint-light);
  }
  body {
    font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
    color: var(--ink);
    padding: 28px 16px 56px;
    text-align: center;
  }
  .hero {
    margin-bottom: 28px;
  }
  .hero .wave {
    display: block;
    margin: 0 auto 10px;
  }
  .hero .logo {
    display: block;
    width: min(280px, 78vw);
    height: auto;
    margin: 0 auto 18px;
  }
  h1 {
    color: var(--green-deep);
    font-weight: 600;
    font-size: 1.55rem;
    margin: 0 0 6px;
  }
  .subtitle {
    color: var(--muted);
    font-size: 0.95rem;
  }
  .empty {
    color: var(--muted);
    margin-top: 24px;
  }
  ul.cards {
    list-style: none;
    max-width: 560px;
    margin: 0 auto;
    text-align: left;
  }
  ul.cards > li { margin-bottom: 14px; }
  .card {
    display: flex;
    gap: 14px;
    background: var(--card);
    border-radius: 16px;
    padding: 14px;
    box-shadow: 0 6px 20px rgba(46, 137, 93, 0.12);
    border: 1px solid rgba(46, 137, 93, 0.08);
  }
  .cover {
    width: 72px;
    height: 72px;
    border-radius: 12px;
    object-fit: cover;
    flex-shrink: 0;
    background: var(--mint-light);
  }
  .cover.placeholder {
    background: linear-gradient(145deg, var(--mint-light), var(--mint));
  }
  .meta { min-width: 0; flex: 1; align-self: center; }
  .title {
    font-size: 1.05rem;
    font-weight: 600;
    line-height: 1.3;
    word-break: break-word;
    color: var(--ink);
  }
  .links {
    margin-top: 8px;
    font-size: 0.88rem;
  }
  .links a {
    color: var(--green);
    text-decoration: none;
    font-weight: 600;
  }
  .links a:hover {
    text-decoration: underline;
    color: var(--green-deep);
  }
  .group .feed {
    margin-bottom: 0;
    border-radius: 16px 16px 0 0;
  }
  .episodes {
    list-style: none;
    background: var(--card);
    border-radius: 0 0 16px 16px;
    margin-top: -2px;
    padding: 4px 14px 10px;
    box-shadow: 0 6px 20px rgba(46, 137, 93, 0.10);
    border: 1px solid rgba(46, 137, 93, 0.08);
    border-top: none;
  }
  .episode {
    border-top: 1px solid var(--line);
    padding: 10px 0;
  }
  .episode-title {
    font-size: 0.95rem;
    font-weight: 500;
    line-height: 1.35;
    word-break: break-word;
  }
  footer {
    margin-top: 40px;
    color: var(--muted);
    font-size: 0.85rem;
  }
  footer a {
    color: var(--green-deep);
    font-weight: 600;
    text-decoration: none;
  }
  footer a:hover { text-decoration: underline; }
</style>
</head>
<body>
  <header class="hero">
    <div class="wave">$_waveIconSvg</div>
    <img class="logo" src="$logoUri" alt="Podavio">
    <h1>$safeTitle</h1>
    <p class="subtitle">$safeSubtitle</p>
  </header>
  $body
  <footer>${DateTime.now().year} – <a href="https://podavio.com">podavio.com</a></footer>
</body>
</html>
''';
}

String _esc(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
