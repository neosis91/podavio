// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PodcastsTable extends Podcasts with TableInfo<$PodcastsTable, Podcast> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PodcastsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _feedUrlMeta = const VerificationMeta(
    'feedUrl',
  );
  @override
  late final GeneratedColumn<String> feedUrl = GeneratedColumn<String>(
    'feed_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleFoldMeta = const VerificationMeta(
    'titleFold',
  );
  @override
  late final GeneratedColumn<String> titleFold = GeneratedColumn<String>(
    'title_fold',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
    'link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subscribedAtMeta = const VerificationMeta(
    'subscribedAt',
  );
  @override
  late final GeneratedColumn<DateTime> subscribedAt = GeneratedColumn<DateTime>(
    'subscribed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refreshedAtMeta = const VerificationMeta(
    'refreshedAt',
  );
  @override
  late final GeneratedColumn<DateTime> refreshedAt = GeneratedColumn<DateTime>(
    'refreshed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferredMeta = const VerificationMeta(
    'preferred',
  );
  @override
  late final GeneratedColumn<bool> preferred = GeneratedColumn<bool>(
    'preferred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("preferred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _autoDownloadMeta = const VerificationMeta(
    'autoDownload',
  );
  @override
  late final GeneratedColumn<bool> autoDownload = GeneratedColumn<bool>(
    'auto_download',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_download" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _autoDownloadLimitMeta = const VerificationMeta(
    'autoDownloadLimit',
  );
  @override
  late final GeneratedColumn<int> autoDownloadLimit = GeneratedColumn<int>(
    'auto_download_limit',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _keepUpdatedMeta = const VerificationMeta(
    'keepUpdated',
  );
  @override
  late final GeneratedColumn<bool> keepUpdated = GeneratedColumn<bool>(
    'keep_updated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_updated" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _episodeNotificationMeta =
      const VerificationMeta('episodeNotification');
  @override
  late final GeneratedColumn<bool> episodeNotification = GeneratedColumn<bool>(
    'episode_notification',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("episode_notification" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _subscribedMeta = const VerificationMeta(
    'subscribed',
  );
  @override
  late final GeneratedColumn<bool> subscribed = GeneratedColumn<bool>(
    'subscribed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("subscribed" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _playbackSpeedMeta = const VerificationMeta(
    'playbackSpeed',
  );
  @override
  late final GeneratedColumn<double> playbackSpeed = GeneratedColumn<double>(
    'playback_speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skipIntroSecondsMeta = const VerificationMeta(
    'skipIntroSeconds',
  );
  @override
  late final GeneratedColumn<int> skipIntroSeconds = GeneratedColumn<int>(
    'skip_intro_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _skipOutroSecondsMeta = const VerificationMeta(
    'skipOutroSeconds',
  );
  @override
  late final GeneratedColumn<int> skipOutroSeconds = GeneratedColumn<int>(
    'skip_outro_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _authUsernameMeta = const VerificationMeta(
    'authUsername',
  );
  @override
  late final GeneratedColumn<String> authUsername = GeneratedColumn<String>(
    'auth_username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authPasswordMeta = const VerificationMeta(
    'authPassword',
  );
  @override
  late final GeneratedColumn<String> authPassword = GeneratedColumn<String>(
    'auth_password',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _personsJsonMeta = const VerificationMeta(
    'personsJson',
  );
  @override
  late final GeneratedColumn<String> personsJson = GeneratedColumn<String>(
    'persons_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _fundingJsonMeta = const VerificationMeta(
    'fundingJson',
  );
  @override
  late final GeneratedColumn<String> fundingJson = GeneratedColumn<String>(
    'funding_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _categoriesJsonMeta = const VerificationMeta(
    'categoriesJson',
  );
  @override
  late final GeneratedColumn<String> categoriesJson = GeneratedColumn<String>(
    'categories_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoSkipAdsMeta = const VerificationMeta(
    'autoSkipAds',
  );
  @override
  late final GeneratedColumn<bool> autoSkipAds = GeneratedColumn<bool>(
    'auto_skip_ads',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_skip_ads" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _autoSkipKindsMeta = const VerificationMeta(
    'autoSkipKinds',
  );
  @override
  late final GeneratedColumn<String> autoSkipKinds = GeneratedColumn<String>(
    'auto_skip_kinds',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    feedUrl,
    title,
    titleFold,
    author,
    description,
    imageUrl,
    imagePath,
    link,
    subscribedAt,
    refreshedAt,
    preferred,
    autoDownload,
    autoDownloadLimit,
    keepUpdated,
    episodeNotification,
    subscribed,
    playbackSpeed,
    skipIntroSeconds,
    skipOutroSeconds,
    authUsername,
    authPassword,
    personsJson,
    fundingJson,
    categoriesJson,
    autoSkipAds,
    autoSkipKinds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'podcasts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Podcast> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('feed_url')) {
      context.handle(
        _feedUrlMeta,
        feedUrl.isAcceptableOrUnknown(data['feed_url']!, _feedUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_feedUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('title_fold')) {
      context.handle(
        _titleFoldMeta,
        titleFold.isAcceptableOrUnknown(data['title_fold']!, _titleFoldMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('link')) {
      context.handle(
        _linkMeta,
        link.isAcceptableOrUnknown(data['link']!, _linkMeta),
      );
    }
    if (data.containsKey('subscribed_at')) {
      context.handle(
        _subscribedAtMeta,
        subscribedAt.isAcceptableOrUnknown(
          data['subscribed_at']!,
          _subscribedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subscribedAtMeta);
    }
    if (data.containsKey('refreshed_at')) {
      context.handle(
        _refreshedAtMeta,
        refreshedAt.isAcceptableOrUnknown(
          data['refreshed_at']!,
          _refreshedAtMeta,
        ),
      );
    }
    if (data.containsKey('preferred')) {
      context.handle(
        _preferredMeta,
        preferred.isAcceptableOrUnknown(data['preferred']!, _preferredMeta),
      );
    }
    if (data.containsKey('auto_download')) {
      context.handle(
        _autoDownloadMeta,
        autoDownload.isAcceptableOrUnknown(
          data['auto_download']!,
          _autoDownloadMeta,
        ),
      );
    }
    if (data.containsKey('auto_download_limit')) {
      context.handle(
        _autoDownloadLimitMeta,
        autoDownloadLimit.isAcceptableOrUnknown(
          data['auto_download_limit']!,
          _autoDownloadLimitMeta,
        ),
      );
    }
    if (data.containsKey('keep_updated')) {
      context.handle(
        _keepUpdatedMeta,
        keepUpdated.isAcceptableOrUnknown(
          data['keep_updated']!,
          _keepUpdatedMeta,
        ),
      );
    }
    if (data.containsKey('episode_notification')) {
      context.handle(
        _episodeNotificationMeta,
        episodeNotification.isAcceptableOrUnknown(
          data['episode_notification']!,
          _episodeNotificationMeta,
        ),
      );
    }
    if (data.containsKey('subscribed')) {
      context.handle(
        _subscribedMeta,
        subscribed.isAcceptableOrUnknown(data['subscribed']!, _subscribedMeta),
      );
    }
    if (data.containsKey('playback_speed')) {
      context.handle(
        _playbackSpeedMeta,
        playbackSpeed.isAcceptableOrUnknown(
          data['playback_speed']!,
          _playbackSpeedMeta,
        ),
      );
    }
    if (data.containsKey('skip_intro_seconds')) {
      context.handle(
        _skipIntroSecondsMeta,
        skipIntroSeconds.isAcceptableOrUnknown(
          data['skip_intro_seconds']!,
          _skipIntroSecondsMeta,
        ),
      );
    }
    if (data.containsKey('skip_outro_seconds')) {
      context.handle(
        _skipOutroSecondsMeta,
        skipOutroSeconds.isAcceptableOrUnknown(
          data['skip_outro_seconds']!,
          _skipOutroSecondsMeta,
        ),
      );
    }
    if (data.containsKey('auth_username')) {
      context.handle(
        _authUsernameMeta,
        authUsername.isAcceptableOrUnknown(
          data['auth_username']!,
          _authUsernameMeta,
        ),
      );
    }
    if (data.containsKey('auth_password')) {
      context.handle(
        _authPasswordMeta,
        authPassword.isAcceptableOrUnknown(
          data['auth_password']!,
          _authPasswordMeta,
        ),
      );
    }
    if (data.containsKey('persons_json')) {
      context.handle(
        _personsJsonMeta,
        personsJson.isAcceptableOrUnknown(
          data['persons_json']!,
          _personsJsonMeta,
        ),
      );
    }
    if (data.containsKey('funding_json')) {
      context.handle(
        _fundingJsonMeta,
        fundingJson.isAcceptableOrUnknown(
          data['funding_json']!,
          _fundingJsonMeta,
        ),
      );
    }
    if (data.containsKey('categories_json')) {
      context.handle(
        _categoriesJsonMeta,
        categoriesJson.isAcceptableOrUnknown(
          data['categories_json']!,
          _categoriesJsonMeta,
        ),
      );
    }
    if (data.containsKey('auto_skip_ads')) {
      context.handle(
        _autoSkipAdsMeta,
        autoSkipAds.isAcceptableOrUnknown(
          data['auto_skip_ads']!,
          _autoSkipAdsMeta,
        ),
      );
    }
    if (data.containsKey('auto_skip_kinds')) {
      context.handle(
        _autoSkipKindsMeta,
        autoSkipKinds.isAcceptableOrUnknown(
          data['auto_skip_kinds']!,
          _autoSkipKindsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Podcast map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Podcast(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      feedUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feed_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleFold: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_fold'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      link: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link'],
      ),
      subscribedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}subscribed_at'],
      )!,
      refreshedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}refreshed_at'],
      ),
      preferred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}preferred'],
      )!,
      autoDownload: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_download'],
      )!,
      autoDownloadLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_download_limit'],
      ),
      keepUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_updated'],
      )!,
      episodeNotification: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}episode_notification'],
      )!,
      subscribed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}subscribed'],
      )!,
      playbackSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}playback_speed'],
      ),
      skipIntroSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skip_intro_seconds'],
      )!,
      skipOutroSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skip_outro_seconds'],
      )!,
      authUsername: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_username'],
      ),
      authPassword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_password'],
      ),
      personsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persons_json'],
      )!,
      fundingJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}funding_json'],
      )!,
      categoriesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories_json'],
      ),
      autoSkipAds: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_skip_ads'],
      )!,
      autoSkipKinds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auto_skip_kinds'],
      )!,
    );
  }

  @override
  $PodcastsTable createAlias(String alias) {
    return $PodcastsTable(attachedDatabase, alias);
  }
}

class Podcast extends DataClass implements Insertable<Podcast> {
  final int id;
  final String feedUrl;
  final String title;

  /// [title] plié par [foldForSearch], pour la recherche SQL.
  final String titleFold;
  final String author;
  final String description;
  final String? imageUrl;
  final String? imagePath;
  final String? link;
  final DateTime subscribedAt;
  final DateTime? refreshedAt;
  final bool preferred;
  final bool autoDownload;

  /// Plafond d’épisodes de ce podcast. `null` = illimité. Défaut : 1.
  final int? autoDownloadLimit;
  final bool keepUpdated;

  /// Prévient quand un épisode paraît. Coupé au départ, comme AntennaPod.
  final bool episodeNotification;

  /// false = aperçu (Explorer) : épisodes utilisables, hors bibliothèque.
  final bool subscribed;

  /// Vitesse de lecture propre au podcast ; `null` = défaut global des réglages.
  final double? playbackSpeed;

  /// Secondes ignorées au début de chaque épisode (0 = désactivé).
  final int skipIntroSeconds;

  /// Secondes ignorées à la fin de chaque épisode (0 = désactivé).
  final int skipOutroSeconds;

  /// Identifiant HTTP Basic du flux. `null` = pas d’authentification.
  final String? authUsername;

  /// Mot de passe HTTP Basic du flux. `null` = pas d’authentification.
  final String? authPassword;

  /// Personnes du flux (`podcast:person`), JSON.
  final String personsJson;

  /// Liens de financement (`podcast:funding`), JSON.
  final String fundingJson;

  /// Genres du flux (`itunes:category`, `podcast:category`). `null` : pas encore lus.
  final String? categoriesJson;

  /// Saute pubs et jingles détectés dans les épisodes téléchargés.
  final bool autoSkipAds;

  /// JSON : noms de [SkipSegmentKind] sautés quand [autoSkipAds] est actif.
  final String autoSkipKinds;
  const Podcast({
    required this.id,
    required this.feedUrl,
    required this.title,
    required this.titleFold,
    required this.author,
    required this.description,
    this.imageUrl,
    this.imagePath,
    this.link,
    required this.subscribedAt,
    this.refreshedAt,
    required this.preferred,
    required this.autoDownload,
    this.autoDownloadLimit,
    required this.keepUpdated,
    required this.episodeNotification,
    required this.subscribed,
    this.playbackSpeed,
    required this.skipIntroSeconds,
    required this.skipOutroSeconds,
    this.authUsername,
    this.authPassword,
    required this.personsJson,
    required this.fundingJson,
    this.categoriesJson,
    required this.autoSkipAds,
    required this.autoSkipKinds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['feed_url'] = Variable<String>(feedUrl);
    map['title'] = Variable<String>(title);
    map['title_fold'] = Variable<String>(titleFold);
    map['author'] = Variable<String>(author);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || link != null) {
      map['link'] = Variable<String>(link);
    }
    map['subscribed_at'] = Variable<DateTime>(subscribedAt);
    if (!nullToAbsent || refreshedAt != null) {
      map['refreshed_at'] = Variable<DateTime>(refreshedAt);
    }
    map['preferred'] = Variable<bool>(preferred);
    map['auto_download'] = Variable<bool>(autoDownload);
    if (!nullToAbsent || autoDownloadLimit != null) {
      map['auto_download_limit'] = Variable<int>(autoDownloadLimit);
    }
    map['keep_updated'] = Variable<bool>(keepUpdated);
    map['episode_notification'] = Variable<bool>(episodeNotification);
    map['subscribed'] = Variable<bool>(subscribed);
    if (!nullToAbsent || playbackSpeed != null) {
      map['playback_speed'] = Variable<double>(playbackSpeed);
    }
    map['skip_intro_seconds'] = Variable<int>(skipIntroSeconds);
    map['skip_outro_seconds'] = Variable<int>(skipOutroSeconds);
    if (!nullToAbsent || authUsername != null) {
      map['auth_username'] = Variable<String>(authUsername);
    }
    if (!nullToAbsent || authPassword != null) {
      map['auth_password'] = Variable<String>(authPassword);
    }
    map['persons_json'] = Variable<String>(personsJson);
    map['funding_json'] = Variable<String>(fundingJson);
    if (!nullToAbsent || categoriesJson != null) {
      map['categories_json'] = Variable<String>(categoriesJson);
    }
    map['auto_skip_ads'] = Variable<bool>(autoSkipAds);
    map['auto_skip_kinds'] = Variable<String>(autoSkipKinds);
    return map;
  }

  PodcastsCompanion toCompanion(bool nullToAbsent) {
    return PodcastsCompanion(
      id: Value(id),
      feedUrl: Value(feedUrl),
      title: Value(title),
      titleFold: Value(titleFold),
      author: Value(author),
      description: Value(description),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      link: link == null && nullToAbsent ? const Value.absent() : Value(link),
      subscribedAt: Value(subscribedAt),
      refreshedAt: refreshedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(refreshedAt),
      preferred: Value(preferred),
      autoDownload: Value(autoDownload),
      autoDownloadLimit: autoDownloadLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(autoDownloadLimit),
      keepUpdated: Value(keepUpdated),
      episodeNotification: Value(episodeNotification),
      subscribed: Value(subscribed),
      playbackSpeed: playbackSpeed == null && nullToAbsent
          ? const Value.absent()
          : Value(playbackSpeed),
      skipIntroSeconds: Value(skipIntroSeconds),
      skipOutroSeconds: Value(skipOutroSeconds),
      authUsername: authUsername == null && nullToAbsent
          ? const Value.absent()
          : Value(authUsername),
      authPassword: authPassword == null && nullToAbsent
          ? const Value.absent()
          : Value(authPassword),
      personsJson: Value(personsJson),
      fundingJson: Value(fundingJson),
      categoriesJson: categoriesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(categoriesJson),
      autoSkipAds: Value(autoSkipAds),
      autoSkipKinds: Value(autoSkipKinds),
    );
  }

  factory Podcast.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Podcast(
      id: serializer.fromJson<int>(json['id']),
      feedUrl: serializer.fromJson<String>(json['feedUrl']),
      title: serializer.fromJson<String>(json['title']),
      titleFold: serializer.fromJson<String>(json['titleFold']),
      author: serializer.fromJson<String>(json['author']),
      description: serializer.fromJson<String>(json['description']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      link: serializer.fromJson<String?>(json['link']),
      subscribedAt: serializer.fromJson<DateTime>(json['subscribedAt']),
      refreshedAt: serializer.fromJson<DateTime?>(json['refreshedAt']),
      preferred: serializer.fromJson<bool>(json['preferred']),
      autoDownload: serializer.fromJson<bool>(json['autoDownload']),
      autoDownloadLimit: serializer.fromJson<int?>(json['autoDownloadLimit']),
      keepUpdated: serializer.fromJson<bool>(json['keepUpdated']),
      episodeNotification: serializer.fromJson<bool>(
        json['episodeNotification'],
      ),
      subscribed: serializer.fromJson<bool>(json['subscribed']),
      playbackSpeed: serializer.fromJson<double?>(json['playbackSpeed']),
      skipIntroSeconds: serializer.fromJson<int>(json['skipIntroSeconds']),
      skipOutroSeconds: serializer.fromJson<int>(json['skipOutroSeconds']),
      authUsername: serializer.fromJson<String?>(json['authUsername']),
      authPassword: serializer.fromJson<String?>(json['authPassword']),
      personsJson: serializer.fromJson<String>(json['personsJson']),
      fundingJson: serializer.fromJson<String>(json['fundingJson']),
      categoriesJson: serializer.fromJson<String?>(json['categoriesJson']),
      autoSkipAds: serializer.fromJson<bool>(json['autoSkipAds']),
      autoSkipKinds: serializer.fromJson<String>(json['autoSkipKinds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'feedUrl': serializer.toJson<String>(feedUrl),
      'title': serializer.toJson<String>(title),
      'titleFold': serializer.toJson<String>(titleFold),
      'author': serializer.toJson<String>(author),
      'description': serializer.toJson<String>(description),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'imagePath': serializer.toJson<String?>(imagePath),
      'link': serializer.toJson<String?>(link),
      'subscribedAt': serializer.toJson<DateTime>(subscribedAt),
      'refreshedAt': serializer.toJson<DateTime?>(refreshedAt),
      'preferred': serializer.toJson<bool>(preferred),
      'autoDownload': serializer.toJson<bool>(autoDownload),
      'autoDownloadLimit': serializer.toJson<int?>(autoDownloadLimit),
      'keepUpdated': serializer.toJson<bool>(keepUpdated),
      'episodeNotification': serializer.toJson<bool>(episodeNotification),
      'subscribed': serializer.toJson<bool>(subscribed),
      'playbackSpeed': serializer.toJson<double?>(playbackSpeed),
      'skipIntroSeconds': serializer.toJson<int>(skipIntroSeconds),
      'skipOutroSeconds': serializer.toJson<int>(skipOutroSeconds),
      'authUsername': serializer.toJson<String?>(authUsername),
      'authPassword': serializer.toJson<String?>(authPassword),
      'personsJson': serializer.toJson<String>(personsJson),
      'fundingJson': serializer.toJson<String>(fundingJson),
      'categoriesJson': serializer.toJson<String?>(categoriesJson),
      'autoSkipAds': serializer.toJson<bool>(autoSkipAds),
      'autoSkipKinds': serializer.toJson<String>(autoSkipKinds),
    };
  }

  Podcast copyWith({
    int? id,
    String? feedUrl,
    String? title,
    String? titleFold,
    String? author,
    String? description,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
    Value<String?> link = const Value.absent(),
    DateTime? subscribedAt,
    Value<DateTime?> refreshedAt = const Value.absent(),
    bool? preferred,
    bool? autoDownload,
    Value<int?> autoDownloadLimit = const Value.absent(),
    bool? keepUpdated,
    bool? episodeNotification,
    bool? subscribed,
    Value<double?> playbackSpeed = const Value.absent(),
    int? skipIntroSeconds,
    int? skipOutroSeconds,
    Value<String?> authUsername = const Value.absent(),
    Value<String?> authPassword = const Value.absent(),
    String? personsJson,
    String? fundingJson,
    Value<String?> categoriesJson = const Value.absent(),
    bool? autoSkipAds,
    String? autoSkipKinds,
  }) => Podcast(
    id: id ?? this.id,
    feedUrl: feedUrl ?? this.feedUrl,
    title: title ?? this.title,
    titleFold: titleFold ?? this.titleFold,
    author: author ?? this.author,
    description: description ?? this.description,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    link: link.present ? link.value : this.link,
    subscribedAt: subscribedAt ?? this.subscribedAt,
    refreshedAt: refreshedAt.present ? refreshedAt.value : this.refreshedAt,
    preferred: preferred ?? this.preferred,
    autoDownload: autoDownload ?? this.autoDownload,
    autoDownloadLimit: autoDownloadLimit.present
        ? autoDownloadLimit.value
        : this.autoDownloadLimit,
    keepUpdated: keepUpdated ?? this.keepUpdated,
    episodeNotification: episodeNotification ?? this.episodeNotification,
    subscribed: subscribed ?? this.subscribed,
    playbackSpeed: playbackSpeed.present
        ? playbackSpeed.value
        : this.playbackSpeed,
    skipIntroSeconds: skipIntroSeconds ?? this.skipIntroSeconds,
    skipOutroSeconds: skipOutroSeconds ?? this.skipOutroSeconds,
    authUsername: authUsername.present ? authUsername.value : this.authUsername,
    authPassword: authPassword.present ? authPassword.value : this.authPassword,
    personsJson: personsJson ?? this.personsJson,
    fundingJson: fundingJson ?? this.fundingJson,
    categoriesJson: categoriesJson.present
        ? categoriesJson.value
        : this.categoriesJson,
    autoSkipAds: autoSkipAds ?? this.autoSkipAds,
    autoSkipKinds: autoSkipKinds ?? this.autoSkipKinds,
  );
  Podcast copyWithCompanion(PodcastsCompanion data) {
    return Podcast(
      id: data.id.present ? data.id.value : this.id,
      feedUrl: data.feedUrl.present ? data.feedUrl.value : this.feedUrl,
      title: data.title.present ? data.title.value : this.title,
      titleFold: data.titleFold.present ? data.titleFold.value : this.titleFold,
      author: data.author.present ? data.author.value : this.author,
      description: data.description.present
          ? data.description.value
          : this.description,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      link: data.link.present ? data.link.value : this.link,
      subscribedAt: data.subscribedAt.present
          ? data.subscribedAt.value
          : this.subscribedAt,
      refreshedAt: data.refreshedAt.present
          ? data.refreshedAt.value
          : this.refreshedAt,
      preferred: data.preferred.present ? data.preferred.value : this.preferred,
      autoDownload: data.autoDownload.present
          ? data.autoDownload.value
          : this.autoDownload,
      autoDownloadLimit: data.autoDownloadLimit.present
          ? data.autoDownloadLimit.value
          : this.autoDownloadLimit,
      keepUpdated: data.keepUpdated.present
          ? data.keepUpdated.value
          : this.keepUpdated,
      episodeNotification: data.episodeNotification.present
          ? data.episodeNotification.value
          : this.episodeNotification,
      subscribed: data.subscribed.present
          ? data.subscribed.value
          : this.subscribed,
      playbackSpeed: data.playbackSpeed.present
          ? data.playbackSpeed.value
          : this.playbackSpeed,
      skipIntroSeconds: data.skipIntroSeconds.present
          ? data.skipIntroSeconds.value
          : this.skipIntroSeconds,
      skipOutroSeconds: data.skipOutroSeconds.present
          ? data.skipOutroSeconds.value
          : this.skipOutroSeconds,
      authUsername: data.authUsername.present
          ? data.authUsername.value
          : this.authUsername,
      authPassword: data.authPassword.present
          ? data.authPassword.value
          : this.authPassword,
      personsJson: data.personsJson.present
          ? data.personsJson.value
          : this.personsJson,
      fundingJson: data.fundingJson.present
          ? data.fundingJson.value
          : this.fundingJson,
      categoriesJson: data.categoriesJson.present
          ? data.categoriesJson.value
          : this.categoriesJson,
      autoSkipAds: data.autoSkipAds.present
          ? data.autoSkipAds.value
          : this.autoSkipAds,
      autoSkipKinds: data.autoSkipKinds.present
          ? data.autoSkipKinds.value
          : this.autoSkipKinds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Podcast(')
          ..write('id: $id, ')
          ..write('feedUrl: $feedUrl, ')
          ..write('title: $title, ')
          ..write('titleFold: $titleFold, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('imagePath: $imagePath, ')
          ..write('link: $link, ')
          ..write('subscribedAt: $subscribedAt, ')
          ..write('refreshedAt: $refreshedAt, ')
          ..write('preferred: $preferred, ')
          ..write('autoDownload: $autoDownload, ')
          ..write('autoDownloadLimit: $autoDownloadLimit, ')
          ..write('keepUpdated: $keepUpdated, ')
          ..write('episodeNotification: $episodeNotification, ')
          ..write('subscribed: $subscribed, ')
          ..write('playbackSpeed: $playbackSpeed, ')
          ..write('skipIntroSeconds: $skipIntroSeconds, ')
          ..write('skipOutroSeconds: $skipOutroSeconds, ')
          ..write('authUsername: $authUsername, ')
          ..write('authPassword: $authPassword, ')
          ..write('personsJson: $personsJson, ')
          ..write('fundingJson: $fundingJson, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('autoSkipAds: $autoSkipAds, ')
          ..write('autoSkipKinds: $autoSkipKinds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    feedUrl,
    title,
    titleFold,
    author,
    description,
    imageUrl,
    imagePath,
    link,
    subscribedAt,
    refreshedAt,
    preferred,
    autoDownload,
    autoDownloadLimit,
    keepUpdated,
    episodeNotification,
    subscribed,
    playbackSpeed,
    skipIntroSeconds,
    skipOutroSeconds,
    authUsername,
    authPassword,
    personsJson,
    fundingJson,
    categoriesJson,
    autoSkipAds,
    autoSkipKinds,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Podcast &&
          other.id == this.id &&
          other.feedUrl == this.feedUrl &&
          other.title == this.title &&
          other.titleFold == this.titleFold &&
          other.author == this.author &&
          other.description == this.description &&
          other.imageUrl == this.imageUrl &&
          other.imagePath == this.imagePath &&
          other.link == this.link &&
          other.subscribedAt == this.subscribedAt &&
          other.refreshedAt == this.refreshedAt &&
          other.preferred == this.preferred &&
          other.autoDownload == this.autoDownload &&
          other.autoDownloadLimit == this.autoDownloadLimit &&
          other.keepUpdated == this.keepUpdated &&
          other.episodeNotification == this.episodeNotification &&
          other.subscribed == this.subscribed &&
          other.playbackSpeed == this.playbackSpeed &&
          other.skipIntroSeconds == this.skipIntroSeconds &&
          other.skipOutroSeconds == this.skipOutroSeconds &&
          other.authUsername == this.authUsername &&
          other.authPassword == this.authPassword &&
          other.personsJson == this.personsJson &&
          other.fundingJson == this.fundingJson &&
          other.categoriesJson == this.categoriesJson &&
          other.autoSkipAds == this.autoSkipAds &&
          other.autoSkipKinds == this.autoSkipKinds);
}

class PodcastsCompanion extends UpdateCompanion<Podcast> {
  final Value<int> id;
  final Value<String> feedUrl;
  final Value<String> title;
  final Value<String> titleFold;
  final Value<String> author;
  final Value<String> description;
  final Value<String?> imageUrl;
  final Value<String?> imagePath;
  final Value<String?> link;
  final Value<DateTime> subscribedAt;
  final Value<DateTime?> refreshedAt;
  final Value<bool> preferred;
  final Value<bool> autoDownload;
  final Value<int?> autoDownloadLimit;
  final Value<bool> keepUpdated;
  final Value<bool> episodeNotification;
  final Value<bool> subscribed;
  final Value<double?> playbackSpeed;
  final Value<int> skipIntroSeconds;
  final Value<int> skipOutroSeconds;
  final Value<String?> authUsername;
  final Value<String?> authPassword;
  final Value<String> personsJson;
  final Value<String> fundingJson;
  final Value<String?> categoriesJson;
  final Value<bool> autoSkipAds;
  final Value<String> autoSkipKinds;
  const PodcastsCompanion({
    this.id = const Value.absent(),
    this.feedUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.titleFold = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.link = const Value.absent(),
    this.subscribedAt = const Value.absent(),
    this.refreshedAt = const Value.absent(),
    this.preferred = const Value.absent(),
    this.autoDownload = const Value.absent(),
    this.autoDownloadLimit = const Value.absent(),
    this.keepUpdated = const Value.absent(),
    this.episodeNotification = const Value.absent(),
    this.subscribed = const Value.absent(),
    this.playbackSpeed = const Value.absent(),
    this.skipIntroSeconds = const Value.absent(),
    this.skipOutroSeconds = const Value.absent(),
    this.authUsername = const Value.absent(),
    this.authPassword = const Value.absent(),
    this.personsJson = const Value.absent(),
    this.fundingJson = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    this.autoSkipAds = const Value.absent(),
    this.autoSkipKinds = const Value.absent(),
  });
  PodcastsCompanion.insert({
    this.id = const Value.absent(),
    required String feedUrl,
    required String title,
    this.titleFold = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.link = const Value.absent(),
    required DateTime subscribedAt,
    this.refreshedAt = const Value.absent(),
    this.preferred = const Value.absent(),
    this.autoDownload = const Value.absent(),
    this.autoDownloadLimit = const Value.absent(),
    this.keepUpdated = const Value.absent(),
    this.episodeNotification = const Value.absent(),
    this.subscribed = const Value.absent(),
    this.playbackSpeed = const Value.absent(),
    this.skipIntroSeconds = const Value.absent(),
    this.skipOutroSeconds = const Value.absent(),
    this.authUsername = const Value.absent(),
    this.authPassword = const Value.absent(),
    this.personsJson = const Value.absent(),
    this.fundingJson = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    this.autoSkipAds = const Value.absent(),
    this.autoSkipKinds = const Value.absent(),
  }) : feedUrl = Value(feedUrl),
       title = Value(title),
       subscribedAt = Value(subscribedAt);
  static Insertable<Podcast> custom({
    Expression<int>? id,
    Expression<String>? feedUrl,
    Expression<String>? title,
    Expression<String>? titleFold,
    Expression<String>? author,
    Expression<String>? description,
    Expression<String>? imageUrl,
    Expression<String>? imagePath,
    Expression<String>? link,
    Expression<DateTime>? subscribedAt,
    Expression<DateTime>? refreshedAt,
    Expression<bool>? preferred,
    Expression<bool>? autoDownload,
    Expression<int>? autoDownloadLimit,
    Expression<bool>? keepUpdated,
    Expression<bool>? episodeNotification,
    Expression<bool>? subscribed,
    Expression<double>? playbackSpeed,
    Expression<int>? skipIntroSeconds,
    Expression<int>? skipOutroSeconds,
    Expression<String>? authUsername,
    Expression<String>? authPassword,
    Expression<String>? personsJson,
    Expression<String>? fundingJson,
    Expression<String>? categoriesJson,
    Expression<bool>? autoSkipAds,
    Expression<String>? autoSkipKinds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (feedUrl != null) 'feed_url': feedUrl,
      if (title != null) 'title': title,
      if (titleFold != null) 'title_fold': titleFold,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      if (imagePath != null) 'image_path': imagePath,
      if (link != null) 'link': link,
      if (subscribedAt != null) 'subscribed_at': subscribedAt,
      if (refreshedAt != null) 'refreshed_at': refreshedAt,
      if (preferred != null) 'preferred': preferred,
      if (autoDownload != null) 'auto_download': autoDownload,
      if (autoDownloadLimit != null) 'auto_download_limit': autoDownloadLimit,
      if (keepUpdated != null) 'keep_updated': keepUpdated,
      if (episodeNotification != null)
        'episode_notification': episodeNotification,
      if (subscribed != null) 'subscribed': subscribed,
      if (playbackSpeed != null) 'playback_speed': playbackSpeed,
      if (skipIntroSeconds != null) 'skip_intro_seconds': skipIntroSeconds,
      if (skipOutroSeconds != null) 'skip_outro_seconds': skipOutroSeconds,
      if (authUsername != null) 'auth_username': authUsername,
      if (authPassword != null) 'auth_password': authPassword,
      if (personsJson != null) 'persons_json': personsJson,
      if (fundingJson != null) 'funding_json': fundingJson,
      if (categoriesJson != null) 'categories_json': categoriesJson,
      if (autoSkipAds != null) 'auto_skip_ads': autoSkipAds,
      if (autoSkipKinds != null) 'auto_skip_kinds': autoSkipKinds,
    });
  }

  PodcastsCompanion copyWith({
    Value<int>? id,
    Value<String>? feedUrl,
    Value<String>? title,
    Value<String>? titleFold,
    Value<String>? author,
    Value<String>? description,
    Value<String?>? imageUrl,
    Value<String?>? imagePath,
    Value<String?>? link,
    Value<DateTime>? subscribedAt,
    Value<DateTime?>? refreshedAt,
    Value<bool>? preferred,
    Value<bool>? autoDownload,
    Value<int?>? autoDownloadLimit,
    Value<bool>? keepUpdated,
    Value<bool>? episodeNotification,
    Value<bool>? subscribed,
    Value<double?>? playbackSpeed,
    Value<int>? skipIntroSeconds,
    Value<int>? skipOutroSeconds,
    Value<String?>? authUsername,
    Value<String?>? authPassword,
    Value<String>? personsJson,
    Value<String>? fundingJson,
    Value<String?>? categoriesJson,
    Value<bool>? autoSkipAds,
    Value<String>? autoSkipKinds,
  }) {
    return PodcastsCompanion(
      id: id ?? this.id,
      feedUrl: feedUrl ?? this.feedUrl,
      title: title ?? this.title,
      titleFold: titleFold ?? this.titleFold,
      author: author ?? this.author,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      link: link ?? this.link,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      refreshedAt: refreshedAt ?? this.refreshedAt,
      preferred: preferred ?? this.preferred,
      autoDownload: autoDownload ?? this.autoDownload,
      autoDownloadLimit: autoDownloadLimit ?? this.autoDownloadLimit,
      keepUpdated: keepUpdated ?? this.keepUpdated,
      episodeNotification: episodeNotification ?? this.episodeNotification,
      subscribed: subscribed ?? this.subscribed,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      skipIntroSeconds: skipIntroSeconds ?? this.skipIntroSeconds,
      skipOutroSeconds: skipOutroSeconds ?? this.skipOutroSeconds,
      authUsername: authUsername ?? this.authUsername,
      authPassword: authPassword ?? this.authPassword,
      personsJson: personsJson ?? this.personsJson,
      fundingJson: fundingJson ?? this.fundingJson,
      categoriesJson: categoriesJson ?? this.categoriesJson,
      autoSkipAds: autoSkipAds ?? this.autoSkipAds,
      autoSkipKinds: autoSkipKinds ?? this.autoSkipKinds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (feedUrl.present) {
      map['feed_url'] = Variable<String>(feedUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleFold.present) {
      map['title_fold'] = Variable<String>(titleFold.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (subscribedAt.present) {
      map['subscribed_at'] = Variable<DateTime>(subscribedAt.value);
    }
    if (refreshedAt.present) {
      map['refreshed_at'] = Variable<DateTime>(refreshedAt.value);
    }
    if (preferred.present) {
      map['preferred'] = Variable<bool>(preferred.value);
    }
    if (autoDownload.present) {
      map['auto_download'] = Variable<bool>(autoDownload.value);
    }
    if (autoDownloadLimit.present) {
      map['auto_download_limit'] = Variable<int>(autoDownloadLimit.value);
    }
    if (keepUpdated.present) {
      map['keep_updated'] = Variable<bool>(keepUpdated.value);
    }
    if (episodeNotification.present) {
      map['episode_notification'] = Variable<bool>(episodeNotification.value);
    }
    if (subscribed.present) {
      map['subscribed'] = Variable<bool>(subscribed.value);
    }
    if (playbackSpeed.present) {
      map['playback_speed'] = Variable<double>(playbackSpeed.value);
    }
    if (skipIntroSeconds.present) {
      map['skip_intro_seconds'] = Variable<int>(skipIntroSeconds.value);
    }
    if (skipOutroSeconds.present) {
      map['skip_outro_seconds'] = Variable<int>(skipOutroSeconds.value);
    }
    if (authUsername.present) {
      map['auth_username'] = Variable<String>(authUsername.value);
    }
    if (authPassword.present) {
      map['auth_password'] = Variable<String>(authPassword.value);
    }
    if (personsJson.present) {
      map['persons_json'] = Variable<String>(personsJson.value);
    }
    if (fundingJson.present) {
      map['funding_json'] = Variable<String>(fundingJson.value);
    }
    if (categoriesJson.present) {
      map['categories_json'] = Variable<String>(categoriesJson.value);
    }
    if (autoSkipAds.present) {
      map['auto_skip_ads'] = Variable<bool>(autoSkipAds.value);
    }
    if (autoSkipKinds.present) {
      map['auto_skip_kinds'] = Variable<String>(autoSkipKinds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PodcastsCompanion(')
          ..write('id: $id, ')
          ..write('feedUrl: $feedUrl, ')
          ..write('title: $title, ')
          ..write('titleFold: $titleFold, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('imagePath: $imagePath, ')
          ..write('link: $link, ')
          ..write('subscribedAt: $subscribedAt, ')
          ..write('refreshedAt: $refreshedAt, ')
          ..write('preferred: $preferred, ')
          ..write('autoDownload: $autoDownload, ')
          ..write('autoDownloadLimit: $autoDownloadLimit, ')
          ..write('keepUpdated: $keepUpdated, ')
          ..write('episodeNotification: $episodeNotification, ')
          ..write('subscribed: $subscribed, ')
          ..write('playbackSpeed: $playbackSpeed, ')
          ..write('skipIntroSeconds: $skipIntroSeconds, ')
          ..write('skipOutroSeconds: $skipOutroSeconds, ')
          ..write('authUsername: $authUsername, ')
          ..write('authPassword: $authPassword, ')
          ..write('personsJson: $personsJson, ')
          ..write('fundingJson: $fundingJson, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('autoSkipAds: $autoSkipAds, ')
          ..write('autoSkipKinds: $autoSkipKinds')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes with TableInfo<$EpisodesTable, Episode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _podcastIdMeta = const VerificationMeta(
    'podcastId',
  );
  @override
  late final GeneratedColumn<int> podcastId = GeneratedColumn<int>(
    'podcast_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES podcasts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _guidMeta = const VerificationMeta('guid');
  @override
  late final GeneratedColumn<String> guid = GeneratedColumn<String>(
    'guid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleFoldMeta = const VerificationMeta(
    'titleFold',
  );
  @override
  late final GeneratedColumn<String> titleFold = GeneratedColumn<String>(
    'title_fold',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _audioUrlMeta = const VerificationMeta(
    'audioUrl',
  );
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
    'audio_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _playedMeta = const VerificationMeta('played');
  @override
  late final GeneratedColumn<bool> played = GeneratedColumn<bool>(
    'played',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("played" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _downloadPathMeta = const VerificationMeta(
    'downloadPath',
  );
  @override
  late final GeneratedColumn<String> downloadPath = GeneratedColumn<String>(
    'download_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachePathMeta = const VerificationMeta(
    'cachePath',
  );
  @override
  late final GeneratedColumn<String> cachePath = GeneratedColumn<String>(
    'cache_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _queueIndexMeta = const VerificationMeta(
    'queueIndex',
  );
  @override
  late final GeneratedColumn<int> queueIndex = GeneratedColumn<int>(
    'queue_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chaptersUrlMeta = const VerificationMeta(
    'chaptersUrl',
  );
  @override
  late final GeneratedColumn<String> chaptersUrl = GeneratedColumn<String>(
    'chapters_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chaptersFetchedMeta = const VerificationMeta(
    'chaptersFetched',
  );
  @override
  late final GeneratedColumn<bool> chaptersFetched = GeneratedColumn<bool>(
    'chapters_fetched',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("chapters_fetched" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    podcastId,
    guid,
    title,
    titleFold,
    description,
    audioUrl,
    mimeType,
    durationSeconds,
    publishedAt,
    imageUrl,
    imagePath,
    positionMs,
    played,
    favorite,
    downloadPath,
    cachePath,
    queueIndex,
    lastPlayedAt,
    downloadedAt,
    chaptersUrl,
    chaptersFetched,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Episode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('podcast_id')) {
      context.handle(
        _podcastIdMeta,
        podcastId.isAcceptableOrUnknown(data['podcast_id']!, _podcastIdMeta),
      );
    } else if (isInserting) {
      context.missing(_podcastIdMeta);
    }
    if (data.containsKey('guid')) {
      context.handle(
        _guidMeta,
        guid.isAcceptableOrUnknown(data['guid']!, _guidMeta),
      );
    } else if (isInserting) {
      context.missing(_guidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('title_fold')) {
      context.handle(
        _titleFoldMeta,
        titleFold.isAcceptableOrUnknown(data['title_fold']!, _titleFoldMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('audio_url')) {
      context.handle(
        _audioUrlMeta,
        audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_audioUrlMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('played')) {
      context.handle(
        _playedMeta,
        played.isAcceptableOrUnknown(data['played']!, _playedMeta),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('download_path')) {
      context.handle(
        _downloadPathMeta,
        downloadPath.isAcceptableOrUnknown(
          data['download_path']!,
          _downloadPathMeta,
        ),
      );
    }
    if (data.containsKey('cache_path')) {
      context.handle(
        _cachePathMeta,
        cachePath.isAcceptableOrUnknown(data['cache_path']!, _cachePathMeta),
      );
    }
    if (data.containsKey('queue_index')) {
      context.handle(
        _queueIndexMeta,
        queueIndex.isAcceptableOrUnknown(data['queue_index']!, _queueIndexMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    if (data.containsKey('chapters_url')) {
      context.handle(
        _chaptersUrlMeta,
        chaptersUrl.isAcceptableOrUnknown(
          data['chapters_url']!,
          _chaptersUrlMeta,
        ),
      );
    }
    if (data.containsKey('chapters_fetched')) {
      context.handle(
        _chaptersFetchedMeta,
        chaptersFetched.isAcceptableOrUnknown(
          data['chapters_fetched']!,
          _chaptersFetchedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {podcastId, guid},
  ];
  @override
  Episode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Episode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      podcastId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}podcast_id'],
      )!,
      guid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleFold: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_fold'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      audioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_url'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      played: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}played'],
      )!,
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      downloadPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_path'],
      ),
      cachePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_path'],
      ),
      queueIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}queue_index'],
      ),
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      ),
      chaptersUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapters_url'],
      ),
      chaptersFetched: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}chapters_fetched'],
      )!,
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class Episode extends DataClass implements Insertable<Episode> {
  final int id;
  final int podcastId;
  final String guid;
  final String title;

  /// [title] plié par [foldForSearch], pour la recherche SQL.
  final String titleFold;
  final String description;
  final String audioUrl;
  final String? mimeType;
  final int? durationSeconds;
  final DateTime? publishedAt;
  final String? imageUrl;
  final String? imagePath;
  final int positionMs;
  final bool played;
  final bool favorite;
  final String? downloadPath;

  /// Fichier gardé pendant une lecture en streaming. Distinct d’un téléchargement.
  final String? cachePath;
  final int? queueIndex;
  final DateTime? lastPlayedAt;
  final DateTime? downloadedAt;
  final String? chaptersUrl;
  final bool chaptersFetched;
  const Episode({
    required this.id,
    required this.podcastId,
    required this.guid,
    required this.title,
    required this.titleFold,
    required this.description,
    required this.audioUrl,
    this.mimeType,
    this.durationSeconds,
    this.publishedAt,
    this.imageUrl,
    this.imagePath,
    required this.positionMs,
    required this.played,
    required this.favorite,
    this.downloadPath,
    this.cachePath,
    this.queueIndex,
    this.lastPlayedAt,
    this.downloadedAt,
    this.chaptersUrl,
    required this.chaptersFetched,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['podcast_id'] = Variable<int>(podcastId);
    map['guid'] = Variable<String>(guid);
    map['title'] = Variable<String>(title);
    map['title_fold'] = Variable<String>(titleFold);
    map['description'] = Variable<String>(description);
    map['audio_url'] = Variable<String>(audioUrl);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['position_ms'] = Variable<int>(positionMs);
    map['played'] = Variable<bool>(played);
    map['favorite'] = Variable<bool>(favorite);
    if (!nullToAbsent || downloadPath != null) {
      map['download_path'] = Variable<String>(downloadPath);
    }
    if (!nullToAbsent || cachePath != null) {
      map['cache_path'] = Variable<String>(cachePath);
    }
    if (!nullToAbsent || queueIndex != null) {
      map['queue_index'] = Variable<int>(queueIndex);
    }
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    }
    if (!nullToAbsent || chaptersUrl != null) {
      map['chapters_url'] = Variable<String>(chaptersUrl);
    }
    map['chapters_fetched'] = Variable<bool>(chaptersFetched);
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      id: Value(id),
      podcastId: Value(podcastId),
      guid: Value(guid),
      title: Value(title),
      titleFold: Value(titleFold),
      description: Value(description),
      audioUrl: Value(audioUrl),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      positionMs: Value(positionMs),
      played: Value(played),
      favorite: Value(favorite),
      downloadPath: downloadPath == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadPath),
      cachePath: cachePath == null && nullToAbsent
          ? const Value.absent()
          : Value(cachePath),
      queueIndex: queueIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(queueIndex),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
      chaptersUrl: chaptersUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(chaptersUrl),
      chaptersFetched: Value(chaptersFetched),
    );
  }

  factory Episode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Episode(
      id: serializer.fromJson<int>(json['id']),
      podcastId: serializer.fromJson<int>(json['podcastId']),
      guid: serializer.fromJson<String>(json['guid']),
      title: serializer.fromJson<String>(json['title']),
      titleFold: serializer.fromJson<String>(json['titleFold']),
      description: serializer.fromJson<String>(json['description']),
      audioUrl: serializer.fromJson<String>(json['audioUrl']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      played: serializer.fromJson<bool>(json['played']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      downloadPath: serializer.fromJson<String?>(json['downloadPath']),
      cachePath: serializer.fromJson<String?>(json['cachePath']),
      queueIndex: serializer.fromJson<int?>(json['queueIndex']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
      chaptersUrl: serializer.fromJson<String?>(json['chaptersUrl']),
      chaptersFetched: serializer.fromJson<bool>(json['chaptersFetched']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'podcastId': serializer.toJson<int>(podcastId),
      'guid': serializer.toJson<String>(guid),
      'title': serializer.toJson<String>(title),
      'titleFold': serializer.toJson<String>(titleFold),
      'description': serializer.toJson<String>(description),
      'audioUrl': serializer.toJson<String>(audioUrl),
      'mimeType': serializer.toJson<String?>(mimeType),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'imagePath': serializer.toJson<String?>(imagePath),
      'positionMs': serializer.toJson<int>(positionMs),
      'played': serializer.toJson<bool>(played),
      'favorite': serializer.toJson<bool>(favorite),
      'downloadPath': serializer.toJson<String?>(downloadPath),
      'cachePath': serializer.toJson<String?>(cachePath),
      'queueIndex': serializer.toJson<int?>(queueIndex),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
      'chaptersUrl': serializer.toJson<String?>(chaptersUrl),
      'chaptersFetched': serializer.toJson<bool>(chaptersFetched),
    };
  }

  Episode copyWith({
    int? id,
    int? podcastId,
    String? guid,
    String? title,
    String? titleFold,
    String? description,
    String? audioUrl,
    Value<String?> mimeType = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<DateTime?> publishedAt = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
    int? positionMs,
    bool? played,
    bool? favorite,
    Value<String?> downloadPath = const Value.absent(),
    Value<String?> cachePath = const Value.absent(),
    Value<int?> queueIndex = const Value.absent(),
    Value<DateTime?> lastPlayedAt = const Value.absent(),
    Value<DateTime?> downloadedAt = const Value.absent(),
    Value<String?> chaptersUrl = const Value.absent(),
    bool? chaptersFetched,
  }) => Episode(
    id: id ?? this.id,
    podcastId: podcastId ?? this.podcastId,
    guid: guid ?? this.guid,
    title: title ?? this.title,
    titleFold: titleFold ?? this.titleFold,
    description: description ?? this.description,
    audioUrl: audioUrl ?? this.audioUrl,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    positionMs: positionMs ?? this.positionMs,
    played: played ?? this.played,
    favorite: favorite ?? this.favorite,
    downloadPath: downloadPath.present ? downloadPath.value : this.downloadPath,
    cachePath: cachePath.present ? cachePath.value : this.cachePath,
    queueIndex: queueIndex.present ? queueIndex.value : this.queueIndex,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
    chaptersUrl: chaptersUrl.present ? chaptersUrl.value : this.chaptersUrl,
    chaptersFetched: chaptersFetched ?? this.chaptersFetched,
  );
  Episode copyWithCompanion(EpisodesCompanion data) {
    return Episode(
      id: data.id.present ? data.id.value : this.id,
      podcastId: data.podcastId.present ? data.podcastId.value : this.podcastId,
      guid: data.guid.present ? data.guid.value : this.guid,
      title: data.title.present ? data.title.value : this.title,
      titleFold: data.titleFold.present ? data.titleFold.value : this.titleFold,
      description: data.description.present
          ? data.description.value
          : this.description,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      played: data.played.present ? data.played.value : this.played,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      downloadPath: data.downloadPath.present
          ? data.downloadPath.value
          : this.downloadPath,
      cachePath: data.cachePath.present ? data.cachePath.value : this.cachePath,
      queueIndex: data.queueIndex.present
          ? data.queueIndex.value
          : this.queueIndex,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      chaptersUrl: data.chaptersUrl.present
          ? data.chaptersUrl.value
          : this.chaptersUrl,
      chaptersFetched: data.chaptersFetched.present
          ? data.chaptersFetched.value
          : this.chaptersFetched,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Episode(')
          ..write('id: $id, ')
          ..write('podcastId: $podcastId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('titleFold: $titleFold, ')
          ..write('description: $description, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('mimeType: $mimeType, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('imagePath: $imagePath, ')
          ..write('positionMs: $positionMs, ')
          ..write('played: $played, ')
          ..write('favorite: $favorite, ')
          ..write('downloadPath: $downloadPath, ')
          ..write('cachePath: $cachePath, ')
          ..write('queueIndex: $queueIndex, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('chaptersUrl: $chaptersUrl, ')
          ..write('chaptersFetched: $chaptersFetched')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    podcastId,
    guid,
    title,
    titleFold,
    description,
    audioUrl,
    mimeType,
    durationSeconds,
    publishedAt,
    imageUrl,
    imagePath,
    positionMs,
    played,
    favorite,
    downloadPath,
    cachePath,
    queueIndex,
    lastPlayedAt,
    downloadedAt,
    chaptersUrl,
    chaptersFetched,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Episode &&
          other.id == this.id &&
          other.podcastId == this.podcastId &&
          other.guid == this.guid &&
          other.title == this.title &&
          other.titleFold == this.titleFold &&
          other.description == this.description &&
          other.audioUrl == this.audioUrl &&
          other.mimeType == this.mimeType &&
          other.durationSeconds == this.durationSeconds &&
          other.publishedAt == this.publishedAt &&
          other.imageUrl == this.imageUrl &&
          other.imagePath == this.imagePath &&
          other.positionMs == this.positionMs &&
          other.played == this.played &&
          other.favorite == this.favorite &&
          other.downloadPath == this.downloadPath &&
          other.cachePath == this.cachePath &&
          other.queueIndex == this.queueIndex &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.downloadedAt == this.downloadedAt &&
          other.chaptersUrl == this.chaptersUrl &&
          other.chaptersFetched == this.chaptersFetched);
}

class EpisodesCompanion extends UpdateCompanion<Episode> {
  final Value<int> id;
  final Value<int> podcastId;
  final Value<String> guid;
  final Value<String> title;
  final Value<String> titleFold;
  final Value<String> description;
  final Value<String> audioUrl;
  final Value<String?> mimeType;
  final Value<int?> durationSeconds;
  final Value<DateTime?> publishedAt;
  final Value<String?> imageUrl;
  final Value<String?> imagePath;
  final Value<int> positionMs;
  final Value<bool> played;
  final Value<bool> favorite;
  final Value<String?> downloadPath;
  final Value<String?> cachePath;
  final Value<int?> queueIndex;
  final Value<DateTime?> lastPlayedAt;
  final Value<DateTime?> downloadedAt;
  final Value<String?> chaptersUrl;
  final Value<bool> chaptersFetched;
  const EpisodesCompanion({
    this.id = const Value.absent(),
    this.podcastId = const Value.absent(),
    this.guid = const Value.absent(),
    this.title = const Value.absent(),
    this.titleFold = const Value.absent(),
    this.description = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.played = const Value.absent(),
    this.favorite = const Value.absent(),
    this.downloadPath = const Value.absent(),
    this.cachePath = const Value.absent(),
    this.queueIndex = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.chaptersUrl = const Value.absent(),
    this.chaptersFetched = const Value.absent(),
  });
  EpisodesCompanion.insert({
    this.id = const Value.absent(),
    required int podcastId,
    required String guid,
    required String title,
    this.titleFold = const Value.absent(),
    this.description = const Value.absent(),
    required String audioUrl,
    this.mimeType = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.played = const Value.absent(),
    this.favorite = const Value.absent(),
    this.downloadPath = const Value.absent(),
    this.cachePath = const Value.absent(),
    this.queueIndex = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.chaptersUrl = const Value.absent(),
    this.chaptersFetched = const Value.absent(),
  }) : podcastId = Value(podcastId),
       guid = Value(guid),
       title = Value(title),
       audioUrl = Value(audioUrl);
  static Insertable<Episode> custom({
    Expression<int>? id,
    Expression<int>? podcastId,
    Expression<String>? guid,
    Expression<String>? title,
    Expression<String>? titleFold,
    Expression<String>? description,
    Expression<String>? audioUrl,
    Expression<String>? mimeType,
    Expression<int>? durationSeconds,
    Expression<DateTime>? publishedAt,
    Expression<String>? imageUrl,
    Expression<String>? imagePath,
    Expression<int>? positionMs,
    Expression<bool>? played,
    Expression<bool>? favorite,
    Expression<String>? downloadPath,
    Expression<String>? cachePath,
    Expression<int>? queueIndex,
    Expression<DateTime>? lastPlayedAt,
    Expression<DateTime>? downloadedAt,
    Expression<String>? chaptersUrl,
    Expression<bool>? chaptersFetched,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (podcastId != null) 'podcast_id': podcastId,
      if (guid != null) 'guid': guid,
      if (title != null) 'title': title,
      if (titleFold != null) 'title_fold': titleFold,
      if (description != null) 'description': description,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (mimeType != null) 'mime_type': mimeType,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (publishedAt != null) 'published_at': publishedAt,
      if (imageUrl != null) 'image_url': imageUrl,
      if (imagePath != null) 'image_path': imagePath,
      if (positionMs != null) 'position_ms': positionMs,
      if (played != null) 'played': played,
      if (favorite != null) 'favorite': favorite,
      if (downloadPath != null) 'download_path': downloadPath,
      if (cachePath != null) 'cache_path': cachePath,
      if (queueIndex != null) 'queue_index': queueIndex,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (chaptersUrl != null) 'chapters_url': chaptersUrl,
      if (chaptersFetched != null) 'chapters_fetched': chaptersFetched,
    });
  }

  EpisodesCompanion copyWith({
    Value<int>? id,
    Value<int>? podcastId,
    Value<String>? guid,
    Value<String>? title,
    Value<String>? titleFold,
    Value<String>? description,
    Value<String>? audioUrl,
    Value<String?>? mimeType,
    Value<int?>? durationSeconds,
    Value<DateTime?>? publishedAt,
    Value<String?>? imageUrl,
    Value<String?>? imagePath,
    Value<int>? positionMs,
    Value<bool>? played,
    Value<bool>? favorite,
    Value<String?>? downloadPath,
    Value<String?>? cachePath,
    Value<int?>? queueIndex,
    Value<DateTime?>? lastPlayedAt,
    Value<DateTime?>? downloadedAt,
    Value<String?>? chaptersUrl,
    Value<bool>? chaptersFetched,
  }) {
    return EpisodesCompanion(
      id: id ?? this.id,
      podcastId: podcastId ?? this.podcastId,
      guid: guid ?? this.guid,
      title: title ?? this.title,
      titleFold: titleFold ?? this.titleFold,
      description: description ?? this.description,
      audioUrl: audioUrl ?? this.audioUrl,
      mimeType: mimeType ?? this.mimeType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      publishedAt: publishedAt ?? this.publishedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      positionMs: positionMs ?? this.positionMs,
      played: played ?? this.played,
      favorite: favorite ?? this.favorite,
      downloadPath: downloadPath ?? this.downloadPath,
      cachePath: cachePath ?? this.cachePath,
      queueIndex: queueIndex ?? this.queueIndex,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      chaptersUrl: chaptersUrl ?? this.chaptersUrl,
      chaptersFetched: chaptersFetched ?? this.chaptersFetched,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (podcastId.present) {
      map['podcast_id'] = Variable<int>(podcastId.value);
    }
    if (guid.present) {
      map['guid'] = Variable<String>(guid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleFold.present) {
      map['title_fold'] = Variable<String>(titleFold.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (played.present) {
      map['played'] = Variable<bool>(played.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (downloadPath.present) {
      map['download_path'] = Variable<String>(downloadPath.value);
    }
    if (cachePath.present) {
      map['cache_path'] = Variable<String>(cachePath.value);
    }
    if (queueIndex.present) {
      map['queue_index'] = Variable<int>(queueIndex.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (chaptersUrl.present) {
      map['chapters_url'] = Variable<String>(chaptersUrl.value);
    }
    if (chaptersFetched.present) {
      map['chapters_fetched'] = Variable<bool>(chaptersFetched.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('id: $id, ')
          ..write('podcastId: $podcastId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('titleFold: $titleFold, ')
          ..write('description: $description, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('mimeType: $mimeType, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('imagePath: $imagePath, ')
          ..write('positionMs: $positionMs, ')
          ..write('played: $played, ')
          ..write('favorite: $favorite, ')
          ..write('downloadPath: $downloadPath, ')
          ..write('cachePath: $cachePath, ')
          ..write('queueIndex: $queueIndex, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('chaptersUrl: $chaptersUrl, ')
          ..write('chaptersFetched: $chaptersFetched')
          ..write(')'))
        .toString();
  }
}

class $EpisodeChaptersTable extends EpisodeChapters
    with TableInfo<$EpisodeChaptersTable, EpisodeChapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodeChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES episodes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
    'link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tocMeta = const VerificationMeta('toc');
  @override
  late final GeneratedColumn<bool> toc = GeneratedColumn<bool>(
    'toc',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("toc" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    episodeId,
    startMs,
    title,
    link,
    toc,
    sortIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episode_chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeChapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeIdMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('link')) {
      context.handle(
        _linkMeta,
        link.isAcceptableOrUnknown(data['link']!, _linkMeta),
      );
    }
    if (data.containsKey('toc')) {
      context.handle(
        _tocMeta,
        toc.isAcceptableOrUnknown(data['toc']!, _tocMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpisodeChapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeChapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      link: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link'],
      ),
      toc: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}toc'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  $EpisodeChaptersTable createAlias(String alias) {
    return $EpisodeChaptersTable(attachedDatabase, alias);
  }
}

class EpisodeChapter extends DataClass implements Insertable<EpisodeChapter> {
  final int id;
  final int episodeId;
  final int startMs;
  final String title;
  final String? link;
  final bool toc;
  final int sortIndex;
  const EpisodeChapter({
    required this.id,
    required this.episodeId,
    required this.startMs,
    required this.title,
    this.link,
    required this.toc,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['episode_id'] = Variable<int>(episodeId);
    map['start_ms'] = Variable<int>(startMs);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || link != null) {
      map['link'] = Variable<String>(link);
    }
    map['toc'] = Variable<bool>(toc);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  EpisodeChaptersCompanion toCompanion(bool nullToAbsent) {
    return EpisodeChaptersCompanion(
      id: Value(id),
      episodeId: Value(episodeId),
      startMs: Value(startMs),
      title: Value(title),
      link: link == null && nullToAbsent ? const Value.absent() : Value(link),
      toc: Value(toc),
      sortIndex: Value(sortIndex),
    );
  }

  factory EpisodeChapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeChapter(
      id: serializer.fromJson<int>(json['id']),
      episodeId: serializer.fromJson<int>(json['episodeId']),
      startMs: serializer.fromJson<int>(json['startMs']),
      title: serializer.fromJson<String>(json['title']),
      link: serializer.fromJson<String?>(json['link']),
      toc: serializer.fromJson<bool>(json['toc']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'episodeId': serializer.toJson<int>(episodeId),
      'startMs': serializer.toJson<int>(startMs),
      'title': serializer.toJson<String>(title),
      'link': serializer.toJson<String?>(link),
      'toc': serializer.toJson<bool>(toc),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  EpisodeChapter copyWith({
    int? id,
    int? episodeId,
    int? startMs,
    String? title,
    Value<String?> link = const Value.absent(),
    bool? toc,
    int? sortIndex,
  }) => EpisodeChapter(
    id: id ?? this.id,
    episodeId: episodeId ?? this.episodeId,
    startMs: startMs ?? this.startMs,
    title: title ?? this.title,
    link: link.present ? link.value : this.link,
    toc: toc ?? this.toc,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  EpisodeChapter copyWithCompanion(EpisodeChaptersCompanion data) {
    return EpisodeChapter(
      id: data.id.present ? data.id.value : this.id,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      title: data.title.present ? data.title.value : this.title,
      link: data.link.present ? data.link.value : this.link,
      toc: data.toc.present ? data.toc.value : this.toc,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeChapter(')
          ..write('id: $id, ')
          ..write('episodeId: $episodeId, ')
          ..write('startMs: $startMs, ')
          ..write('title: $title, ')
          ..write('link: $link, ')
          ..write('toc: $toc, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, episodeId, startMs, title, link, toc, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeChapter &&
          other.id == this.id &&
          other.episodeId == this.episodeId &&
          other.startMs == this.startMs &&
          other.title == this.title &&
          other.link == this.link &&
          other.toc == this.toc &&
          other.sortIndex == this.sortIndex);
}

class EpisodeChaptersCompanion extends UpdateCompanion<EpisodeChapter> {
  final Value<int> id;
  final Value<int> episodeId;
  final Value<int> startMs;
  final Value<String> title;
  final Value<String?> link;
  final Value<bool> toc;
  final Value<int> sortIndex;
  const EpisodeChaptersCompanion({
    this.id = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.startMs = const Value.absent(),
    this.title = const Value.absent(),
    this.link = const Value.absent(),
    this.toc = const Value.absent(),
    this.sortIndex = const Value.absent(),
  });
  EpisodeChaptersCompanion.insert({
    this.id = const Value.absent(),
    required int episodeId,
    required int startMs,
    this.title = const Value.absent(),
    this.link = const Value.absent(),
    this.toc = const Value.absent(),
    this.sortIndex = const Value.absent(),
  }) : episodeId = Value(episodeId),
       startMs = Value(startMs);
  static Insertable<EpisodeChapter> custom({
    Expression<int>? id,
    Expression<int>? episodeId,
    Expression<int>? startMs,
    Expression<String>? title,
    Expression<String>? link,
    Expression<bool>? toc,
    Expression<int>? sortIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (episodeId != null) 'episode_id': episodeId,
      if (startMs != null) 'start_ms': startMs,
      if (title != null) 'title': title,
      if (link != null) 'link': link,
      if (toc != null) 'toc': toc,
      if (sortIndex != null) 'sort_index': sortIndex,
    });
  }

  EpisodeChaptersCompanion copyWith({
    Value<int>? id,
    Value<int>? episodeId,
    Value<int>? startMs,
    Value<String>? title,
    Value<String?>? link,
    Value<bool>? toc,
    Value<int>? sortIndex,
  }) {
    return EpisodeChaptersCompanion(
      id: id ?? this.id,
      episodeId: episodeId ?? this.episodeId,
      startMs: startMs ?? this.startMs,
      title: title ?? this.title,
      link: link ?? this.link,
      toc: toc ?? this.toc,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (toc.present) {
      map['toc'] = Variable<bool>(toc.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeChaptersCompanion(')
          ..write('id: $id, ')
          ..write('episodeId: $episodeId, ')
          ..write('startMs: $startMs, ')
          ..write('title: $title, ')
          ..write('link: $link, ')
          ..write('toc: $toc, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }
}

class $PlaybackPositionsTable extends PlaybackPositions
    with TableInfo<$PlaybackPositionsTable, PlaybackPosition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES episodes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [episodeId, positionMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackPosition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {episodeId};
  @override
  PlaybackPosition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackPosition(
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
    );
  }

  @override
  $PlaybackPositionsTable createAlias(String alias) {
    return $PlaybackPositionsTable(attachedDatabase, alias);
  }
}

class PlaybackPosition extends DataClass
    implements Insertable<PlaybackPosition> {
  final int episodeId;
  final int positionMs;
  const PlaybackPosition({required this.episodeId, required this.positionMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['episode_id'] = Variable<int>(episodeId);
    map['position_ms'] = Variable<int>(positionMs);
    return map;
  }

  PlaybackPositionsCompanion toCompanion(bool nullToAbsent) {
    return PlaybackPositionsCompanion(
      episodeId: Value(episodeId),
      positionMs: Value(positionMs),
    );
  }

  factory PlaybackPosition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackPosition(
      episodeId: serializer.fromJson<int>(json['episodeId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'episodeId': serializer.toJson<int>(episodeId),
      'positionMs': serializer.toJson<int>(positionMs),
    };
  }

  PlaybackPosition copyWith({int? episodeId, int? positionMs}) =>
      PlaybackPosition(
        episodeId: episodeId ?? this.episodeId,
        positionMs: positionMs ?? this.positionMs,
      );
  PlaybackPosition copyWithCompanion(PlaybackPositionsCompanion data) {
    return PlaybackPosition(
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackPosition(')
          ..write('episodeId: $episodeId, ')
          ..write('positionMs: $positionMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(episodeId, positionMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackPosition &&
          other.episodeId == this.episodeId &&
          other.positionMs == this.positionMs);
}

class PlaybackPositionsCompanion extends UpdateCompanion<PlaybackPosition> {
  final Value<int> episodeId;
  final Value<int> positionMs;
  const PlaybackPositionsCompanion({
    this.episodeId = const Value.absent(),
    this.positionMs = const Value.absent(),
  });
  PlaybackPositionsCompanion.insert({
    this.episodeId = const Value.absent(),
    this.positionMs = const Value.absent(),
  });
  static Insertable<PlaybackPosition> custom({
    Expression<int>? episodeId,
    Expression<int>? positionMs,
  }) {
    return RawValuesInsertable({
      if (episodeId != null) 'episode_id': episodeId,
      if (positionMs != null) 'position_ms': positionMs,
    });
  }

  PlaybackPositionsCompanion copyWith({
    Value<int>? episodeId,
    Value<int>? positionMs,
  }) {
    return PlaybackPositionsCompanion(
      episodeId: episodeId ?? this.episodeId,
      positionMs: positionMs ?? this.positionMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackPositionsCompanion(')
          ..write('episodeId: $episodeId, ')
          ..write('positionMs: $positionMs')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, isDefault, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final int id;
  final String name;
  final bool isDefault;
  final DateTime createdAt;
  const Playlist({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Playlist copyWith({
    int? id,
    String? name,
    bool? isDefault,
    DateTime? createdAt,
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, isDefault, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.isDefault = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Playlist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistEpisodesTable extends PlaylistEpisodes
    with TableInfo<$PlaylistEpisodesTable, PlaylistEpisode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES episodes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [playlistId, episodeId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistEpisode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, episodeId};
  @override
  PlaylistEpisode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistEpisode(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlaylistEpisodesTable createAlias(String alias) {
    return $PlaylistEpisodesTable(attachedDatabase, alias);
  }
}

class PlaylistEpisode extends DataClass implements Insertable<PlaylistEpisode> {
  final int playlistId;
  final int episodeId;
  final int position;
  const PlaylistEpisode({
    required this.playlistId,
    required this.episodeId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['episode_id'] = Variable<int>(episodeId);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistEpisodesCompanion toCompanion(bool nullToAbsent) {
    return PlaylistEpisodesCompanion(
      playlistId: Value(playlistId),
      episodeId: Value(episodeId),
      position: Value(position),
    );
  }

  factory PlaylistEpisode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistEpisode(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      episodeId: serializer.fromJson<int>(json['episodeId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'episodeId': serializer.toJson<int>(episodeId),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistEpisode copyWith({int? playlistId, int? episodeId, int? position}) =>
      PlaylistEpisode(
        playlistId: playlistId ?? this.playlistId,
        episodeId: episodeId ?? this.episodeId,
        position: position ?? this.position,
      );
  PlaylistEpisode copyWithCompanion(PlaylistEpisodesCompanion data) {
    return PlaylistEpisode(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEpisode(')
          ..write('playlistId: $playlistId, ')
          ..write('episodeId: $episodeId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, episodeId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistEpisode &&
          other.playlistId == this.playlistId &&
          other.episodeId == this.episodeId &&
          other.position == this.position);
}

class PlaylistEpisodesCompanion extends UpdateCompanion<PlaylistEpisode> {
  final Value<int> playlistId;
  final Value<int> episodeId;
  final Value<int> position;
  final Value<int> rowid;
  const PlaylistEpisodesCompanion({
    this.playlistId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistEpisodesCompanion.insert({
    required int playlistId,
    required int episodeId,
    required int position,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       episodeId = Value(episodeId),
       position = Value(position);
  static Insertable<PlaylistEpisode> custom({
    Expression<int>? playlistId,
    Expression<int>? episodeId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (episodeId != null) 'episode_id': episodeId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistEpisodesCompanion copyWith({
    Value<int>? playlistId,
    Value<int>? episodeId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PlaylistEpisodesCompanion(
      playlistId: playlistId ?? this.playlistId,
      episodeId: episodeId ?? this.episodeId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEpisodesCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('episodeId: $episodeId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodeFingerprintsTable extends EpisodeFingerprints
    with TableInfo<$EpisodeFingerprintsTable, EpisodeFingerprint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodeFingerprintsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES episodes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<Uint8List> data = GeneratedColumn<Uint8List>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hopMicrosMeta = const VerificationMeta(
    'hopMicros',
  );
  @override
  late final GeneratedColumn<int> hopMicros = GeneratedColumn<int>(
    'hop_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speechMeta = const VerificationMeta('speech');
  @override
  late final GeneratedColumn<Uint8List> speech = GeneratedColumn<Uint8List>(
    'speech',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    episodeId,
    data,
    hopMicros,
    speech,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episode_fingerprints';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeFingerprint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('hop_micros')) {
      context.handle(
        _hopMicrosMeta,
        hopMicros.isAcceptableOrUnknown(data['hop_micros']!, _hopMicrosMeta),
      );
    } else if (isInserting) {
      context.missing(_hopMicrosMeta);
    }
    if (data.containsKey('speech')) {
      context.handle(
        _speechMeta,
        speech.isAcceptableOrUnknown(data['speech']!, _speechMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {episodeId};
  @override
  EpisodeFingerprint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeFingerprint(
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}data'],
      )!,
      hopMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hop_micros'],
      )!,
      speech: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}speech'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EpisodeFingerprintsTable createAlias(String alias) {
    return $EpisodeFingerprintsTable(attachedDatabase, alias);
  }
}

class EpisodeFingerprint extends DataClass
    implements Insertable<EpisodeFingerprint> {
  final int episodeId;

  /// Valeurs uint32, little-endian. Voir [encodeFingerprint].
  final Uint8List data;

  /// Écart entre deux valeurs, en microsecondes (~125000 pour 8/s).
  final int hopMicros;

  /// Une octet par seconde : 0 musique, 255 parole. `null` tant que
  /// l’épisode n’a pas été noté.
  final Uint8List? speech;
  final DateTime createdAt;
  const EpisodeFingerprint({
    required this.episodeId,
    required this.data,
    required this.hopMicros,
    this.speech,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['episode_id'] = Variable<int>(episodeId);
    map['data'] = Variable<Uint8List>(data);
    map['hop_micros'] = Variable<int>(hopMicros);
    if (!nullToAbsent || speech != null) {
      map['speech'] = Variable<Uint8List>(speech);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EpisodeFingerprintsCompanion toCompanion(bool nullToAbsent) {
    return EpisodeFingerprintsCompanion(
      episodeId: Value(episodeId),
      data: Value(data),
      hopMicros: Value(hopMicros),
      speech: speech == null && nullToAbsent
          ? const Value.absent()
          : Value(speech),
      createdAt: Value(createdAt),
    );
  }

  factory EpisodeFingerprint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeFingerprint(
      episodeId: serializer.fromJson<int>(json['episodeId']),
      data: serializer.fromJson<Uint8List>(json['data']),
      hopMicros: serializer.fromJson<int>(json['hopMicros']),
      speech: serializer.fromJson<Uint8List?>(json['speech']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'episodeId': serializer.toJson<int>(episodeId),
      'data': serializer.toJson<Uint8List>(data),
      'hopMicros': serializer.toJson<int>(hopMicros),
      'speech': serializer.toJson<Uint8List?>(speech),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EpisodeFingerprint copyWith({
    int? episodeId,
    Uint8List? data,
    int? hopMicros,
    Value<Uint8List?> speech = const Value.absent(),
    DateTime? createdAt,
  }) => EpisodeFingerprint(
    episodeId: episodeId ?? this.episodeId,
    data: data ?? this.data,
    hopMicros: hopMicros ?? this.hopMicros,
    speech: speech.present ? speech.value : this.speech,
    createdAt: createdAt ?? this.createdAt,
  );
  EpisodeFingerprint copyWithCompanion(EpisodeFingerprintsCompanion data) {
    return EpisodeFingerprint(
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      data: data.data.present ? data.data.value : this.data,
      hopMicros: data.hopMicros.present ? data.hopMicros.value : this.hopMicros,
      speech: data.speech.present ? data.speech.value : this.speech,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeFingerprint(')
          ..write('episodeId: $episodeId, ')
          ..write('data: $data, ')
          ..write('hopMicros: $hopMicros, ')
          ..write('speech: $speech, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    episodeId,
    $driftBlobEquality.hash(data),
    hopMicros,
    $driftBlobEquality.hash(speech),
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeFingerprint &&
          other.episodeId == this.episodeId &&
          $driftBlobEquality.equals(other.data, this.data) &&
          other.hopMicros == this.hopMicros &&
          $driftBlobEquality.equals(other.speech, this.speech) &&
          other.createdAt == this.createdAt);
}

class EpisodeFingerprintsCompanion extends UpdateCompanion<EpisodeFingerprint> {
  final Value<int> episodeId;
  final Value<Uint8List> data;
  final Value<int> hopMicros;
  final Value<Uint8List?> speech;
  final Value<DateTime> createdAt;
  const EpisodeFingerprintsCompanion({
    this.episodeId = const Value.absent(),
    this.data = const Value.absent(),
    this.hopMicros = const Value.absent(),
    this.speech = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EpisodeFingerprintsCompanion.insert({
    this.episodeId = const Value.absent(),
    required Uint8List data,
    required int hopMicros,
    this.speech = const Value.absent(),
    required DateTime createdAt,
  }) : data = Value(data),
       hopMicros = Value(hopMicros),
       createdAt = Value(createdAt);
  static Insertable<EpisodeFingerprint> custom({
    Expression<int>? episodeId,
    Expression<Uint8List>? data,
    Expression<int>? hopMicros,
    Expression<Uint8List>? speech,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (episodeId != null) 'episode_id': episodeId,
      if (data != null) 'data': data,
      if (hopMicros != null) 'hop_micros': hopMicros,
      if (speech != null) 'speech': speech,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EpisodeFingerprintsCompanion copyWith({
    Value<int>? episodeId,
    Value<Uint8List>? data,
    Value<int>? hopMicros,
    Value<Uint8List?>? speech,
    Value<DateTime>? createdAt,
  }) {
    return EpisodeFingerprintsCompanion(
      episodeId: episodeId ?? this.episodeId,
      data: data ?? this.data,
      hopMicros: hopMicros ?? this.hopMicros,
      speech: speech ?? this.speech,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (data.present) {
      map['data'] = Variable<Uint8List>(data.value);
    }
    if (hopMicros.present) {
      map['hop_micros'] = Variable<int>(hopMicros.value);
    }
    if (speech.present) {
      map['speech'] = Variable<Uint8List>(speech.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeFingerprintsCompanion(')
          ..write('episodeId: $episodeId, ')
          ..write('data: $data, ')
          ..write('hopMicros: $hopMicros, ')
          ..write('speech: $speech, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SegmentTemplatesTable extends SegmentTemplates
    with TableInfo<$SegmentTemplatesTable, SegmentTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SegmentTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _podcastIdMeta = const VerificationMeta(
    'podcastId',
  );
  @override
  late final GeneratedColumn<int> podcastId = GeneratedColumn<int>(
    'podcast_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES podcasts (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<SkipSegmentKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SkipSegmentKind>($SegmentTemplatesTable.$converterkind);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<Uint8List> fingerprint =
      GeneratedColumn<Uint8List>(
        'fingerprint',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _logMelMeta = const VerificationMeta('logMel');
  @override
  late final GeneratedColumn<Uint8List> logMel = GeneratedColumn<Uint8List>(
    'log_mel',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurrencesMeta = const VerificationMeta(
    'occurrences',
  );
  @override
  late final GeneratedColumn<int> occurrences = GeneratedColumn<int>(
    'occurrences',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<int> confidence = GeneratedColumn<int>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    podcastId,
    kind,
    label,
    fingerprint,
    logMel,
    durationMs,
    occurrences,
    confidence,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'segment_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<SegmentTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('podcast_id')) {
      context.handle(
        _podcastIdMeta,
        podcastId.isAcceptableOrUnknown(data['podcast_id']!, _podcastIdMeta),
      );
    } else if (isInserting) {
      context.missing(_podcastIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('log_mel')) {
      context.handle(
        _logMelMeta,
        logMel.isAcceptableOrUnknown(data['log_mel']!, _logMelMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('occurrences')) {
      context.handle(
        _occurrencesMeta,
        occurrences.isAcceptableOrUnknown(
          data['occurrences']!,
          _occurrencesMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SegmentTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SegmentTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      podcastId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}podcast_id'],
      )!,
      kind: $SegmentTemplatesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}fingerprint'],
      )!,
      logMel: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}log_mel'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      occurrences: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrences'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confidence'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SegmentTemplatesTable createAlias(String alias) {
    return $SegmentTemplatesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SkipSegmentKind, String, String> $converterkind =
      const EnumNameConverter<SkipSegmentKind>(SkipSegmentKind.values);
}

class SegmentTemplate extends DataClass implements Insertable<SegmentTemplate> {
  final int id;
  final int podcastId;
  final SkipSegmentKind kind;
  final String? label;

  /// Tranche Chromaprint du motif (uint32 little-endian).
  /// Les épisodes suivants ne sont comparés qu’à ce gabarit.
  final Uint8List fingerprint;

  /// Gabarit log-mel (float32 little-endian, 40 bandes). `null` tant
  /// que l’analyseur ne l’a pas calculé. Sons < 3 s et frontières.
  final Uint8List? logMel;
  final int durationMs;
  final int occurrences;

  /// 0–100. `null` : gabarit posé avant le score. Le saut n’en dépend pas.
  final int? confidence;
  final DateTime createdAt;
  const SegmentTemplate({
    required this.id,
    required this.podcastId,
    required this.kind,
    this.label,
    required this.fingerprint,
    this.logMel,
    required this.durationMs,
    required this.occurrences,
    this.confidence,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['podcast_id'] = Variable<int>(podcastId);
    {
      map['kind'] = Variable<String>(
        $SegmentTemplatesTable.$converterkind.toSql(kind),
      );
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['fingerprint'] = Variable<Uint8List>(fingerprint);
    if (!nullToAbsent || logMel != null) {
      map['log_mel'] = Variable<Uint8List>(logMel);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['occurrences'] = Variable<int>(occurrences);
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<int>(confidence);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SegmentTemplatesCompanion toCompanion(bool nullToAbsent) {
    return SegmentTemplatesCompanion(
      id: Value(id),
      podcastId: Value(podcastId),
      kind: Value(kind),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      fingerprint: Value(fingerprint),
      logMel: logMel == null && nullToAbsent
          ? const Value.absent()
          : Value(logMel),
      durationMs: Value(durationMs),
      occurrences: Value(occurrences),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      createdAt: Value(createdAt),
    );
  }

  factory SegmentTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SegmentTemplate(
      id: serializer.fromJson<int>(json['id']),
      podcastId: serializer.fromJson<int>(json['podcastId']),
      kind: $SegmentTemplatesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      label: serializer.fromJson<String?>(json['label']),
      fingerprint: serializer.fromJson<Uint8List>(json['fingerprint']),
      logMel: serializer.fromJson<Uint8List?>(json['logMel']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      occurrences: serializer.fromJson<int>(json['occurrences']),
      confidence: serializer.fromJson<int?>(json['confidence']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'podcastId': serializer.toJson<int>(podcastId),
      'kind': serializer.toJson<String>(
        $SegmentTemplatesTable.$converterkind.toJson(kind),
      ),
      'label': serializer.toJson<String?>(label),
      'fingerprint': serializer.toJson<Uint8List>(fingerprint),
      'logMel': serializer.toJson<Uint8List?>(logMel),
      'durationMs': serializer.toJson<int>(durationMs),
      'occurrences': serializer.toJson<int>(occurrences),
      'confidence': serializer.toJson<int?>(confidence),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SegmentTemplate copyWith({
    int? id,
    int? podcastId,
    SkipSegmentKind? kind,
    Value<String?> label = const Value.absent(),
    Uint8List? fingerprint,
    Value<Uint8List?> logMel = const Value.absent(),
    int? durationMs,
    int? occurrences,
    Value<int?> confidence = const Value.absent(),
    DateTime? createdAt,
  }) => SegmentTemplate(
    id: id ?? this.id,
    podcastId: podcastId ?? this.podcastId,
    kind: kind ?? this.kind,
    label: label.present ? label.value : this.label,
    fingerprint: fingerprint ?? this.fingerprint,
    logMel: logMel.present ? logMel.value : this.logMel,
    durationMs: durationMs ?? this.durationMs,
    occurrences: occurrences ?? this.occurrences,
    confidence: confidence.present ? confidence.value : this.confidence,
    createdAt: createdAt ?? this.createdAt,
  );
  SegmentTemplate copyWithCompanion(SegmentTemplatesCompanion data) {
    return SegmentTemplate(
      id: data.id.present ? data.id.value : this.id,
      podcastId: data.podcastId.present ? data.podcastId.value : this.podcastId,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      logMel: data.logMel.present ? data.logMel.value : this.logMel,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      occurrences: data.occurrences.present
          ? data.occurrences.value
          : this.occurrences,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SegmentTemplate(')
          ..write('id: $id, ')
          ..write('podcastId: $podcastId, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('logMel: $logMel, ')
          ..write('durationMs: $durationMs, ')
          ..write('occurrences: $occurrences, ')
          ..write('confidence: $confidence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    podcastId,
    kind,
    label,
    $driftBlobEquality.hash(fingerprint),
    $driftBlobEquality.hash(logMel),
    durationMs,
    occurrences,
    confidence,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SegmentTemplate &&
          other.id == this.id &&
          other.podcastId == this.podcastId &&
          other.kind == this.kind &&
          other.label == this.label &&
          $driftBlobEquality.equals(other.fingerprint, this.fingerprint) &&
          $driftBlobEquality.equals(other.logMel, this.logMel) &&
          other.durationMs == this.durationMs &&
          other.occurrences == this.occurrences &&
          other.confidence == this.confidence &&
          other.createdAt == this.createdAt);
}

class SegmentTemplatesCompanion extends UpdateCompanion<SegmentTemplate> {
  final Value<int> id;
  final Value<int> podcastId;
  final Value<SkipSegmentKind> kind;
  final Value<String?> label;
  final Value<Uint8List> fingerprint;
  final Value<Uint8List?> logMel;
  final Value<int> durationMs;
  final Value<int> occurrences;
  final Value<int?> confidence;
  final Value<DateTime> createdAt;
  const SegmentTemplatesCompanion({
    this.id = const Value.absent(),
    this.podcastId = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.logMel = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.occurrences = const Value.absent(),
    this.confidence = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SegmentTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required int podcastId,
    required SkipSegmentKind kind,
    this.label = const Value.absent(),
    required Uint8List fingerprint,
    this.logMel = const Value.absent(),
    required int durationMs,
    this.occurrences = const Value.absent(),
    this.confidence = const Value.absent(),
    required DateTime createdAt,
  }) : podcastId = Value(podcastId),
       kind = Value(kind),
       fingerprint = Value(fingerprint),
       durationMs = Value(durationMs),
       createdAt = Value(createdAt);
  static Insertable<SegmentTemplate> custom({
    Expression<int>? id,
    Expression<int>? podcastId,
    Expression<String>? kind,
    Expression<String>? label,
    Expression<Uint8List>? fingerprint,
    Expression<Uint8List>? logMel,
    Expression<int>? durationMs,
    Expression<int>? occurrences,
    Expression<int>? confidence,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (podcastId != null) 'podcast_id': podcastId,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (logMel != null) 'log_mel': logMel,
      if (durationMs != null) 'duration_ms': durationMs,
      if (occurrences != null) 'occurrences': occurrences,
      if (confidence != null) 'confidence': confidence,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SegmentTemplatesCompanion copyWith({
    Value<int>? id,
    Value<int>? podcastId,
    Value<SkipSegmentKind>? kind,
    Value<String?>? label,
    Value<Uint8List>? fingerprint,
    Value<Uint8List?>? logMel,
    Value<int>? durationMs,
    Value<int>? occurrences,
    Value<int?>? confidence,
    Value<DateTime>? createdAt,
  }) {
    return SegmentTemplatesCompanion(
      id: id ?? this.id,
      podcastId: podcastId ?? this.podcastId,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      fingerprint: fingerprint ?? this.fingerprint,
      logMel: logMel ?? this.logMel,
      durationMs: durationMs ?? this.durationMs,
      occurrences: occurrences ?? this.occurrences,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (podcastId.present) {
      map['podcast_id'] = Variable<int>(podcastId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $SegmentTemplatesTable.$converterkind.toSql(kind.value),
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<Uint8List>(fingerprint.value);
    }
    if (logMel.present) {
      map['log_mel'] = Variable<Uint8List>(logMel.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (occurrences.present) {
      map['occurrences'] = Variable<int>(occurrences.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<int>(confidence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SegmentTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('podcastId: $podcastId, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('logMel: $logMel, ')
          ..write('durationMs: $durationMs, ')
          ..write('occurrences: $occurrences, ')
          ..write('confidence: $confidence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SkipSegmentsTable extends SkipSegments
    with TableInfo<$SkipSegmentsTable, SkipSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SkipSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES episodes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SkipSegmentKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SkipSegmentKind>($SkipSegmentsTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<SkipSegmentSource, String>
  source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<SkipSegmentSource>($SkipSegmentsTable.$convertersource);
  static const VerificationMeta _matchesMeta = const VerificationMeta(
    'matches',
  );
  @override
  late final GeneratedColumn<int> matches = GeneratedColumn<int>(
    'matches',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _confirmedMeta = const VerificationMeta(
    'confirmed',
  );
  @override
  late final GeneratedColumn<bool> confirmed = GeneratedColumn<bool>(
    'confirmed',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("confirmed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<int> confidence = GeneratedColumn<int>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<int> templateId = GeneratedColumn<int>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES segment_templates (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    episodeId,
    startMs,
    endMs,
    kind,
    source,
    matches,
    confirmed,
    confidence,
    templateId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'skip_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<SkipSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeIdMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('matches')) {
      context.handle(
        _matchesMeta,
        matches.isAcceptableOrUnknown(data['matches']!, _matchesMeta),
      );
    }
    if (data.containsKey('confirmed')) {
      context.handle(
        _confirmedMeta,
        confirmed.isAcceptableOrUnknown(data['confirmed']!, _confirmedMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SkipSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SkipSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      kind: $SkipSegmentsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      source: $SkipSegmentsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      matches: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}matches'],
      )!,
      confirmed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}confirmed'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confidence'],
      ),
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}template_id'],
      ),
    );
  }

  @override
  $SkipSegmentsTable createAlias(String alias) {
    return $SkipSegmentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SkipSegmentKind, String, String> $converterkind =
      const EnumNameConverter<SkipSegmentKind>(SkipSegmentKind.values);
  static JsonTypeConverter2<SkipSegmentSource, String, String>
  $convertersource = const EnumNameConverter<SkipSegmentSource>(
    SkipSegmentSource.values,
  );
}

class SkipSegment extends DataClass implements Insertable<SkipSegment> {
  final int id;
  final int episodeId;
  final int startMs;
  final int endMs;
  final SkipSegmentKind kind;
  final SkipSegmentSource source;

  /// Nombre d’épisodes du podcast qui partagent ce passage.
  final int matches;

  /// `null` : pas revu. `true` : confirmé. `false` : ignoré.
  final bool? confirmed;

  /// 0–100. `null` : pas calculé (chapitre, ou passage ancien).
  /// Sert au tri. Un candidat intra-épisode bas est replié dans l’écran.
  final int? confidence;
  final int? templateId;
  const SkipSegment({
    required this.id,
    required this.episodeId,
    required this.startMs,
    required this.endMs,
    required this.kind,
    required this.source,
    required this.matches,
    this.confirmed,
    this.confidence,
    this.templateId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['episode_id'] = Variable<int>(episodeId);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    {
      map['kind'] = Variable<String>(
        $SkipSegmentsTable.$converterkind.toSql(kind),
      );
    }
    {
      map['source'] = Variable<String>(
        $SkipSegmentsTable.$convertersource.toSql(source),
      );
    }
    map['matches'] = Variable<int>(matches);
    if (!nullToAbsent || confirmed != null) {
      map['confirmed'] = Variable<bool>(confirmed);
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<int>(confidence);
    }
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<int>(templateId);
    }
    return map;
  }

  SkipSegmentsCompanion toCompanion(bool nullToAbsent) {
    return SkipSegmentsCompanion(
      id: Value(id),
      episodeId: Value(episodeId),
      startMs: Value(startMs),
      endMs: Value(endMs),
      kind: Value(kind),
      source: Value(source),
      matches: Value(matches),
      confirmed: confirmed == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmed),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
    );
  }

  factory SkipSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SkipSegment(
      id: serializer.fromJson<int>(json['id']),
      episodeId: serializer.fromJson<int>(json['episodeId']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      kind: $SkipSegmentsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      source: $SkipSegmentsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      matches: serializer.fromJson<int>(json['matches']),
      confirmed: serializer.fromJson<bool?>(json['confirmed']),
      confidence: serializer.fromJson<int?>(json['confidence']),
      templateId: serializer.fromJson<int?>(json['templateId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'episodeId': serializer.toJson<int>(episodeId),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'kind': serializer.toJson<String>(
        $SkipSegmentsTable.$converterkind.toJson(kind),
      ),
      'source': serializer.toJson<String>(
        $SkipSegmentsTable.$convertersource.toJson(source),
      ),
      'matches': serializer.toJson<int>(matches),
      'confirmed': serializer.toJson<bool?>(confirmed),
      'confidence': serializer.toJson<int?>(confidence),
      'templateId': serializer.toJson<int?>(templateId),
    };
  }

  SkipSegment copyWith({
    int? id,
    int? episodeId,
    int? startMs,
    int? endMs,
    SkipSegmentKind? kind,
    SkipSegmentSource? source,
    int? matches,
    Value<bool?> confirmed = const Value.absent(),
    Value<int?> confidence = const Value.absent(),
    Value<int?> templateId = const Value.absent(),
  }) => SkipSegment(
    id: id ?? this.id,
    episodeId: episodeId ?? this.episodeId,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    kind: kind ?? this.kind,
    source: source ?? this.source,
    matches: matches ?? this.matches,
    confirmed: confirmed.present ? confirmed.value : this.confirmed,
    confidence: confidence.present ? confidence.value : this.confidence,
    templateId: templateId.present ? templateId.value : this.templateId,
  );
  SkipSegment copyWithCompanion(SkipSegmentsCompanion data) {
    return SkipSegment(
      id: data.id.present ? data.id.value : this.id,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      kind: data.kind.present ? data.kind.value : this.kind,
      source: data.source.present ? data.source.value : this.source,
      matches: data.matches.present ? data.matches.value : this.matches,
      confirmed: data.confirmed.present ? data.confirmed.value : this.confirmed,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SkipSegment(')
          ..write('id: $id, ')
          ..write('episodeId: $episodeId, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('kind: $kind, ')
          ..write('source: $source, ')
          ..write('matches: $matches, ')
          ..write('confirmed: $confirmed, ')
          ..write('confidence: $confidence, ')
          ..write('templateId: $templateId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    episodeId,
    startMs,
    endMs,
    kind,
    source,
    matches,
    confirmed,
    confidence,
    templateId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkipSegment &&
          other.id == this.id &&
          other.episodeId == this.episodeId &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.kind == this.kind &&
          other.source == this.source &&
          other.matches == this.matches &&
          other.confirmed == this.confirmed &&
          other.confidence == this.confidence &&
          other.templateId == this.templateId);
}

class SkipSegmentsCompanion extends UpdateCompanion<SkipSegment> {
  final Value<int> id;
  final Value<int> episodeId;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<SkipSegmentKind> kind;
  final Value<SkipSegmentSource> source;
  final Value<int> matches;
  final Value<bool?> confirmed;
  final Value<int?> confidence;
  final Value<int?> templateId;
  const SkipSegmentsCompanion({
    this.id = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.kind = const Value.absent(),
    this.source = const Value.absent(),
    this.matches = const Value.absent(),
    this.confirmed = const Value.absent(),
    this.confidence = const Value.absent(),
    this.templateId = const Value.absent(),
  });
  SkipSegmentsCompanion.insert({
    this.id = const Value.absent(),
    required int episodeId,
    required int startMs,
    required int endMs,
    required SkipSegmentKind kind,
    required SkipSegmentSource source,
    this.matches = const Value.absent(),
    this.confirmed = const Value.absent(),
    this.confidence = const Value.absent(),
    this.templateId = const Value.absent(),
  }) : episodeId = Value(episodeId),
       startMs = Value(startMs),
       endMs = Value(endMs),
       kind = Value(kind),
       source = Value(source);
  static Insertable<SkipSegment> custom({
    Expression<int>? id,
    Expression<int>? episodeId,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? kind,
    Expression<String>? source,
    Expression<int>? matches,
    Expression<bool>? confirmed,
    Expression<int>? confidence,
    Expression<int>? templateId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (episodeId != null) 'episode_id': episodeId,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (kind != null) 'kind': kind,
      if (source != null) 'source': source,
      if (matches != null) 'matches': matches,
      if (confirmed != null) 'confirmed': confirmed,
      if (confidence != null) 'confidence': confidence,
      if (templateId != null) 'template_id': templateId,
    });
  }

  SkipSegmentsCompanion copyWith({
    Value<int>? id,
    Value<int>? episodeId,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<SkipSegmentKind>? kind,
    Value<SkipSegmentSource>? source,
    Value<int>? matches,
    Value<bool?>? confirmed,
    Value<int?>? confidence,
    Value<int?>? templateId,
  }) {
    return SkipSegmentsCompanion(
      id: id ?? this.id,
      episodeId: episodeId ?? this.episodeId,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      kind: kind ?? this.kind,
      source: source ?? this.source,
      matches: matches ?? this.matches,
      confirmed: confirmed ?? this.confirmed,
      confidence: confidence ?? this.confidence,
      templateId: templateId ?? this.templateId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $SkipSegmentsTable.$converterkind.toSql(kind.value),
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $SkipSegmentsTable.$convertersource.toSql(source.value),
      );
    }
    if (matches.present) {
      map['matches'] = Variable<int>(matches.value);
    }
    if (confirmed.present) {
      map['confirmed'] = Variable<bool>(confirmed.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<int>(confidence.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<int>(templateId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SkipSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('episodeId: $episodeId, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('kind: $kind, ')
          ..write('source: $source, ')
          ..write('matches: $matches, ')
          ..write('confirmed: $confirmed, ')
          ..write('confidence: $confidence, ')
          ..write('templateId: $templateId')
          ..write(')'))
        .toString();
  }
}

class $EpisodeLogMelsTable extends EpisodeLogMels
    with TableInfo<$EpisodeLogMelsTable, EpisodeLogMel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodeLogMelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES episodes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<Uint8List> data = GeneratedColumn<Uint8List>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hopMsMeta = const VerificationMeta('hopMs');
  @override
  late final GeneratedColumn<int> hopMs = GeneratedColumn<int>(
    'hop_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [episodeId, data, hopMs, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episode_log_mels';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeLogMel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('hop_ms')) {
      context.handle(
        _hopMsMeta,
        hopMs.isAcceptableOrUnknown(data['hop_ms']!, _hopMsMeta),
      );
    } else if (isInserting) {
      context.missing(_hopMsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {episodeId};
  @override
  EpisodeLogMel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeLogMel(
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}data'],
      )!,
      hopMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hop_ms'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EpisodeLogMelsTable createAlias(String alias) {
    return $EpisodeLogMelsTable(attachedDatabase, alias);
  }
}

class EpisodeLogMel extends DataClass implements Insertable<EpisodeLogMel> {
  final int episodeId;

  /// Float32 little-endian, 40 bandes, hop 10 ms.
  final Uint8List data;
  final int hopMs;
  final DateTime createdAt;
  const EpisodeLogMel({
    required this.episodeId,
    required this.data,
    required this.hopMs,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['episode_id'] = Variable<int>(episodeId);
    map['data'] = Variable<Uint8List>(data);
    map['hop_ms'] = Variable<int>(hopMs);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EpisodeLogMelsCompanion toCompanion(bool nullToAbsent) {
    return EpisodeLogMelsCompanion(
      episodeId: Value(episodeId),
      data: Value(data),
      hopMs: Value(hopMs),
      createdAt: Value(createdAt),
    );
  }

  factory EpisodeLogMel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeLogMel(
      episodeId: serializer.fromJson<int>(json['episodeId']),
      data: serializer.fromJson<Uint8List>(json['data']),
      hopMs: serializer.fromJson<int>(json['hopMs']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'episodeId': serializer.toJson<int>(episodeId),
      'data': serializer.toJson<Uint8List>(data),
      'hopMs': serializer.toJson<int>(hopMs),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EpisodeLogMel copyWith({
    int? episodeId,
    Uint8List? data,
    int? hopMs,
    DateTime? createdAt,
  }) => EpisodeLogMel(
    episodeId: episodeId ?? this.episodeId,
    data: data ?? this.data,
    hopMs: hopMs ?? this.hopMs,
    createdAt: createdAt ?? this.createdAt,
  );
  EpisodeLogMel copyWithCompanion(EpisodeLogMelsCompanion data) {
    return EpisodeLogMel(
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      data: data.data.present ? data.data.value : this.data,
      hopMs: data.hopMs.present ? data.hopMs.value : this.hopMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeLogMel(')
          ..write('episodeId: $episodeId, ')
          ..write('data: $data, ')
          ..write('hopMs: $hopMs, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(episodeId, $driftBlobEquality.hash(data), hopMs, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeLogMel &&
          other.episodeId == this.episodeId &&
          $driftBlobEquality.equals(other.data, this.data) &&
          other.hopMs == this.hopMs &&
          other.createdAt == this.createdAt);
}

class EpisodeLogMelsCompanion extends UpdateCompanion<EpisodeLogMel> {
  final Value<int> episodeId;
  final Value<Uint8List> data;
  final Value<int> hopMs;
  final Value<DateTime> createdAt;
  const EpisodeLogMelsCompanion({
    this.episodeId = const Value.absent(),
    this.data = const Value.absent(),
    this.hopMs = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EpisodeLogMelsCompanion.insert({
    this.episodeId = const Value.absent(),
    required Uint8List data,
    required int hopMs,
    required DateTime createdAt,
  }) : data = Value(data),
       hopMs = Value(hopMs),
       createdAt = Value(createdAt);
  static Insertable<EpisodeLogMel> custom({
    Expression<int>? episodeId,
    Expression<Uint8List>? data,
    Expression<int>? hopMs,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (episodeId != null) 'episode_id': episodeId,
      if (data != null) 'data': data,
      if (hopMs != null) 'hop_ms': hopMs,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EpisodeLogMelsCompanion copyWith({
    Value<int>? episodeId,
    Value<Uint8List>? data,
    Value<int>? hopMs,
    Value<DateTime>? createdAt,
  }) {
    return EpisodeLogMelsCompanion(
      episodeId: episodeId ?? this.episodeId,
      data: data ?? this.data,
      hopMs: hopMs ?? this.hopMs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (data.present) {
      map['data'] = Variable<Uint8List>(data.value);
    }
    if (hopMs.present) {
      map['hop_ms'] = Variable<int>(hopMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeLogMelsCompanion(')
          ..write('episodeId: $episodeId, ')
          ..write('data: $data, ')
          ..write('hopMs: $hopMs, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LearnedNetworkStingsTable extends LearnedNetworkStings
    with TableInfo<$LearnedNetworkStingsTable, LearnedNetworkSting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearnedNetworkStingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logMelMeta = const VerificationMeta('logMel');
  @override
  late final GeneratedColumn<Uint8List> logMel = GeneratedColumn<Uint8List>(
    'log_mel',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeCountMeta = const VerificationMeta(
    'episodeCount',
  );
  @override
  late final GeneratedColumn<int> episodeCount = GeneratedColumn<int>(
    'episode_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _podcastCountMeta = const VerificationMeta(
    'podcastCount',
  );
  @override
  late final GeneratedColumn<int> podcastCount = GeneratedColumn<int>(
    'podcast_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    logMel,
    durationMs,
    episodeCount,
    podcastCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learned_network_stings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearnedNetworkSting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('log_mel')) {
      context.handle(
        _logMelMeta,
        logMel.isAcceptableOrUnknown(data['log_mel']!, _logMelMeta),
      );
    } else if (isInserting) {
      context.missing(_logMelMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('episode_count')) {
      context.handle(
        _episodeCountMeta,
        episodeCount.isAcceptableOrUnknown(
          data['episode_count']!,
          _episodeCountMeta,
        ),
      );
    }
    if (data.containsKey('podcast_count')) {
      context.handle(
        _podcastCountMeta,
        podcastCount.isAcceptableOrUnknown(
          data['podcast_count']!,
          _podcastCountMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearnedNetworkSting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearnedNetworkSting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      logMel: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}log_mel'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      episodeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_count'],
      )!,
      podcastCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}podcast_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LearnedNetworkStingsTable createAlias(String alias) {
    return $LearnedNetworkStingsTable(attachedDatabase, alias);
  }
}

class LearnedNetworkSting extends DataClass
    implements Insertable<LearnedNetworkSting> {
  final int id;
  final String? name;
  final Uint8List logMel;
  final int durationMs;
  final int episodeCount;
  final int podcastCount;
  final DateTime createdAt;
  const LearnedNetworkSting({
    required this.id,
    this.name,
    required this.logMel,
    required this.durationMs,
    required this.episodeCount,
    required this.podcastCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['log_mel'] = Variable<Uint8List>(logMel);
    map['duration_ms'] = Variable<int>(durationMs);
    map['episode_count'] = Variable<int>(episodeCount);
    map['podcast_count'] = Variable<int>(podcastCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LearnedNetworkStingsCompanion toCompanion(bool nullToAbsent) {
    return LearnedNetworkStingsCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      logMel: Value(logMel),
      durationMs: Value(durationMs),
      episodeCount: Value(episodeCount),
      podcastCount: Value(podcastCount),
      createdAt: Value(createdAt),
    );
  }

  factory LearnedNetworkSting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearnedNetworkSting(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      logMel: serializer.fromJson<Uint8List>(json['logMel']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      episodeCount: serializer.fromJson<int>(json['episodeCount']),
      podcastCount: serializer.fromJson<int>(json['podcastCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
      'logMel': serializer.toJson<Uint8List>(logMel),
      'durationMs': serializer.toJson<int>(durationMs),
      'episodeCount': serializer.toJson<int>(episodeCount),
      'podcastCount': serializer.toJson<int>(podcastCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LearnedNetworkSting copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
    Uint8List? logMel,
    int? durationMs,
    int? episodeCount,
    int? podcastCount,
    DateTime? createdAt,
  }) => LearnedNetworkSting(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    logMel: logMel ?? this.logMel,
    durationMs: durationMs ?? this.durationMs,
    episodeCount: episodeCount ?? this.episodeCount,
    podcastCount: podcastCount ?? this.podcastCount,
    createdAt: createdAt ?? this.createdAt,
  );
  LearnedNetworkSting copyWithCompanion(LearnedNetworkStingsCompanion data) {
    return LearnedNetworkSting(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      logMel: data.logMel.present ? data.logMel.value : this.logMel,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      episodeCount: data.episodeCount.present
          ? data.episodeCount.value
          : this.episodeCount,
      podcastCount: data.podcastCount.present
          ? data.podcastCount.value
          : this.podcastCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearnedNetworkSting(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('logMel: $logMel, ')
          ..write('durationMs: $durationMs, ')
          ..write('episodeCount: $episodeCount, ')
          ..write('podcastCount: $podcastCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    $driftBlobEquality.hash(logMel),
    durationMs,
    episodeCount,
    podcastCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearnedNetworkSting &&
          other.id == this.id &&
          other.name == this.name &&
          $driftBlobEquality.equals(other.logMel, this.logMel) &&
          other.durationMs == this.durationMs &&
          other.episodeCount == this.episodeCount &&
          other.podcastCount == this.podcastCount &&
          other.createdAt == this.createdAt);
}

class LearnedNetworkStingsCompanion
    extends UpdateCompanion<LearnedNetworkSting> {
  final Value<int> id;
  final Value<String?> name;
  final Value<Uint8List> logMel;
  final Value<int> durationMs;
  final Value<int> episodeCount;
  final Value<int> podcastCount;
  final Value<DateTime> createdAt;
  const LearnedNetworkStingsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.logMel = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.episodeCount = const Value.absent(),
    this.podcastCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LearnedNetworkStingsCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    required Uint8List logMel,
    required int durationMs,
    this.episodeCount = const Value.absent(),
    this.podcastCount = const Value.absent(),
    required DateTime createdAt,
  }) : logMel = Value(logMel),
       durationMs = Value(durationMs),
       createdAt = Value(createdAt);
  static Insertable<LearnedNetworkSting> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<Uint8List>? logMel,
    Expression<int>? durationMs,
    Expression<int>? episodeCount,
    Expression<int>? podcastCount,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (logMel != null) 'log_mel': logMel,
      if (durationMs != null) 'duration_ms': durationMs,
      if (episodeCount != null) 'episode_count': episodeCount,
      if (podcastCount != null) 'podcast_count': podcastCount,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LearnedNetworkStingsCompanion copyWith({
    Value<int>? id,
    Value<String?>? name,
    Value<Uint8List>? logMel,
    Value<int>? durationMs,
    Value<int>? episodeCount,
    Value<int>? podcastCount,
    Value<DateTime>? createdAt,
  }) {
    return LearnedNetworkStingsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      logMel: logMel ?? this.logMel,
      durationMs: durationMs ?? this.durationMs,
      episodeCount: episodeCount ?? this.episodeCount,
      podcastCount: podcastCount ?? this.podcastCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (logMel.present) {
      map['log_mel'] = Variable<Uint8List>(logMel.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (episodeCount.present) {
      map['episode_count'] = Variable<int>(episodeCount.value);
    }
    if (podcastCount.present) {
      map['podcast_count'] = Variable<int>(podcastCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearnedNetworkStingsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('logMel: $logMel, ')
          ..write('durationMs: $durationMs, ')
          ..write('episodeCount: $episodeCount, ')
          ..write('podcastCount: $podcastCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PodcastsTable podcasts = $PodcastsTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final $EpisodeChaptersTable episodeChapters = $EpisodeChaptersTable(
    this,
  );
  late final $PlaybackPositionsTable playbackPositions =
      $PlaybackPositionsTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistEpisodesTable playlistEpisodes = $PlaylistEpisodesTable(
    this,
  );
  late final $EpisodeFingerprintsTable episodeFingerprints =
      $EpisodeFingerprintsTable(this);
  late final $SegmentTemplatesTable segmentTemplates = $SegmentTemplatesTable(
    this,
  );
  late final $SkipSegmentsTable skipSegments = $SkipSegmentsTable(this);
  late final $EpisodeLogMelsTable episodeLogMels = $EpisodeLogMelsTable(this);
  late final $LearnedNetworkStingsTable learnedNetworkStings =
      $LearnedNetworkStingsTable(this);
  late final Index episodesPodcastId = Index(
    'episodes_podcast_id',
    'CREATE INDEX episodes_podcast_id ON episodes (podcast_id)',
  );
  late final Index episodesPublishedAt = Index(
    'episodes_published_at',
    'CREATE INDEX episodes_published_at ON episodes (published_at)',
  );
  late final Index episodesPlayed = Index(
    'episodes_played',
    'CREATE INDEX episodes_played ON episodes (played)',
  );
  late final Index episodesQueueIndex = Index(
    'episodes_queue_index',
    'CREATE INDEX episodes_queue_index ON episodes (queue_index)',
  );
  late final Index episodesLastPlayedAt = Index(
    'episodes_last_played_at',
    'CREATE INDEX episodes_last_played_at ON episodes (last_played_at)',
  );
  late final Index episodesFavorite = Index(
    'episodes_favorite',
    'CREATE INDEX episodes_favorite ON episodes (favorite)',
  );
  late final Index episodesDownloadPath = Index(
    'episodes_download_path',
    'CREATE INDEX episodes_download_path ON episodes (download_path)',
  );
  late final Index playlistEpisodesPlaylistId = Index(
    'playlist_episodes_playlist_id',
    'CREATE INDEX playlist_episodes_playlist_id ON playlist_episodes (playlist_id)',
  );
  late final Index segmentTemplatesPodcastId = Index(
    'segment_templates_podcast_id',
    'CREATE INDEX segment_templates_podcast_id ON segment_templates (podcast_id)',
  );
  late final Index skipSegmentsEpisodeId = Index(
    'skip_segments_episode_id',
    'CREATE INDEX skip_segments_episode_id ON skip_segments (episode_id)',
  );
  late final Index skipSegmentsTemplateId = Index(
    'skip_segments_template_id',
    'CREATE INDEX skip_segments_template_id ON skip_segments (template_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    podcasts,
    episodes,
    episodeChapters,
    playbackPositions,
    playlists,
    playlistEpisodes,
    episodeFingerprints,
    segmentTemplates,
    skipSegments,
    episodeLogMels,
    learnedNetworkStings,
    episodesPodcastId,
    episodesPublishedAt,
    episodesPlayed,
    episodesQueueIndex,
    episodesLastPlayedAt,
    episodesFavorite,
    episodesDownloadPath,
    playlistEpisodesPlaylistId,
    segmentTemplatesPodcastId,
    skipSegmentsEpisodeId,
    skipSegmentsTemplateId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'podcasts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('episodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'episodes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('episode_chapters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'episodes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playback_positions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_episodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'episodes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_episodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'episodes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('episode_fingerprints', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'podcasts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('segment_templates', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'episodes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('skip_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'segment_templates',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('skip_segments', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'episodes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('episode_log_mels', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PodcastsTableCreateCompanionBuilder = PodcastsCompanion Function({
  Value<int> id,
  required String feedUrl,
  required String title,
  Value<String> titleFold,
  Value<String> author,
  Value<String> description,
  Value<String?> imageUrl,
  Value<String?> imagePath,
  Value<String?> link,
  required DateTime subscribedAt,
  Value<DateTime?> refreshedAt,
  Value<bool> preferred,
  Value<bool> autoDownload,
  Value<int?> autoDownloadLimit,
  Value<bool> keepUpdated,
  Value<bool> episodeNotification,
  Value<bool> subscribed,
  Value<double?> playbackSpeed,
  Value<int> skipIntroSeconds,
  Value<int> skipOutroSeconds,
  Value<String?> authUsername,
  Value<String?> authPassword,
  Value<String> personsJson,
  Value<String> fundingJson,
  Value<String?> categoriesJson,
  Value<bool> autoSkipAds,
  Value<String> autoSkipKinds,
});
typedef $$PodcastsTableUpdateCompanionBuilder = PodcastsCompanion Function({
  Value<int> id,
  Value<String> feedUrl,
  Value<String> title,
  Value<String> titleFold,
  Value<String> author,
  Value<String> description,
  Value<String?> imageUrl,
  Value<String?> imagePath,
  Value<String?> link,
  Value<DateTime> subscribedAt,
  Value<DateTime?> refreshedAt,
  Value<bool> preferred,
  Value<bool> autoDownload,
  Value<int?> autoDownloadLimit,
  Value<bool> keepUpdated,
  Value<bool> episodeNotification,
  Value<bool> subscribed,
  Value<double?> playbackSpeed,
  Value<int> skipIntroSeconds,
  Value<int> skipOutroSeconds,
  Value<String?> authUsername,
  Value<String?> authPassword,
  Value<String> personsJson,
  Value<String> fundingJson,
  Value<String?> categoriesJson,
  Value<bool> autoSkipAds,
  Value<String> autoSkipKinds,
});

final class $$PodcastsTableReferences
    extends BaseReferences<_$AppDatabase, $PodcastsTable, Podcast> {
  $$PodcastsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EpisodesTable, List<Episode>> _episodesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.episodes,
    aliasName: 'podcasts__id__episodes__podcast_id',
  );

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.podcastId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SegmentTemplatesTable, List<SegmentTemplate>>
  _segmentTemplatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.segmentTemplates,
    aliasName: 'podcasts__id__segment_templates__podcast_id',
  );

  $$SegmentTemplatesTableProcessedTableManager get segmentTemplatesRefs {
    final manager = $$SegmentTemplatesTableTableManager(
      $_db,
      $_db.segmentTemplates,
    ).filter((f) => f.podcastId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _segmentTemplatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PodcastsTableFilterComposer
    extends Composer<_$AppDatabase, $PodcastsTable> {
  $$PodcastsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedUrl => $composableBuilder(
    column: $table.feedUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleFold => $composableBuilder(
    column: $table.titleFold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get subscribedAt => $composableBuilder(
    column: $table.subscribedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get preferred => $composableBuilder(
    column: $table.preferred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoDownload => $composableBuilder(
    column: $table.autoDownload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoDownloadLimit => $composableBuilder(
    column: $table.autoDownloadLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepUpdated => $composableBuilder(
    column: $table.keepUpdated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get episodeNotification => $composableBuilder(
    column: $table.episodeNotification,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get subscribed => $composableBuilder(
    column: $table.subscribed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get playbackSpeed => $composableBuilder(
    column: $table.playbackSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skipIntroSeconds => $composableBuilder(
    column: $table.skipIntroSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skipOutroSeconds => $composableBuilder(
    column: $table.skipOutroSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authUsername => $composableBuilder(
    column: $table.authUsername,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authPassword => $composableBuilder(
    column: $table.authPassword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personsJson => $composableBuilder(
    column: $table.personsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fundingJson => $composableBuilder(
    column: $table.fundingJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoSkipAds => $composableBuilder(
    column: $table.autoSkipAds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get autoSkipKinds => $composableBuilder(
    column: $table.autoSkipKinds,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> episodesRefs(
    Expression<bool> Function($$EpisodesTableFilterComposer f) f,
  ) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.podcastId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> segmentTemplatesRefs(
    Expression<bool> Function($$SegmentTemplatesTableFilterComposer f) f,
  ) {
    final $$SegmentTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segmentTemplates,
      getReferencedColumn: (t) => t.podcastId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.segmentTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PodcastsTableOrderingComposer
    extends Composer<_$AppDatabase, $PodcastsTable> {
  $$PodcastsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedUrl => $composableBuilder(
    column: $table.feedUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleFold => $composableBuilder(
    column: $table.titleFold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get subscribedAt => $composableBuilder(
    column: $table.subscribedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get preferred => $composableBuilder(
    column: $table.preferred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoDownload => $composableBuilder(
    column: $table.autoDownload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoDownloadLimit => $composableBuilder(
    column: $table.autoDownloadLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepUpdated => $composableBuilder(
    column: $table.keepUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get episodeNotification => $composableBuilder(
    column: $table.episodeNotification,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get subscribed => $composableBuilder(
    column: $table.subscribed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get playbackSpeed => $composableBuilder(
    column: $table.playbackSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skipIntroSeconds => $composableBuilder(
    column: $table.skipIntroSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skipOutroSeconds => $composableBuilder(
    column: $table.skipOutroSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authUsername => $composableBuilder(
    column: $table.authUsername,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authPassword => $composableBuilder(
    column: $table.authPassword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personsJson => $composableBuilder(
    column: $table.personsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fundingJson => $composableBuilder(
    column: $table.fundingJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoSkipAds => $composableBuilder(
    column: $table.autoSkipAds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get autoSkipKinds => $composableBuilder(
    column: $table.autoSkipKinds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PodcastsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PodcastsTable> {
  $$PodcastsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get feedUrl =>
      $composableBuilder(column: $table.feedUrl, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleFold =>
      $composableBuilder(column: $table.titleFold, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);

  GeneratedColumn<DateTime> get subscribedAt => $composableBuilder(
    column: $table.subscribedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get preferred =>
      $composableBuilder(column: $table.preferred, builder: (column) => column);

  GeneratedColumn<bool> get autoDownload => $composableBuilder(
    column: $table.autoDownload,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoDownloadLimit => $composableBuilder(
    column: $table.autoDownloadLimit,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get keepUpdated => $composableBuilder(
    column: $table.keepUpdated,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get episodeNotification => $composableBuilder(
    column: $table.episodeNotification,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get subscribed => $composableBuilder(
    column: $table.subscribed,
    builder: (column) => column,
  );

  GeneratedColumn<double> get playbackSpeed => $composableBuilder(
    column: $table.playbackSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get skipIntroSeconds => $composableBuilder(
    column: $table.skipIntroSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get skipOutroSeconds => $composableBuilder(
    column: $table.skipOutroSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authUsername => $composableBuilder(
    column: $table.authUsername,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authPassword => $composableBuilder(
    column: $table.authPassword,
    builder: (column) => column,
  );

  GeneratedColumn<String> get personsJson => $composableBuilder(
    column: $table.personsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fundingJson => $composableBuilder(
    column: $table.fundingJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoSkipAds => $composableBuilder(
    column: $table.autoSkipAds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get autoSkipKinds => $composableBuilder(
    column: $table.autoSkipKinds,
    builder: (column) => column,
  );

  Expression<T> episodesRefs<T extends Object>(
    Expression<T> Function($$EpisodesTableAnnotationComposer a) f,
  ) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.podcastId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> segmentTemplatesRefs<T extends Object>(
    Expression<T> Function($$SegmentTemplatesTableAnnotationComposer a) f,
  ) {
    final $$SegmentTemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segmentTemplates,
      getReferencedColumn: (t) => t.podcastId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentTemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.segmentTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PodcastsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PodcastsTable,
          Podcast,
          $$PodcastsTableFilterComposer,
          $$PodcastsTableOrderingComposer,
          $$PodcastsTableAnnotationComposer,
          $$PodcastsTableCreateCompanionBuilder,
          $$PodcastsTableUpdateCompanionBuilder,
          (Podcast, $$PodcastsTableReferences),
          Podcast,
          PrefetchHooks Function({bool episodesRefs, bool segmentTemplatesRefs})
        > {
  $$PodcastsTableTableManager(_$AppDatabase db, $PodcastsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PodcastsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PodcastsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PodcastsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> feedUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> titleFold = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<DateTime> subscribedAt = const Value.absent(),
                Value<DateTime?> refreshedAt = const Value.absent(),
                Value<bool> preferred = const Value.absent(),
                Value<bool> autoDownload = const Value.absent(),
                Value<int?> autoDownloadLimit = const Value.absent(),
                Value<bool> keepUpdated = const Value.absent(),
                Value<bool> episodeNotification = const Value.absent(),
                Value<bool> subscribed = const Value.absent(),
                Value<double?> playbackSpeed = const Value.absent(),
                Value<int> skipIntroSeconds = const Value.absent(),
                Value<int> skipOutroSeconds = const Value.absent(),
                Value<String?> authUsername = const Value.absent(),
                Value<String?> authPassword = const Value.absent(),
                Value<String> personsJson = const Value.absent(),
                Value<String> fundingJson = const Value.absent(),
                Value<String?> categoriesJson = const Value.absent(),
                Value<bool> autoSkipAds = const Value.absent(),
                Value<String> autoSkipKinds = const Value.absent(),
              }) => PodcastsCompanion(
                id: id,
                feedUrl: feedUrl,
                title: title,
                titleFold: titleFold,
                author: author,
                description: description,
                imageUrl: imageUrl,
                imagePath: imagePath,
                link: link,
                subscribedAt: subscribedAt,
                refreshedAt: refreshedAt,
                preferred: preferred,
                autoDownload: autoDownload,
                autoDownloadLimit: autoDownloadLimit,
                keepUpdated: keepUpdated,
                episodeNotification: episodeNotification,
                subscribed: subscribed,
                playbackSpeed: playbackSpeed,
                skipIntroSeconds: skipIntroSeconds,
                skipOutroSeconds: skipOutroSeconds,
                authUsername: authUsername,
                authPassword: authPassword,
                personsJson: personsJson,
                fundingJson: fundingJson,
                categoriesJson: categoriesJson,
                autoSkipAds: autoSkipAds,
                autoSkipKinds: autoSkipKinds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String feedUrl,
                required String title,
                Value<String> titleFold = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> link = const Value.absent(),
                required DateTime subscribedAt,
                Value<DateTime?> refreshedAt = const Value.absent(),
                Value<bool> preferred = const Value.absent(),
                Value<bool> autoDownload = const Value.absent(),
                Value<int?> autoDownloadLimit = const Value.absent(),
                Value<bool> keepUpdated = const Value.absent(),
                Value<bool> episodeNotification = const Value.absent(),
                Value<bool> subscribed = const Value.absent(),
                Value<double?> playbackSpeed = const Value.absent(),
                Value<int> skipIntroSeconds = const Value.absent(),
                Value<int> skipOutroSeconds = const Value.absent(),
                Value<String?> authUsername = const Value.absent(),
                Value<String?> authPassword = const Value.absent(),
                Value<String> personsJson = const Value.absent(),
                Value<String> fundingJson = const Value.absent(),
                Value<String?> categoriesJson = const Value.absent(),
                Value<bool> autoSkipAds = const Value.absent(),
                Value<String> autoSkipKinds = const Value.absent(),
              }) => PodcastsCompanion.insert(
                id: id,
                feedUrl: feedUrl,
                title: title,
                titleFold: titleFold,
                author: author,
                description: description,
                imageUrl: imageUrl,
                imagePath: imagePath,
                link: link,
                subscribedAt: subscribedAt,
                refreshedAt: refreshedAt,
                preferred: preferred,
                autoDownload: autoDownload,
                autoDownloadLimit: autoDownloadLimit,
                keepUpdated: keepUpdated,
                episodeNotification: episodeNotification,
                subscribed: subscribed,
                playbackSpeed: playbackSpeed,
                skipIntroSeconds: skipIntroSeconds,
                skipOutroSeconds: skipOutroSeconds,
                authUsername: authUsername,
                authPassword: authPassword,
                personsJson: personsJson,
                fundingJson: fundingJson,
                categoriesJson: categoriesJson,
                autoSkipAds: autoSkipAds,
                autoSkipKinds: autoSkipKinds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PodcastsTable, Podcast>(table),
                  $$PodcastsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({episodesRefs = false, segmentTemplatesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (episodesRefs) db.episodes,
                    if (segmentTemplatesRefs) db.segmentTemplates,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (episodesRefs)
                        await $_getPrefetchedDataByColumns<
                          Podcast,
                          $PodcastsTable,
                          Episode,
                          $EpisodesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PodcastsTableReferences
                              ._episodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PodcastsTableReferences(
                                db,
                                table,
                                p0,
                              ).episodesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'podcast_id',
                          typedResults: items,
                        ),
                      if (segmentTemplatesRefs)
                        await $_getPrefetchedDataByColumns<
                          Podcast,
                          $PodcastsTable,
                          SegmentTemplate,
                          $SegmentTemplatesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PodcastsTableReferences
                              ._segmentTemplatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PodcastsTableReferences(
                                db,
                                table,
                                p0,
                              ).segmentTemplatesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'podcast_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PodcastsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PodcastsTable,
      Podcast,
      $$PodcastsTableFilterComposer,
      $$PodcastsTableOrderingComposer,
      $$PodcastsTableAnnotationComposer,
      $$PodcastsTableCreateCompanionBuilder,
      $$PodcastsTableUpdateCompanionBuilder,
      (Podcast, $$PodcastsTableReferences),
      Podcast,
      PrefetchHooks Function({bool episodesRefs, bool segmentTemplatesRefs})
    >;
typedef $$EpisodesTableCreateCompanionBuilder = EpisodesCompanion Function({
  Value<int> id,
  required int podcastId,
  required String guid,
  required String title,
  Value<String> titleFold,
  Value<String> description,
  required String audioUrl,
  Value<String?> mimeType,
  Value<int?> durationSeconds,
  Value<DateTime?> publishedAt,
  Value<String?> imageUrl,
  Value<String?> imagePath,
  Value<int> positionMs,
  Value<bool> played,
  Value<bool> favorite,
  Value<String?> downloadPath,
  Value<String?> cachePath,
  Value<int?> queueIndex,
  Value<DateTime?> lastPlayedAt,
  Value<DateTime?> downloadedAt,
  Value<String?> chaptersUrl,
  Value<bool> chaptersFetched,
});
typedef $$EpisodesTableUpdateCompanionBuilder = EpisodesCompanion Function({
  Value<int> id,
  Value<int> podcastId,
  Value<String> guid,
  Value<String> title,
  Value<String> titleFold,
  Value<String> description,
  Value<String> audioUrl,
  Value<String?> mimeType,
  Value<int?> durationSeconds,
  Value<DateTime?> publishedAt,
  Value<String?> imageUrl,
  Value<String?> imagePath,
  Value<int> positionMs,
  Value<bool> played,
  Value<bool> favorite,
  Value<String?> downloadPath,
  Value<String?> cachePath,
  Value<int?> queueIndex,
  Value<DateTime?> lastPlayedAt,
  Value<DateTime?> downloadedAt,
  Value<String?> chaptersUrl,
  Value<bool> chaptersFetched,
});

final class $$EpisodesTableReferences
    extends BaseReferences<_$AppDatabase, $EpisodesTable, Episode> {
  $$EpisodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PodcastsTable _podcastIdTable(_$AppDatabase db) =>
      db.podcasts.createAlias('episodes__podcast_id__podcasts__id');

  $$PodcastsTableProcessedTableManager get podcastId {
    final $_column = $_itemColumn<int>('podcast_id')!;

    final manager = $$PodcastsTableTableManager(
      $_db,
      $_db.podcasts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_podcastIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EpisodeChaptersTable, List<EpisodeChapter>>
  _episodeChaptersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.episodeChapters,
    aliasName: 'episodes__id__episode_chapters__episode_id',
  );

  $$EpisodeChaptersTableProcessedTableManager get episodeChaptersRefs {
    final manager = $$EpisodeChaptersTableTableManager(
      $_db,
      $_db.episodeChapters,
    ).filter((f) => f.episodeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _episodeChaptersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlaybackPositionsTable, List<PlaybackPosition>>
  _playbackPositionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playbackPositions,
        aliasName: 'episodes__id__playback_positions__episode_id',
      );

  $$PlaybackPositionsTableProcessedTableManager get playbackPositionsRefs {
    final manager = $$PlaybackPositionsTableTableManager(
      $_db,
      $_db.playbackPositions,
    ).filter((f) => f.episodeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playbackPositionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlaylistEpisodesTable, List<PlaylistEpisode>>
  _playlistEpisodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistEpisodes,
    aliasName: 'episodes__id__playlist_episodes__episode_id',
  );

  $$PlaylistEpisodesTableProcessedTableManager get playlistEpisodesRefs {
    final manager = $$PlaylistEpisodesTableTableManager(
      $_db,
      $_db.playlistEpisodes,
    ).filter((f) => f.episodeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistEpisodesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $EpisodeFingerprintsTable,
    List<EpisodeFingerprint>
  >
  _episodeFingerprintsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.episodeFingerprints,
        aliasName: 'episodes__id__episode_fingerprints__episode_id',
      );

  $$EpisodeFingerprintsTableProcessedTableManager get episodeFingerprintsRefs {
    final manager = $$EpisodeFingerprintsTableTableManager(
      $_db,
      $_db.episodeFingerprints,
    ).filter((f) => f.episodeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _episodeFingerprintsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SkipSegmentsTable, List<SkipSegment>>
  _skipSegmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.skipSegments,
    aliasName: 'episodes__id__skip_segments__episode_id',
  );

  $$SkipSegmentsTableProcessedTableManager get skipSegmentsRefs {
    final manager = $$SkipSegmentsTableTableManager(
      $_db,
      $_db.skipSegments,
    ).filter((f) => f.episodeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_skipSegmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EpisodeLogMelsTable, List<EpisodeLogMel>>
  _episodeLogMelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.episodeLogMels,
    aliasName: 'episodes__id__episode_log_mels__episode_id',
  );

  $$EpisodeLogMelsTableProcessedTableManager get episodeLogMelsRefs {
    final manager = $$EpisodeLogMelsTableTableManager(
      $_db,
      $_db.episodeLogMels,
    ).filter((f) => f.episodeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodeLogMelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleFold => $composableBuilder(
    column: $table.titleFold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get played => $composableBuilder(
    column: $table.played,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadPath => $composableBuilder(
    column: $table.downloadPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cachePath => $composableBuilder(
    column: $table.cachePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get queueIndex => $composableBuilder(
    column: $table.queueIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chaptersUrl => $composableBuilder(
    column: $table.chaptersUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get chaptersFetched => $composableBuilder(
    column: $table.chaptersFetched,
    builder: (column) => ColumnFilters(column),
  );

  $$PodcastsTableFilterComposer get podcastId {
    final $$PodcastsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.podcastId,
      referencedTable: $db.podcasts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastsTableFilterComposer(
            $db: $db,
            $table: $db.podcasts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> episodeChaptersRefs(
    Expression<bool> Function($$EpisodeChaptersTableFilterComposer f) f,
  ) {
    final $$EpisodeChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodeChapters,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodeChaptersTableFilterComposer(
            $db: $db,
            $table: $db.episodeChapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playbackPositionsRefs(
    Expression<bool> Function($$PlaybackPositionsTableFilterComposer f) f,
  ) {
    final $$PlaybackPositionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playbackPositions,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackPositionsTableFilterComposer(
            $db: $db,
            $table: $db.playbackPositions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playlistEpisodesRefs(
    Expression<bool> Function($$PlaylistEpisodesTableFilterComposer f) f,
  ) {
    final $$PlaylistEpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEpisodes,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEpisodesTableFilterComposer(
            $db: $db,
            $table: $db.playlistEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> episodeFingerprintsRefs(
    Expression<bool> Function($$EpisodeFingerprintsTableFilterComposer f) f,
  ) {
    final $$EpisodeFingerprintsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodeFingerprints,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodeFingerprintsTableFilterComposer(
            $db: $db,
            $table: $db.episodeFingerprints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> skipSegmentsRefs(
    Expression<bool> Function($$SkipSegmentsTableFilterComposer f) f,
  ) {
    final $$SkipSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.skipSegments,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkipSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.skipSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> episodeLogMelsRefs(
    Expression<bool> Function($$EpisodeLogMelsTableFilterComposer f) f,
  ) {
    final $$EpisodeLogMelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodeLogMels,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodeLogMelsTableFilterComposer(
            $db: $db,
            $table: $db.episodeLogMels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleFold => $composableBuilder(
    column: $table.titleFold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get played => $composableBuilder(
    column: $table.played,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadPath => $composableBuilder(
    column: $table.downloadPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cachePath => $composableBuilder(
    column: $table.cachePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get queueIndex => $composableBuilder(
    column: $table.queueIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chaptersUrl => $composableBuilder(
    column: $table.chaptersUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get chaptersFetched => $composableBuilder(
    column: $table.chaptersFetched,
    builder: (column) => ColumnOrderings(column),
  );

  $$PodcastsTableOrderingComposer get podcastId {
    final $$PodcastsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.podcastId,
      referencedTable: $db.podcasts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastsTableOrderingComposer(
            $db: $db,
            $table: $db.podcasts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get guid =>
      $composableBuilder(column: $table.guid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleFold =>
      $composableBuilder(column: $table.titleFold, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get played =>
      $composableBuilder(column: $table.played, builder: (column) => column);

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<String> get downloadPath => $composableBuilder(
    column: $table.downloadPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cachePath =>
      $composableBuilder(column: $table.cachePath, builder: (column) => column);

  GeneratedColumn<int> get queueIndex => $composableBuilder(
    column: $table.queueIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chaptersUrl => $composableBuilder(
    column: $table.chaptersUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get chaptersFetched => $composableBuilder(
    column: $table.chaptersFetched,
    builder: (column) => column,
  );

  $$PodcastsTableAnnotationComposer get podcastId {
    final $$PodcastsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.podcastId,
      referencedTable: $db.podcasts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastsTableAnnotationComposer(
            $db: $db,
            $table: $db.podcasts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> episodeChaptersRefs<T extends Object>(
    Expression<T> Function($$EpisodeChaptersTableAnnotationComposer a) f,
  ) {
    final $$EpisodeChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodeChapters,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodeChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.episodeChapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playbackPositionsRefs<T extends Object>(
    Expression<T> Function($$PlaybackPositionsTableAnnotationComposer a) f,
  ) {
    final $$PlaybackPositionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playbackPositions,
          getReferencedColumn: (t) => t.episodeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlaybackPositionsTableAnnotationComposer(
                $db: $db,
                $table: $db.playbackPositions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> playlistEpisodesRefs<T extends Object>(
    Expression<T> Function($$PlaylistEpisodesTableAnnotationComposer a) f,
  ) {
    final $$PlaylistEpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEpisodes,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> episodeFingerprintsRefs<T extends Object>(
    Expression<T> Function($$EpisodeFingerprintsTableAnnotationComposer a) f,
  ) {
    final $$EpisodeFingerprintsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.episodeFingerprints,
          getReferencedColumn: (t) => t.episodeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EpisodeFingerprintsTableAnnotationComposer(
                $db: $db,
                $table: $db.episodeFingerprints,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> skipSegmentsRefs<T extends Object>(
    Expression<T> Function($$SkipSegmentsTableAnnotationComposer a) f,
  ) {
    final $$SkipSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.skipSegments,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkipSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.skipSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> episodeLogMelsRefs<T extends Object>(
    Expression<T> Function($$EpisodeLogMelsTableAnnotationComposer a) f,
  ) {
    final $$EpisodeLogMelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodeLogMels,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodeLogMelsTableAnnotationComposer(
            $db: $db,
            $table: $db.episodeLogMels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodesTable,
          Episode,
          $$EpisodesTableFilterComposer,
          $$EpisodesTableOrderingComposer,
          $$EpisodesTableAnnotationComposer,
          $$EpisodesTableCreateCompanionBuilder,
          $$EpisodesTableUpdateCompanionBuilder,
          (Episode, $$EpisodesTableReferences),
          Episode,
          PrefetchHooks Function({
            bool podcastId,
            bool episodeChaptersRefs,
            bool playbackPositionsRefs,
            bool playlistEpisodesRefs,
            bool episodeFingerprintsRefs,
            bool skipSegmentsRefs,
            bool episodeLogMelsRefs,
          })
        > {
  $$EpisodesTableTableManager(_$AppDatabase db, $EpisodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> podcastId = const Value.absent(),
                Value<String> guid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> titleFold = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> audioUrl = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<bool> played = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<String?> downloadPath = const Value.absent(),
                Value<String?> cachePath = const Value.absent(),
                Value<int?> queueIndex = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<String?> chaptersUrl = const Value.absent(),
                Value<bool> chaptersFetched = const Value.absent(),
              }) => EpisodesCompanion(
                id: id,
                podcastId: podcastId,
                guid: guid,
                title: title,
                titleFold: titleFold,
                description: description,
                audioUrl: audioUrl,
                mimeType: mimeType,
                durationSeconds: durationSeconds,
                publishedAt: publishedAt,
                imageUrl: imageUrl,
                imagePath: imagePath,
                positionMs: positionMs,
                played: played,
                favorite: favorite,
                downloadPath: downloadPath,
                cachePath: cachePath,
                queueIndex: queueIndex,
                lastPlayedAt: lastPlayedAt,
                downloadedAt: downloadedAt,
                chaptersUrl: chaptersUrl,
                chaptersFetched: chaptersFetched,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int podcastId,
                required String guid,
                required String title,
                Value<String> titleFold = const Value.absent(),
                Value<String> description = const Value.absent(),
                required String audioUrl,
                Value<String?> mimeType = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<bool> played = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<String?> downloadPath = const Value.absent(),
                Value<String?> cachePath = const Value.absent(),
                Value<int?> queueIndex = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<String?> chaptersUrl = const Value.absent(),
                Value<bool> chaptersFetched = const Value.absent(),
              }) => EpisodesCompanion.insert(
                id: id,
                podcastId: podcastId,
                guid: guid,
                title: title,
                titleFold: titleFold,
                description: description,
                audioUrl: audioUrl,
                mimeType: mimeType,
                durationSeconds: durationSeconds,
                publishedAt: publishedAt,
                imageUrl: imageUrl,
                imagePath: imagePath,
                positionMs: positionMs,
                played: played,
                favorite: favorite,
                downloadPath: downloadPath,
                cachePath: cachePath,
                queueIndex: queueIndex,
                lastPlayedAt: lastPlayedAt,
                downloadedAt: downloadedAt,
                chaptersUrl: chaptersUrl,
                chaptersFetched: chaptersFetched,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpisodesTable, Episode>(table),
                  $$EpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                podcastId = false,
                episodeChaptersRefs = false,
                playbackPositionsRefs = false,
                playlistEpisodesRefs = false,
                episodeFingerprintsRefs = false,
                skipSegmentsRefs = false,
                episodeLogMelsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (episodeChaptersRefs) db.episodeChapters,
                    if (playbackPositionsRefs) db.playbackPositions,
                    if (playlistEpisodesRefs) db.playlistEpisodes,
                    if (episodeFingerprintsRefs) db.episodeFingerprints,
                    if (skipSegmentsRefs) db.skipSegments,
                    if (episodeLogMelsRefs) db.episodeLogMels,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (podcastId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.podcastId,
                            referencedTable: $$EpisodesTableReferences
                                ._podcastIdTable(db),
                            referencedColumn: $$EpisodesTableReferences
                                ._podcastIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (episodeChaptersRefs)
                        await $_getPrefetchedDataByColumns<
                          Episode,
                          $EpisodesTable,
                          EpisodeChapter,
                          $EpisodeChaptersTable
                        >(
                          currentTable: table,
                          referencedTable: $$EpisodesTableReferences
                              ._episodeChaptersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpisodesTableReferences(
                                db,
                                table,
                                p0,
                              ).episodeChaptersRefs,
                          currentColumn: 'id',
                          referencedColumn: 'episode_id',
                          typedResults: items,
                        ),
                      if (playbackPositionsRefs)
                        await $_getPrefetchedDataByColumns<
                          Episode,
                          $EpisodesTable,
                          PlaybackPosition,
                          $PlaybackPositionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$EpisodesTableReferences
                              ._playbackPositionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpisodesTableReferences(
                                db,
                                table,
                                p0,
                              ).playbackPositionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'episode_id',
                          typedResults: items,
                        ),
                      if (playlistEpisodesRefs)
                        await $_getPrefetchedDataByColumns<
                          Episode,
                          $EpisodesTable,
                          PlaylistEpisode,
                          $PlaylistEpisodesTable
                        >(
                          currentTable: table,
                          referencedTable: $$EpisodesTableReferences
                              ._playlistEpisodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpisodesTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistEpisodesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'episode_id',
                          typedResults: items,
                        ),
                      if (episodeFingerprintsRefs)
                        await $_getPrefetchedDataByColumns<
                          Episode,
                          $EpisodesTable,
                          EpisodeFingerprint,
                          $EpisodeFingerprintsTable
                        >(
                          currentTable: table,
                          referencedTable: $$EpisodesTableReferences
                              ._episodeFingerprintsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpisodesTableReferences(
                                db,
                                table,
                                p0,
                              ).episodeFingerprintsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'episode_id',
                          typedResults: items,
                        ),
                      if (skipSegmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          Episode,
                          $EpisodesTable,
                          SkipSegment,
                          $SkipSegmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$EpisodesTableReferences
                              ._skipSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpisodesTableReferences(
                                db,
                                table,
                                p0,
                              ).skipSegmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'episode_id',
                          typedResults: items,
                        ),
                      if (episodeLogMelsRefs)
                        await $_getPrefetchedDataByColumns<
                          Episode,
                          $EpisodesTable,
                          EpisodeLogMel,
                          $EpisodeLogMelsTable
                        >(
                          currentTable: table,
                          referencedTable: $$EpisodesTableReferences
                              ._episodeLogMelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpisodesTableReferences(
                                db,
                                table,
                                p0,
                              ).episodeLogMelsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'episode_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$EpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodesTable,
      Episode,
      $$EpisodesTableFilterComposer,
      $$EpisodesTableOrderingComposer,
      $$EpisodesTableAnnotationComposer,
      $$EpisodesTableCreateCompanionBuilder,
      $$EpisodesTableUpdateCompanionBuilder,
      (Episode, $$EpisodesTableReferences),
      Episode,
      PrefetchHooks Function({
        bool podcastId,
        bool episodeChaptersRefs,
        bool playbackPositionsRefs,
        bool playlistEpisodesRefs,
        bool episodeFingerprintsRefs,
        bool skipSegmentsRefs,
        bool episodeLogMelsRefs,
      })
    >;
typedef $$EpisodeChaptersTableCreateCompanionBuilder =
    EpisodeChaptersCompanion Function({
      Value<int> id,
      required int episodeId,
      required int startMs,
      Value<String> title,
      Value<String?> link,
      Value<bool> toc,
      Value<int> sortIndex,
    });
typedef $$EpisodeChaptersTableUpdateCompanionBuilder =
    EpisodeChaptersCompanion Function({
      Value<int> id,
      Value<int> episodeId,
      Value<int> startMs,
      Value<String> title,
      Value<String?> link,
      Value<bool> toc,
      Value<int> sortIndex,
    });

final class $$EpisodeChaptersTableReferences
    extends
        BaseReferences<_$AppDatabase, $EpisodeChaptersTable, EpisodeChapter> {
  $$EpisodeChaptersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EpisodesTable _episodeIdTable(_$AppDatabase db) =>
      db.episodes.createAlias('episode_chapters__episode_id__episodes__id');

  $$EpisodesTableProcessedTableManager get episodeId {
    final $_column = $_itemColumn<int>('episode_id')!;

    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_episodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpisodeChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodeChaptersTable> {
  $$EpisodeChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get toc => $composableBuilder(
    column: $table.toc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$EpisodesTableFilterComposer get episodeId {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodeChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodeChaptersTable> {
  $$EpisodeChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get toc => $composableBuilder(
    column: $table.toc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$EpisodesTableOrderingComposer get episodeId {
    final $$EpisodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableOrderingComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodeChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodeChaptersTable> {
  $$EpisodeChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);

  GeneratedColumn<bool> get toc =>
      $composableBuilder(column: $table.toc, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  $$EpisodesTableAnnotationComposer get episodeId {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodeChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodeChaptersTable,
          EpisodeChapter,
          $$EpisodeChaptersTableFilterComposer,
          $$EpisodeChaptersTableOrderingComposer,
          $$EpisodeChaptersTableAnnotationComposer,
          $$EpisodeChaptersTableCreateCompanionBuilder,
          $$EpisodeChaptersTableUpdateCompanionBuilder,
          (EpisodeChapter, $$EpisodeChaptersTableReferences),
          EpisodeChapter,
          PrefetchHooks Function({bool episodeId})
        > {
  $$EpisodeChaptersTableTableManager(
    _$AppDatabase db,
    $EpisodeChaptersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodeChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodeChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodeChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> episodeId = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<bool> toc = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
              }) => EpisodeChaptersCompanion(
                id: id,
                episodeId: episodeId,
                startMs: startMs,
                title: title,
                link: link,
                toc: toc,
                sortIndex: sortIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int episodeId,
                required int startMs,
                Value<String> title = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<bool> toc = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
              }) => EpisodeChaptersCompanion.insert(
                id: id,
                episodeId: episodeId,
                startMs: startMs,
                title: title,
                link: link,
                toc: toc,
                sortIndex: sortIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpisodeChaptersTable, EpisodeChapter>(table),
                  $$EpisodeChaptersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (episodeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.episodeId,
                        referencedTable: $$EpisodeChaptersTableReferences
                            ._episodeIdTable(db),
                        referencedColumn: $$EpisodeChaptersTableReferences
                            ._episodeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpisodeChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodeChaptersTable,
      EpisodeChapter,
      $$EpisodeChaptersTableFilterComposer,
      $$EpisodeChaptersTableOrderingComposer,
      $$EpisodeChaptersTableAnnotationComposer,
      $$EpisodeChaptersTableCreateCompanionBuilder,
      $$EpisodeChaptersTableUpdateCompanionBuilder,
      (EpisodeChapter, $$EpisodeChaptersTableReferences),
      EpisodeChapter,
      PrefetchHooks Function({bool episodeId})
    >;
typedef $$PlaybackPositionsTableCreateCompanionBuilder =
    PlaybackPositionsCompanion Function({
      Value<int> episodeId,
      Value<int> positionMs,
    });
typedef $$PlaybackPositionsTableUpdateCompanionBuilder =
    PlaybackPositionsCompanion Function({
      Value<int> episodeId,
      Value<int> positionMs,
    });

final class $$PlaybackPositionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlaybackPositionsTable,
          PlaybackPosition
        > {
  $$PlaybackPositionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EpisodesTable _episodeIdTable(_$AppDatabase db) =>
      db.episodes.createAlias('playback_positions__episode_id__episodes__id');

  $$EpisodesTableProcessedTableManager get episodeId {
    final $_column = $_itemColumn<int>('episode_id')!;

    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_episodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaybackPositionsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTable> {
  $$PlaybackPositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  $$EpisodesTableFilterComposer get episodeId {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackPositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTable> {
  $$PlaybackPositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$EpisodesTableOrderingComposer get episodeId {
    final $$EpisodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableOrderingComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackPositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTable> {
  $$PlaybackPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  $$EpisodesTableAnnotationComposer get episodeId {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackPositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackPositionsTable,
          PlaybackPosition,
          $$PlaybackPositionsTableFilterComposer,
          $$PlaybackPositionsTableOrderingComposer,
          $$PlaybackPositionsTableAnnotationComposer,
          $$PlaybackPositionsTableCreateCompanionBuilder,
          $$PlaybackPositionsTableUpdateCompanionBuilder,
          (PlaybackPosition, $$PlaybackPositionsTableReferences),
          PlaybackPosition,
          PrefetchHooks Function({bool episodeId})
        > {
  $$PlaybackPositionsTableTableManager(
    _$AppDatabase db,
    $PlaybackPositionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackPositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackPositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackPositionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> episodeId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
              }) => PlaybackPositionsCompanion(
                episodeId: episodeId,
                positionMs: positionMs,
              ),
          createCompanionCallback:
              ({
                Value<int> episodeId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
              }) => PlaybackPositionsCompanion.insert(
                episodeId: episodeId,
                positionMs: positionMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaybackPositionsTable, PlaybackPosition>(table),
                  $$PlaybackPositionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (episodeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.episodeId,
                        referencedTable: $$PlaybackPositionsTableReferences
                            ._episodeIdTable(db),
                        referencedColumn: $$PlaybackPositionsTableReferences
                            ._episodeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaybackPositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackPositionsTable,
      PlaybackPosition,
      $$PlaybackPositionsTableFilterComposer,
      $$PlaybackPositionsTableOrderingComposer,
      $$PlaybackPositionsTableAnnotationComposer,
      $$PlaybackPositionsTableCreateCompanionBuilder,
      $$PlaybackPositionsTableUpdateCompanionBuilder,
      (PlaybackPosition, $$PlaybackPositionsTableReferences),
      PlaybackPosition,
      PrefetchHooks Function({bool episodeId})
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
  Value<bool> isDefault,
  required DateTime createdAt,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<bool> isDefault,
  Value<DateTime> createdAt,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistEpisodesTable, List<PlaylistEpisode>>
  _playlistEpisodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistEpisodes,
    aliasName: 'playlists__id__playlist_episodes__playlist_id',
  );

  $$PlaylistEpisodesTableProcessedTableManager get playlistEpisodesRefs {
    final manager = $$PlaylistEpisodesTableTableManager(
      $_db,
      $_db.playlistEpisodes,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistEpisodesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistEpisodesRefs(
    Expression<bool> Function($$PlaylistEpisodesTableFilterComposer f) f,
  ) {
    final $$PlaylistEpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEpisodes,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEpisodesTableFilterComposer(
            $db: $db,
            $table: $db.playlistEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> playlistEpisodesRefs<T extends Object>(
    Expression<T> Function($$PlaylistEpisodesTableAnnotationComposer a) f,
  ) {
    final $$PlaylistEpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEpisodes,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, $$PlaylistsTableReferences),
          Playlist,
          PrefetchHooks Function({bool playlistEpisodesRefs})
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                isDefault: isDefault,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> isDefault = const Value.absent(),
                required DateTime createdAt,
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                isDefault: isDefault,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, Playlist>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistEpisodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistEpisodesRefs) db.playlistEpisodes,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistEpisodesRefs)
                    await $_getPrefetchedDataByColumns<
                      Playlist,
                      $PlaylistsTable,
                      PlaylistEpisode,
                      $PlaylistEpisodesTable
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistEpisodesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistEpisodesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'playlist_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, $$PlaylistsTableReferences),
      Playlist,
      PrefetchHooks Function({bool playlistEpisodesRefs})
    >;
typedef $$PlaylistEpisodesTableCreateCompanionBuilder =
    PlaylistEpisodesCompanion Function({
      required int playlistId,
      required int episodeId,
      required int position,
      Value<int> rowid,
    });
typedef $$PlaylistEpisodesTableUpdateCompanionBuilder =
    PlaylistEpisodesCompanion Function({
      Value<int> playlistId,
      Value<int> episodeId,
      Value<int> position,
      Value<int> rowid,
    });

final class $$PlaylistEpisodesTableReferences
    extends
        BaseReferences<_$AppDatabase, $PlaylistEpisodesTable, PlaylistEpisode> {
  $$PlaylistEpisodesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_episodes__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EpisodesTable _episodeIdTable(_$AppDatabase db) =>
      db.episodes.createAlias('playlist_episodes__episode_id__episodes__id');

  $$EpisodesTableProcessedTableManager get episodeId {
    final $_column = $_itemColumn<int>('episode_id')!;

    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_episodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistEpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistEpisodesTable> {
  $$PlaylistEpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EpisodesTableFilterComposer get episodeId {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistEpisodesTable> {
  $$PlaylistEpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EpisodesTableOrderingComposer get episodeId {
    final $$EpisodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableOrderingComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistEpisodesTable> {
  $$PlaylistEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EpisodesTableAnnotationComposer get episodeId {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistEpisodesTable,
          PlaylistEpisode,
          $$PlaylistEpisodesTableFilterComposer,
          $$PlaylistEpisodesTableOrderingComposer,
          $$PlaylistEpisodesTableAnnotationComposer,
          $$PlaylistEpisodesTableCreateCompanionBuilder,
          $$PlaylistEpisodesTableUpdateCompanionBuilder,
          (PlaylistEpisode, $$PlaylistEpisodesTableReferences),
          PlaylistEpisode,
          PrefetchHooks Function({bool playlistId, bool episodeId})
        > {
  $$PlaylistEpisodesTableTableManager(
    _$AppDatabase db,
    $PlaylistEpisodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistEpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<int> episodeId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistEpisodesCompanion(
                playlistId: playlistId,
                episodeId: episodeId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int playlistId,
                required int episodeId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistEpisodesCompanion.insert(
                playlistId: playlistId,
                episodeId: episodeId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistEpisodesTable, PlaylistEpisode>(table),
                  $$PlaylistEpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false, episodeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistEpisodesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistEpisodesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (episodeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.episodeId,
                        referencedTable: $$PlaylistEpisodesTableReferences
                            ._episodeIdTable(db),
                        referencedColumn: $$PlaylistEpisodesTableReferences
                            ._episodeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistEpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistEpisodesTable,
      PlaylistEpisode,
      $$PlaylistEpisodesTableFilterComposer,
      $$PlaylistEpisodesTableOrderingComposer,
      $$PlaylistEpisodesTableAnnotationComposer,
      $$PlaylistEpisodesTableCreateCompanionBuilder,
      $$PlaylistEpisodesTableUpdateCompanionBuilder,
      (PlaylistEpisode, $$PlaylistEpisodesTableReferences),
      PlaylistEpisode,
      PrefetchHooks Function({bool playlistId, bool episodeId})
    >;
typedef $$EpisodeFingerprintsTableCreateCompanionBuilder =
    EpisodeFingerprintsCompanion Function({
      Value<int> episodeId,
      required Uint8List data,
      required int hopMicros,
      Value<Uint8List?> speech,
      required DateTime createdAt,
    });
typedef $$EpisodeFingerprintsTableUpdateCompanionBuilder =
    EpisodeFingerprintsCompanion Function({
      Value<int> episodeId,
      Value<Uint8List> data,
      Value<int> hopMicros,
      Value<Uint8List?> speech,
      Value<DateTime> createdAt,
    });

final class $$EpisodeFingerprintsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EpisodeFingerprintsTable,
          EpisodeFingerprint
        > {
  $$EpisodeFingerprintsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EpisodesTable _episodeIdTable(_$AppDatabase db) =>
      db.episodes.createAlias('episode_fingerprints__episode_id__episodes__id');

  $$EpisodesTableProcessedTableManager get episodeId {
    final $_column = $_itemColumn<int>('episode_id')!;

    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_episodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpisodeFingerprintsTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodeFingerprintsTable> {
  $$EpisodeFingerprintsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hopMicros => $composableBuilder(
    column: $table.hopMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get speech => $composableBuilder(
    column: $table.speech,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EpisodesTableFilterComposer get episodeId {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodeFingerprintsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodeFingerprintsTable> {
  $$EpisodeFingerprintsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hopMicros => $composableBuilder(
    column: $table.hopMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get speech => $composableBuilder(
    column: $table.speech,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EpisodesTableOrderingComposer get episodeId {
    final $$EpisodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableOrderingComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodeFingerprintsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodeFingerprintsTable> {
  $$EpisodeFingerprintsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get hopMicros =>
      $composableBuilder(column: $table.hopMicros, builder: (column) => column);

  GeneratedColumn<Uint8List> get speech =>
      $composableBuilder(column: $table.speech, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$EpisodesTableAnnotationComposer get episodeId {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodeFingerprintsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodeFingerprintsTable,
          EpisodeFingerprint,
          $$EpisodeFingerprintsTableFilterComposer,
          $$EpisodeFingerprintsTableOrderingComposer,
          $$EpisodeFingerprintsTableAnnotationComposer,
          $$EpisodeFingerprintsTableCreateCompanionBuilder,
          $$EpisodeFingerprintsTableUpdateCompanionBuilder,
          (EpisodeFingerprint, $$EpisodeFingerprintsTableReferences),
          EpisodeFingerprint,
          PrefetchHooks Function({bool episodeId})
        > {
  $$EpisodeFingerprintsTableTableManager(
    _$AppDatabase db,
    $EpisodeFingerprintsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodeFingerprintsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodeFingerprintsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EpisodeFingerprintsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> episodeId = const Value.absent(),
                Value<Uint8List> data = const Value.absent(),
                Value<int> hopMicros = const Value.absent(),
                Value<Uint8List?> speech = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => EpisodeFingerprintsCompanion(
                episodeId: episodeId,
                data: data,
                hopMicros: hopMicros,
                speech: speech,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> episodeId = const Value.absent(),
                required Uint8List data,
                required int hopMicros,
                Value<Uint8List?> speech = const Value.absent(),
                required DateTime createdAt,
              }) => EpisodeFingerprintsCompanion.insert(
                episodeId: episodeId,
                data: data,
                hopMicros: hopMicros,
                speech: speech,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpisodeFingerprintsTable, EpisodeFingerprint>(
                    table,
                  ),
                  $$EpisodeFingerprintsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (episodeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.episodeId,
                        referencedTable: $$EpisodeFingerprintsTableReferences
                            ._episodeIdTable(db),
                        referencedColumn: $$EpisodeFingerprintsTableReferences
                            ._episodeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpisodeFingerprintsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodeFingerprintsTable,
      EpisodeFingerprint,
      $$EpisodeFingerprintsTableFilterComposer,
      $$EpisodeFingerprintsTableOrderingComposer,
      $$EpisodeFingerprintsTableAnnotationComposer,
      $$EpisodeFingerprintsTableCreateCompanionBuilder,
      $$EpisodeFingerprintsTableUpdateCompanionBuilder,
      (EpisodeFingerprint, $$EpisodeFingerprintsTableReferences),
      EpisodeFingerprint,
      PrefetchHooks Function({bool episodeId})
    >;
typedef $$SegmentTemplatesTableCreateCompanionBuilder =
    SegmentTemplatesCompanion Function({
      Value<int> id,
      required int podcastId,
      required SkipSegmentKind kind,
      Value<String?> label,
      required Uint8List fingerprint,
      Value<Uint8List?> logMel,
      required int durationMs,
      Value<int> occurrences,
      Value<int?> confidence,
      required DateTime createdAt,
    });
typedef $$SegmentTemplatesTableUpdateCompanionBuilder =
    SegmentTemplatesCompanion Function({
      Value<int> id,
      Value<int> podcastId,
      Value<SkipSegmentKind> kind,
      Value<String?> label,
      Value<Uint8List> fingerprint,
      Value<Uint8List?> logMel,
      Value<int> durationMs,
      Value<int> occurrences,
      Value<int?> confidence,
      Value<DateTime> createdAt,
    });

final class $$SegmentTemplatesTableReferences
    extends
        BaseReferences<_$AppDatabase, $SegmentTemplatesTable, SegmentTemplate> {
  $$SegmentTemplatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PodcastsTable _podcastIdTable(_$AppDatabase db) =>
      db.podcasts.createAlias('segment_templates__podcast_id__podcasts__id');

  $$PodcastsTableProcessedTableManager get podcastId {
    final $_column = $_itemColumn<int>('podcast_id')!;

    final manager = $$PodcastsTableTableManager(
      $_db,
      $_db.podcasts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_podcastIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SkipSegmentsTable, List<SkipSegment>>
  _skipSegmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.skipSegments,
    aliasName: 'segment_templates__id__skip_segments__template_id',
  );

  $$SkipSegmentsTableProcessedTableManager get skipSegmentsRefs {
    final manager = $$SkipSegmentsTableTableManager(
      $_db,
      $_db.skipSegments,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_skipSegmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SegmentTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $SegmentTemplatesTable> {
  $$SegmentTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SkipSegmentKind, SkipSegmentKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get logMel => $composableBuilder(
    column: $table.logMel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrences => $composableBuilder(
    column: $table.occurrences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PodcastsTableFilterComposer get podcastId {
    final $$PodcastsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.podcastId,
      referencedTable: $db.podcasts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastsTableFilterComposer(
            $db: $db,
            $table: $db.podcasts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> skipSegmentsRefs(
    Expression<bool> Function($$SkipSegmentsTableFilterComposer f) f,
  ) {
    final $$SkipSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.skipSegments,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkipSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.skipSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SegmentTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SegmentTemplatesTable> {
  $$SegmentTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get logMel => $composableBuilder(
    column: $table.logMel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrences => $composableBuilder(
    column: $table.occurrences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PodcastsTableOrderingComposer get podcastId {
    final $$PodcastsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.podcastId,
      referencedTable: $db.podcasts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastsTableOrderingComposer(
            $db: $db,
            $table: $db.podcasts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SegmentTemplatesTable> {
  $$SegmentTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SkipSegmentKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<Uint8List> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get logMel =>
      $composableBuilder(column: $table.logMel, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get occurrences => $composableBuilder(
    column: $table.occurrences,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PodcastsTableAnnotationComposer get podcastId {
    final $$PodcastsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.podcastId,
      referencedTable: $db.podcasts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastsTableAnnotationComposer(
            $db: $db,
            $table: $db.podcasts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> skipSegmentsRefs<T extends Object>(
    Expression<T> Function($$SkipSegmentsTableAnnotationComposer a) f,
  ) {
    final $$SkipSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.skipSegments,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkipSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.skipSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SegmentTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SegmentTemplatesTable,
          SegmentTemplate,
          $$SegmentTemplatesTableFilterComposer,
          $$SegmentTemplatesTableOrderingComposer,
          $$SegmentTemplatesTableAnnotationComposer,
          $$SegmentTemplatesTableCreateCompanionBuilder,
          $$SegmentTemplatesTableUpdateCompanionBuilder,
          (SegmentTemplate, $$SegmentTemplatesTableReferences),
          SegmentTemplate,
          PrefetchHooks Function({bool podcastId, bool skipSegmentsRefs})
        > {
  $$SegmentTemplatesTableTableManager(
    _$AppDatabase db,
    $SegmentTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SegmentTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SegmentTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SegmentTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> podcastId = const Value.absent(),
                Value<SkipSegmentKind> kind = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<Uint8List> fingerprint = const Value.absent(),
                Value<Uint8List?> logMel = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> occurrences = const Value.absent(),
                Value<int?> confidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SegmentTemplatesCompanion(
                id: id,
                podcastId: podcastId,
                kind: kind,
                label: label,
                fingerprint: fingerprint,
                logMel: logMel,
                durationMs: durationMs,
                occurrences: occurrences,
                confidence: confidence,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int podcastId,
                required SkipSegmentKind kind,
                Value<String?> label = const Value.absent(),
                required Uint8List fingerprint,
                Value<Uint8List?> logMel = const Value.absent(),
                required int durationMs,
                Value<int> occurrences = const Value.absent(),
                Value<int?> confidence = const Value.absent(),
                required DateTime createdAt,
              }) => SegmentTemplatesCompanion.insert(
                id: id,
                podcastId: podcastId,
                kind: kind,
                label: label,
                fingerprint: fingerprint,
                logMel: logMel,
                durationMs: durationMs,
                occurrences: occurrences,
                confidence: confidence,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SegmentTemplatesTable, SegmentTemplate>(table),
                  $$SegmentTemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({podcastId = false, skipSegmentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (skipSegmentsRefs) db.skipSegments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (podcastId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.podcastId,
                            referencedTable: $$SegmentTemplatesTableReferences
                                ._podcastIdTable(db),
                            referencedColumn: $$SegmentTemplatesTableReferences
                                ._podcastIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (skipSegmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          SegmentTemplate,
                          $SegmentTemplatesTable,
                          SkipSegment,
                          $SkipSegmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SegmentTemplatesTableReferences
                              ._skipSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SegmentTemplatesTableReferences(
                                db,
                                table,
                                p0,
                              ).skipSegmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'template_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SegmentTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SegmentTemplatesTable,
      SegmentTemplate,
      $$SegmentTemplatesTableFilterComposer,
      $$SegmentTemplatesTableOrderingComposer,
      $$SegmentTemplatesTableAnnotationComposer,
      $$SegmentTemplatesTableCreateCompanionBuilder,
      $$SegmentTemplatesTableUpdateCompanionBuilder,
      (SegmentTemplate, $$SegmentTemplatesTableReferences),
      SegmentTemplate,
      PrefetchHooks Function({bool podcastId, bool skipSegmentsRefs})
    >;
typedef $$SkipSegmentsTableCreateCompanionBuilder =
    SkipSegmentsCompanion Function({
      Value<int> id,
      required int episodeId,
      required int startMs,
      required int endMs,
      required SkipSegmentKind kind,
      required SkipSegmentSource source,
      Value<int> matches,
      Value<bool?> confirmed,
      Value<int?> confidence,
      Value<int?> templateId,
    });
typedef $$SkipSegmentsTableUpdateCompanionBuilder =
    SkipSegmentsCompanion Function({
      Value<int> id,
      Value<int> episodeId,
      Value<int> startMs,
      Value<int> endMs,
      Value<SkipSegmentKind> kind,
      Value<SkipSegmentSource> source,
      Value<int> matches,
      Value<bool?> confirmed,
      Value<int?> confidence,
      Value<int?> templateId,
    });

final class $$SkipSegmentsTableReferences
    extends BaseReferences<_$AppDatabase, $SkipSegmentsTable, SkipSegment> {
  $$SkipSegmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EpisodesTable _episodeIdTable(_$AppDatabase db) =>
      db.episodes.createAlias('skip_segments__episode_id__episodes__id');

  $$EpisodesTableProcessedTableManager get episodeId {
    final $_column = $_itemColumn<int>('episode_id')!;

    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_episodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SegmentTemplatesTable _templateIdTable(_$AppDatabase db) => db
      .segmentTemplates
      .createAlias('skip_segments__template_id__segment_templates__id');

  $$SegmentTemplatesTableProcessedTableManager? get templateId {
    final $_column = $_itemColumn<int>('template_id');
    if ($_column == null) return null;
    final manager = $$SegmentTemplatesTableTableManager(
      $_db,
      $_db.segmentTemplates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SkipSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $SkipSegmentsTable> {
  $$SkipSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SkipSegmentKind, SkipSegmentKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<SkipSegmentSource, SkipSegmentSource, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get matches => $composableBuilder(
    column: $table.matches,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get confirmed => $composableBuilder(
    column: $table.confirmed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  $$EpisodesTableFilterComposer get episodeId {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SegmentTemplatesTableFilterComposer get templateId {
    final $$SegmentTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.segmentTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.segmentTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SkipSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $SkipSegmentsTable> {
  $$SkipSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get matches => $composableBuilder(
    column: $table.matches,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get confirmed => $composableBuilder(
    column: $table.confirmed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  $$EpisodesTableOrderingComposer get episodeId {
    final $$EpisodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableOrderingComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SegmentTemplatesTableOrderingComposer get templateId {
    final $$SegmentTemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.segmentTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentTemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.segmentTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SkipSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SkipSegmentsTable> {
  $$SkipSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SkipSegmentKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SkipSegmentSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get matches =>
      $composableBuilder(column: $table.matches, builder: (column) => column);

  GeneratedColumn<bool> get confirmed =>
      $composableBuilder(column: $table.confirmed, builder: (column) => column);

  GeneratedColumn<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  $$EpisodesTableAnnotationComposer get episodeId {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SegmentTemplatesTableAnnotationComposer get templateId {
    final $$SegmentTemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.segmentTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentTemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.segmentTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SkipSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SkipSegmentsTable,
          SkipSegment,
          $$SkipSegmentsTableFilterComposer,
          $$SkipSegmentsTableOrderingComposer,
          $$SkipSegmentsTableAnnotationComposer,
          $$SkipSegmentsTableCreateCompanionBuilder,
          $$SkipSegmentsTableUpdateCompanionBuilder,
          (SkipSegment, $$SkipSegmentsTableReferences),
          SkipSegment,
          PrefetchHooks Function({bool episodeId, bool templateId})
        > {
  $$SkipSegmentsTableTableManager(_$AppDatabase db, $SkipSegmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SkipSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SkipSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SkipSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> episodeId = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<SkipSegmentKind> kind = const Value.absent(),
                Value<SkipSegmentSource> source = const Value.absent(),
                Value<int> matches = const Value.absent(),
                Value<bool?> confirmed = const Value.absent(),
                Value<int?> confidence = const Value.absent(),
                Value<int?> templateId = const Value.absent(),
              }) => SkipSegmentsCompanion(
                id: id,
                episodeId: episodeId,
                startMs: startMs,
                endMs: endMs,
                kind: kind,
                source: source,
                matches: matches,
                confirmed: confirmed,
                confidence: confidence,
                templateId: templateId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int episodeId,
                required int startMs,
                required int endMs,
                required SkipSegmentKind kind,
                required SkipSegmentSource source,
                Value<int> matches = const Value.absent(),
                Value<bool?> confirmed = const Value.absent(),
                Value<int?> confidence = const Value.absent(),
                Value<int?> templateId = const Value.absent(),
              }) => SkipSegmentsCompanion.insert(
                id: id,
                episodeId: episodeId,
                startMs: startMs,
                endMs: endMs,
                kind: kind,
                source: source,
                matches: matches,
                confirmed: confirmed,
                confidence: confidence,
                templateId: templateId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SkipSegmentsTable, SkipSegment>(table),
                  $$SkipSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodeId = false, templateId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (episodeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.episodeId,
                        referencedTable: $$SkipSegmentsTableReferences
                            ._episodeIdTable(db),
                        referencedColumn: $$SkipSegmentsTableReferences
                            ._episodeIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (templateId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.templateId,
                        referencedTable: $$SkipSegmentsTableReferences
                            ._templateIdTable(db),
                        referencedColumn: $$SkipSegmentsTableReferences
                            ._templateIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SkipSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SkipSegmentsTable,
      SkipSegment,
      $$SkipSegmentsTableFilterComposer,
      $$SkipSegmentsTableOrderingComposer,
      $$SkipSegmentsTableAnnotationComposer,
      $$SkipSegmentsTableCreateCompanionBuilder,
      $$SkipSegmentsTableUpdateCompanionBuilder,
      (SkipSegment, $$SkipSegmentsTableReferences),
      SkipSegment,
      PrefetchHooks Function({bool episodeId, bool templateId})
    >;
typedef $$EpisodeLogMelsTableCreateCompanionBuilder =
    EpisodeLogMelsCompanion Function({
      Value<int> episodeId,
      required Uint8List data,
      required int hopMs,
      required DateTime createdAt,
    });
typedef $$EpisodeLogMelsTableUpdateCompanionBuilder =
    EpisodeLogMelsCompanion Function({
      Value<int> episodeId,
      Value<Uint8List> data,
      Value<int> hopMs,
      Value<DateTime> createdAt,
    });

final class $$EpisodeLogMelsTableReferences
    extends BaseReferences<_$AppDatabase, $EpisodeLogMelsTable, EpisodeLogMel> {
  $$EpisodeLogMelsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EpisodesTable _episodeIdTable(_$AppDatabase db) =>
      db.episodes.createAlias('episode_log_mels__episode_id__episodes__id');

  $$EpisodesTableProcessedTableManager get episodeId {
    final $_column = $_itemColumn<int>('episode_id')!;

    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_episodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpisodeLogMelsTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodeLogMelsTable> {
  $$EpisodeLogMelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hopMs => $composableBuilder(
    column: $table.hopMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EpisodesTableFilterComposer get episodeId {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodeLogMelsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodeLogMelsTable> {
  $$EpisodeLogMelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hopMs => $composableBuilder(
    column: $table.hopMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EpisodesTableOrderingComposer get episodeId {
    final $$EpisodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableOrderingComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodeLogMelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodeLogMelsTable> {
  $$EpisodeLogMelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get hopMs =>
      $composableBuilder(column: $table.hopMs, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$EpisodesTableAnnotationComposer get episodeId {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodeLogMelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodeLogMelsTable,
          EpisodeLogMel,
          $$EpisodeLogMelsTableFilterComposer,
          $$EpisodeLogMelsTableOrderingComposer,
          $$EpisodeLogMelsTableAnnotationComposer,
          $$EpisodeLogMelsTableCreateCompanionBuilder,
          $$EpisodeLogMelsTableUpdateCompanionBuilder,
          (EpisodeLogMel, $$EpisodeLogMelsTableReferences),
          EpisodeLogMel,
          PrefetchHooks Function({bool episodeId})
        > {
  $$EpisodeLogMelsTableTableManager(
    _$AppDatabase db,
    $EpisodeLogMelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodeLogMelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodeLogMelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodeLogMelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> episodeId = const Value.absent(),
                Value<Uint8List> data = const Value.absent(),
                Value<int> hopMs = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => EpisodeLogMelsCompanion(
                episodeId: episodeId,
                data: data,
                hopMs: hopMs,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> episodeId = const Value.absent(),
                required Uint8List data,
                required int hopMs,
                required DateTime createdAt,
              }) => EpisodeLogMelsCompanion.insert(
                episodeId: episodeId,
                data: data,
                hopMs: hopMs,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpisodeLogMelsTable, EpisodeLogMel>(table),
                  $$EpisodeLogMelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (episodeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.episodeId,
                        referencedTable: $$EpisodeLogMelsTableReferences
                            ._episodeIdTable(db),
                        referencedColumn: $$EpisodeLogMelsTableReferences
                            ._episodeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpisodeLogMelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodeLogMelsTable,
      EpisodeLogMel,
      $$EpisodeLogMelsTableFilterComposer,
      $$EpisodeLogMelsTableOrderingComposer,
      $$EpisodeLogMelsTableAnnotationComposer,
      $$EpisodeLogMelsTableCreateCompanionBuilder,
      $$EpisodeLogMelsTableUpdateCompanionBuilder,
      (EpisodeLogMel, $$EpisodeLogMelsTableReferences),
      EpisodeLogMel,
      PrefetchHooks Function({bool episodeId})
    >;
typedef $$LearnedNetworkStingsTableCreateCompanionBuilder =
    LearnedNetworkStingsCompanion Function({
      Value<int> id,
      Value<String?> name,
      required Uint8List logMel,
      required int durationMs,
      Value<int> episodeCount,
      Value<int> podcastCount,
      required DateTime createdAt,
    });
typedef $$LearnedNetworkStingsTableUpdateCompanionBuilder =
    LearnedNetworkStingsCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<Uint8List> logMel,
      Value<int> durationMs,
      Value<int> episodeCount,
      Value<int> podcastCount,
      Value<DateTime> createdAt,
    });

class $$LearnedNetworkStingsTableFilterComposer
    extends Composer<_$AppDatabase, $LearnedNetworkStingsTable> {
  $$LearnedNetworkStingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get logMel => $composableBuilder(
    column: $table.logMel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get podcastCount => $composableBuilder(
    column: $table.podcastCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearnedNetworkStingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LearnedNetworkStingsTable> {
  $$LearnedNetworkStingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get logMel => $composableBuilder(
    column: $table.logMel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get podcastCount => $composableBuilder(
    column: $table.podcastCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearnedNetworkStingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearnedNetworkStingsTable> {
  $$LearnedNetworkStingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<Uint8List> get logMel =>
      $composableBuilder(column: $table.logMel, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get podcastCount => $composableBuilder(
    column: $table.podcastCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LearnedNetworkStingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearnedNetworkStingsTable,
          LearnedNetworkSting,
          $$LearnedNetworkStingsTableFilterComposer,
          $$LearnedNetworkStingsTableOrderingComposer,
          $$LearnedNetworkStingsTableAnnotationComposer,
          $$LearnedNetworkStingsTableCreateCompanionBuilder,
          $$LearnedNetworkStingsTableUpdateCompanionBuilder,
          (
            LearnedNetworkSting,
            BaseReferences<
              _$AppDatabase,
              $LearnedNetworkStingsTable,
              LearnedNetworkSting
            >,
          ),
          LearnedNetworkSting,
          PrefetchHooks Function()
        > {
  $$LearnedNetworkStingsTableTableManager(
    _$AppDatabase db,
    $LearnedNetworkStingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearnedNetworkStingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearnedNetworkStingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LearnedNetworkStingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<Uint8List> logMel = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> episodeCount = const Value.absent(),
                Value<int> podcastCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LearnedNetworkStingsCompanion(
                id: id,
                name: name,
                logMel: logMel,
                durationMs: durationMs,
                episodeCount: episodeCount,
                podcastCount: podcastCount,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                required Uint8List logMel,
                required int durationMs,
                Value<int> episodeCount = const Value.absent(),
                Value<int> podcastCount = const Value.absent(),
                required DateTime createdAt,
              }) => LearnedNetworkStingsCompanion.insert(
                id: id,
                name: name,
                logMel: logMel,
                durationMs: durationMs,
                episodeCount: episodeCount,
                podcastCount: podcastCount,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearnedNetworkStingsTable, LearnedNetworkSting>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LearnedNetworkStingsTable,
                    LearnedNetworkSting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearnedNetworkStingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearnedNetworkStingsTable,
      LearnedNetworkSting,
      $$LearnedNetworkStingsTableFilterComposer,
      $$LearnedNetworkStingsTableOrderingComposer,
      $$LearnedNetworkStingsTableAnnotationComposer,
      $$LearnedNetworkStingsTableCreateCompanionBuilder,
      $$LearnedNetworkStingsTableUpdateCompanionBuilder,
      (
        LearnedNetworkSting,
        BaseReferences<
          _$AppDatabase,
          $LearnedNetworkStingsTable,
          LearnedNetworkSting
        >,
      ),
      LearnedNetworkSting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PodcastsTableTableManager get podcasts =>
      $$PodcastsTableTableManager(_db, _db.podcasts);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$EpisodeChaptersTableTableManager get episodeChapters =>
      $$EpisodeChaptersTableTableManager(_db, _db.episodeChapters);
  $$PlaybackPositionsTableTableManager get playbackPositions =>
      $$PlaybackPositionsTableTableManager(_db, _db.playbackPositions);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistEpisodesTableTableManager get playlistEpisodes =>
      $$PlaylistEpisodesTableTableManager(_db, _db.playlistEpisodes);
  $$EpisodeFingerprintsTableTableManager get episodeFingerprints =>
      $$EpisodeFingerprintsTableTableManager(_db, _db.episodeFingerprints);
  $$SegmentTemplatesTableTableManager get segmentTemplates =>
      $$SegmentTemplatesTableTableManager(_db, _db.segmentTemplates);
  $$SkipSegmentsTableTableManager get skipSegments =>
      $$SkipSegmentsTableTableManager(_db, _db.skipSegments);
  $$EpisodeLogMelsTableTableManager get episodeLogMels =>
      $$EpisodeLogMelsTableTableManager(_db, _db.episodeLogMels);
  $$LearnedNetworkStingsTableTableManager get learnedNetworkStings =>
      $$LearnedNetworkStingsTableTableManager(_db, _db.learnedNetworkStings);
}
