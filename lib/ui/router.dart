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
  static const downloadSettings = '/download-settings';
  static const about = '/about';
  static const licenses = '/licenses';
  static const backupRestore = '/backup-restore';
  static const stats = '/stats';
  static const opmlImport = '/preferences/opml-import';
  static const player = '/player';

  static String podcast(int id) => '/podcasts/$id';

  static String episode(int id) => '/episode/$id';
}
