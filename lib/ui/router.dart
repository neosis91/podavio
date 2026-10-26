class AppRoutes {
  static const home = '/home';
  static const library = '/library';
  static const episodes = '/episodes';
  static const queue = '/queue';
  static const playlists = '/playlists';
  static const podcasts = '/podcasts';
  static const discover = '/discover';
  static const discoverMore = '/discover/more';
  static const discoverLanguages = '/discover-languages';
  static const preferences = '/preferences';
  static const sync = '/preferences/sync';
  static const webCompanion = '/preferences/web';
  static const favorites = '/favorites';
  static const history = '/history';
  static const downloads = '/downloads';
  static const appearance = '/appearance';
  static const languages = '/languages';
  static const interfaceLanguage = '/appearance/language';
  static const playback = '/playback';
  static const downloadSettings = '/download-settings';
  static const network = '/network';
  static const notifications = '/notifications';
  static const about = '/about';
  static const nearbyShare = '/about/nearby-share';
  static const licenses = '/licenses';
  static const backupRestore = '/backup-restore';
  static const stats = '/stats';
  static const opmlImport = '/preferences/opml-import';
  static const player = '/player';

  static String podcast(int id) => '/podcasts/$id';

  static String podcastAbout(int id) => '/podcasts/$id/about';

  static String podcastSettings(int id) => '/podcasts/$id/settings';

  static String episode(int id) => '/episode/$id';

  static String playlist(int id) => '/playlists/$id';
}
