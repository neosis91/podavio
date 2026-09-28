import 'package:flutter/material.dart';

import 'router.dart';

class NavPage {
  const NavPage(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const navPages = <NavPage>[
  NavPage(AppRoutes.home, 'Accueil', Icons.home_outlined, Icons.home),
  NavPage(
    AppRoutes.episodes,
    'Épisodes',
    Icons.podcasts_outlined,
    Icons.podcasts,
  ),
  NavPage(
    AppRoutes.queue,
    'File',
    Icons.queue_music_outlined,
    Icons.queue_music,
  ),
  NavPage(
    AppRoutes.podcasts,
    'Abonnements',
    Icons.grid_view_outlined,
    Icons.grid_view,
  ),
  NavPage(
    AppRoutes.discover,
    'Explorer',
    Icons.explore_outlined,
    Icons.explore,
  ),
  NavPage(AppRoutes.history, 'Historique', Icons.history, Icons.history),
  NavPage(
    AppRoutes.favorites,
    'Favoris',
    Icons.favorite_outline,
    Icons.favorite,
  ),
  NavPage(
    AppRoutes.downloads,
    'Téléchargements',
    Icons.download_outlined,
    Icons.download,
  ),
  NavPage(
    AppRoutes.preferences,
    'Préférences',
    Icons.tune_outlined,
    Icons.tune,
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
