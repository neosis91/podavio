class AppRoutes {
  static const episodes = '/episodes';
  static const queue = '/queue';
  static const podcasts = '/podcasts';
  static const discover = '/discover';
  static const more = '/more';
  static const favorites = '/favorites';
  static const history = '/history';
  static const downloads = '/downloads';
  static const settings = '/settings';
  static const player = '/player';

  static String podcast(int id) => '/podcasts/$id';
}
