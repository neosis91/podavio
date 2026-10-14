import 'package:flutter/material.dart';

import 'router.dart';
import 'widgets/brand.dart';

typedef NavIconBuilder = Widget Function({required Color color, double size});

NavIconBuilder _material(IconData data) {
  return ({required Color color, double size = 24}) =>
      Icon(data, color: color, size: size);
}

class NavPage {
  const NavPage(this.path, this.label, this.icon, [this.selectedIcon]);

  final String path;
  final String label;
  final NavIconBuilder icon;
  final NavIconBuilder? selectedIcon;

  Widget buildIcon({
    required Color color,
    double size = 24,
    bool selected = false,
  }) {
    final builder = selected ? (selectedIcon ?? icon) : icon;
    return builder(color: color, size: size);
  }
}

final navPages = <NavPage>[
  NavPage(
    AppRoutes.home,
    'Accueil',
    _material(Icons.home_outlined),
    _material(Icons.home),
  ),
  NavPage(
    AppRoutes.episodes,
    'Épisodes',
    _material(Icons.podcasts_outlined),
    _material(Icons.podcasts),
  ),
  NavPage(
    AppRoutes.queue,
    'Playlist',
    ({required Color color, double size = 24}) => IconTheme(
      data: IconThemeData(color: color, size: size),
      child: PlaylistPlayIcon(size: size),
    ),
  ),
  NavPage(
    AppRoutes.podcasts,
    'Abonnements',
    ({required Color color, double size = 24}) => IconTheme(
      data: IconThemeData(color: color, size: size),
      child: SubscriptionsIcon(size: size),
    ),
  ),
  NavPage(
    AppRoutes.discover,
    'Explorer',
    _material(Icons.explore_outlined),
    _material(Icons.explore),
  ),
  NavPage(AppRoutes.history, 'Lectures récentes', _material(Icons.history)),
  NavPage(
    AppRoutes.favorites,
    'Favoris',
    _material(Icons.favorite_outline),
    _material(Icons.favorite),
  ),
  NavPage(
    AppRoutes.playlists,
    'Playlists',
    _material(Icons.playlist_play_outlined),
    _material(Icons.playlist_play),
  ),
  NavPage(
    AppRoutes.downloads,
    'Téléchargements',
    _material(Icons.download_outlined),
    _material(Icons.download),
  ),
  NavPage(
    AppRoutes.stats,
    'Statistiques',
    _material(Icons.insights_outlined),
    _material(Icons.insights),
  ),
  NavPage(
    AppRoutes.preferences,
    'Préférences',
    _material(Icons.tune_outlined),
    _material(Icons.tune),
  ),
];

List<String> get defaultNavOrder => [for (final page in navPages) page.path];

List<String> normalizeNavOrder(List<String>? stored) {
  final known = defaultNavOrder.toSet();
  final seen = <String>{};
  final order = <String>[];
  for (final path in stored ?? const <String>[]) {
    if (known.contains(path) && seen.add(path)) order.add(path);
  }
  for (final path in defaultNavOrder) {
    if (seen.add(path)) order.add(path);
  }
  return order;
}

NavPage? navPageByPath(String path) {
  for (final page in navPages) {
    if (page.path == path) return page;
  }
  return null;
}
