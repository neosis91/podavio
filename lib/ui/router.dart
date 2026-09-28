class AppRoutes {
  static const home = '/home';
  static const episodes = '/episodes';
  static const queue = '/queue';
  static const podcasts = '/podcasts';
  static const discover = '/discover';
  static const preferences = '/preferences';
  static const favorites = '/favorites';
  static const history = '/history';
  static const downloads = '/downloads';
  static const appearance = '/appearance';
  static const playback = '/playback';
  static const player = '/player';

  static String podcast(int id) => '/podcasts/$id';
}
