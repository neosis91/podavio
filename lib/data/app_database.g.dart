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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    feedUrl,
    title,
    author,
    description,
    imageUrl,
    link,
    subscribedAt,
    refreshedAt,
    preferred,
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
  final String author;
  final String description;
  final String? imageUrl;
  final String? link;
  final DateTime subscribedAt;
  final DateTime? refreshedAt;
  final bool preferred;
  const Podcast({
    required this.id,
    required this.feedUrl,
    required this.title,
    required this.author,
    required this.description,
    this.imageUrl,
    this.link,
    required this.subscribedAt,
    this.refreshedAt,
    required this.preferred,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['feed_url'] = Variable<String>(feedUrl);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || link != null) {
      map['link'] = Variable<String>(link);
    }
    map['subscribed_at'] = Variable<DateTime>(subscribedAt);
    if (!nullToAbsent || refreshedAt != null) {
      map['refreshed_at'] = Variable<DateTime>(refreshedAt);
    }
    map['preferred'] = Variable<bool>(preferred);
    return map;
  }

  PodcastsCompanion toCompanion(bool nullToAbsent) {
    return PodcastsCompanion(
      id: Value(id),
      feedUrl: Value(feedUrl),
      title: Value(title),
      author: Value(author),
      description: Value(description),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      link: link == null && nullToAbsent ? const Value.absent() : Value(link),
      subscribedAt: Value(subscribedAt),
      refreshedAt: refreshedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(refreshedAt),
      preferred: Value(preferred),
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
      author: serializer.fromJson<String>(json['author']),
      description: serializer.fromJson<String>(json['description']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      link: serializer.fromJson<String?>(json['link']),
      subscribedAt: serializer.fromJson<DateTime>(json['subscribedAt']),
      refreshedAt: serializer.fromJson<DateTime?>(json['refreshedAt']),
      preferred: serializer.fromJson<bool>(json['preferred']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'feedUrl': serializer.toJson<String>(feedUrl),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'description': serializer.toJson<String>(description),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'link': serializer.toJson<String?>(link),
      'subscribedAt': serializer.toJson<DateTime>(subscribedAt),
      'refreshedAt': serializer.toJson<DateTime?>(refreshedAt),
      'preferred': serializer.toJson<bool>(preferred),
    };
  }

  Podcast copyWith({
    int? id,
    String? feedUrl,
    String? title,
    String? author,
    String? description,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> link = const Value.absent(),
    DateTime? subscribedAt,
    Value<DateTime?> refreshedAt = const Value.absent(),
    bool? preferred,
  }) => Podcast(
    id: id ?? this.id,
    feedUrl: feedUrl ?? this.feedUrl,
    title: title ?? this.title,
    author: author ?? this.author,
    description: description ?? this.description,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    link: link.present ? link.value : this.link,
    subscribedAt: subscribedAt ?? this.subscribedAt,
    refreshedAt: refreshedAt.present ? refreshedAt.value : this.refreshedAt,
    preferred: preferred ?? this.preferred,
  );
  Podcast copyWithCompanion(PodcastsCompanion data) {
    return Podcast(
      id: data.id.present ? data.id.value : this.id,
      feedUrl: data.feedUrl.present ? data.feedUrl.value : this.feedUrl,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      description: data.description.present
          ? data.description.value
          : this.description,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      link: data.link.present ? data.link.value : this.link,
      subscribedAt: data.subscribedAt.present
          ? data.subscribedAt.value
          : this.subscribedAt,
      refreshedAt: data.refreshedAt.present
          ? data.refreshedAt.value
          : this.refreshedAt,
      preferred: data.preferred.present ? data.preferred.value : this.preferred,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Podcast(')
          ..write('id: $id, ')
          ..write('feedUrl: $feedUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('link: $link, ')
          ..write('subscribedAt: $subscribedAt, ')
          ..write('refreshedAt: $refreshedAt, ')
          ..write('preferred: $preferred')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    feedUrl,
    title,
    author,
    description,
    imageUrl,
    link,
    subscribedAt,
    refreshedAt,
    preferred,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Podcast &&
          other.id == this.id &&
          other.feedUrl == this.feedUrl &&
          other.title == this.title &&
          other.author == this.author &&
          other.description == this.description &&
          other.imageUrl == this.imageUrl &&
          other.link == this.link &&
          other.subscribedAt == this.subscribedAt &&
          other.refreshedAt == this.refreshedAt &&
          other.preferred == this.preferred);
}

class PodcastsCompanion extends UpdateCompanion<Podcast> {
  final Value<int> id;
  final Value<String> feedUrl;
  final Value<String> title;
  final Value<String> author;
  final Value<String> description;
  final Value<String?> imageUrl;
  final Value<String?> link;
  final Value<DateTime> subscribedAt;
  final Value<DateTime?> refreshedAt;
  final Value<bool> preferred;
  const PodcastsCompanion({
    this.id = const Value.absent(),
    this.feedUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.link = const Value.absent(),
    this.subscribedAt = const Value.absent(),
    this.refreshedAt = const Value.absent(),
    this.preferred = const Value.absent(),
  });
  PodcastsCompanion.insert({
    this.id = const Value.absent(),
    required String feedUrl,
    required String title,
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.link = const Value.absent(),
    required DateTime subscribedAt,
    this.refreshedAt = const Value.absent(),
    this.preferred = const Value.absent(),
  }) : feedUrl = Value(feedUrl),
       title = Value(title),
       subscribedAt = Value(subscribedAt);
  static Insertable<Podcast> custom({
    Expression<int>? id,
    Expression<String>? feedUrl,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? description,
    Expression<String>? imageUrl,
    Expression<String>? link,
    Expression<DateTime>? subscribedAt,
    Expression<DateTime>? refreshedAt,
    Expression<bool>? preferred,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (feedUrl != null) 'feed_url': feedUrl,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      if (link != null) 'link': link,
      if (subscribedAt != null) 'subscribed_at': subscribedAt,
      if (refreshedAt != null) 'refreshed_at': refreshedAt,
      if (preferred != null) 'preferred': preferred,
    });
  }

  PodcastsCompanion copyWith({
    Value<int>? id,
    Value<String>? feedUrl,
    Value<String>? title,
    Value<String>? author,
    Value<String>? description,
    Value<String?>? imageUrl,
    Value<String?>? link,
    Value<DateTime>? subscribedAt,
    Value<DateTime?>? refreshedAt,
    Value<bool>? preferred,
  }) {
    return PodcastsCompanion(
      id: id ?? this.id,
      feedUrl: feedUrl ?? this.feedUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      link: link ?? this.link,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      refreshedAt: refreshedAt ?? this.refreshedAt,
      preferred: preferred ?? this.preferred,
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
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PodcastsCompanion(')
          ..write('id: $id, ')
          ..write('feedUrl: $feedUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('link: $link, ')
          ..write('subscribedAt: $subscribedAt, ')
          ..write('refreshedAt: $refreshedAt, ')
          ..write('preferred: $preferred')
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    podcastId,
    guid,
    title,
    description,
    audioUrl,
    mimeType,
    durationSeconds,
    publishedAt,
    imageUrl,
    positionMs,
    played,
    favorite,
    downloadPath,
    queueIndex,
    lastPlayedAt,
    downloadedAt,
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
  final String description;
  final String audioUrl;
  final String? mimeType;
  final int? durationSeconds;
  final DateTime? publishedAt;
  final String? imageUrl;
  final int positionMs;
  final bool played;
  final bool favorite;
  final String? downloadPath;
  final int? queueIndex;
  final DateTime? lastPlayedAt;
  final DateTime? downloadedAt;
  const Episode({
    required this.id,
    required this.podcastId,
    required this.guid,
    required this.title,
    required this.description,
    required this.audioUrl,
    this.mimeType,
    this.durationSeconds,
    this.publishedAt,
    this.imageUrl,
    required this.positionMs,
    required this.played,
    required this.favorite,
    this.downloadPath,
    this.queueIndex,
    this.lastPlayedAt,
    this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['podcast_id'] = Variable<int>(podcastId);
    map['guid'] = Variable<String>(guid);
    map['title'] = Variable<String>(title);
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
    map['position_ms'] = Variable<int>(positionMs);
    map['played'] = Variable<bool>(played);
    map['favorite'] = Variable<bool>(favorite);
    if (!nullToAbsent || downloadPath != null) {
      map['download_path'] = Variable<String>(downloadPath);
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
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      id: Value(id),
      podcastId: Value(podcastId),
      guid: Value(guid),
      title: Value(title),
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
      positionMs: Value(positionMs),
      played: Value(played),
      favorite: Value(favorite),
      downloadPath: downloadPath == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadPath),
      queueIndex: queueIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(queueIndex),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
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
      description: serializer.fromJson<String>(json['description']),
      audioUrl: serializer.fromJson<String>(json['audioUrl']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      played: serializer.fromJson<bool>(json['played']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      downloadPath: serializer.fromJson<String?>(json['downloadPath']),
      queueIndex: serializer.fromJson<int?>(json['queueIndex']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
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
      'description': serializer.toJson<String>(description),
      'audioUrl': serializer.toJson<String>(audioUrl),
      'mimeType': serializer.toJson<String?>(mimeType),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'positionMs': serializer.toJson<int>(positionMs),
      'played': serializer.toJson<bool>(played),
      'favorite': serializer.toJson<bool>(favorite),
      'downloadPath': serializer.toJson<String?>(downloadPath),
      'queueIndex': serializer.toJson<int?>(queueIndex),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
    };
  }

  Episode copyWith({
    int? id,
    int? podcastId,
    String? guid,
    String? title,
    String? description,
    String? audioUrl,
    Value<String?> mimeType = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<DateTime?> publishedAt = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    int? positionMs,
    bool? played,
    bool? favorite,
    Value<String?> downloadPath = const Value.absent(),
    Value<int?> queueIndex = const Value.absent(),
    Value<DateTime?> lastPlayedAt = const Value.absent(),
    Value<DateTime?> downloadedAt = const Value.absent(),
  }) => Episode(
    id: id ?? this.id,
    podcastId: podcastId ?? this.podcastId,
    guid: guid ?? this.guid,
    title: title ?? this.title,
    description: description ?? this.description,
    audioUrl: audioUrl ?? this.audioUrl,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    positionMs: positionMs ?? this.positionMs,
    played: played ?? this.played,
    favorite: favorite ?? this.favorite,
    downloadPath: downloadPath.present ? downloadPath.value : this.downloadPath,
    queueIndex: queueIndex.present ? queueIndex.value : this.queueIndex,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
  );
  Episode copyWithCompanion(EpisodesCompanion data) {
    return Episode(
      id: data.id.present ? data.id.value : this.id,
      podcastId: data.podcastId.present ? data.podcastId.value : this.podcastId,
      guid: data.guid.present ? data.guid.value : this.guid,
      title: data.title.present ? data.title.value : this.title,
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
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      played: data.played.present ? data.played.value : this.played,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      downloadPath: data.downloadPath.present
          ? data.downloadPath.value
          : this.downloadPath,
      queueIndex: data.queueIndex.present
          ? data.queueIndex.value
          : this.queueIndex,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Episode(')
          ..write('id: $id, ')
          ..write('podcastId: $podcastId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('mimeType: $mimeType, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('positionMs: $positionMs, ')
          ..write('played: $played, ')
          ..write('favorite: $favorite, ')
          ..write('downloadPath: $downloadPath, ')
          ..write('queueIndex: $queueIndex, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    podcastId,
    guid,
    title,
    description,
    audioUrl,
    mimeType,
    durationSeconds,
    publishedAt,
    imageUrl,
    positionMs,
    played,
    favorite,
    downloadPath,
    queueIndex,
    lastPlayedAt,
    downloadedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Episode &&
          other.id == this.id &&
          other.podcastId == this.podcastId &&
          other.guid == this.guid &&
          other.title == this.title &&
          other.description == this.description &&
          other.audioUrl == this.audioUrl &&
          other.mimeType == this.mimeType &&
          other.durationSeconds == this.durationSeconds &&
          other.publishedAt == this.publishedAt &&
          other.imageUrl == this.imageUrl &&
          other.positionMs == this.positionMs &&
          other.played == this.played &&
          other.favorite == this.favorite &&
          other.downloadPath == this.downloadPath &&
          other.queueIndex == this.queueIndex &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.downloadedAt == this.downloadedAt);
}

class EpisodesCompanion extends UpdateCompanion<Episode> {
  final Value<int> id;
  final Value<int> podcastId;
  final Value<String> guid;
  final Value<String> title;
  final Value<String> description;
  final Value<String> audioUrl;
  final Value<String?> mimeType;
  final Value<int?> durationSeconds;
  final Value<DateTime?> publishedAt;
  final Value<String?> imageUrl;
  final Value<int> positionMs;
  final Value<bool> played;
  final Value<bool> favorite;
  final Value<String?> downloadPath;
  final Value<int?> queueIndex;
  final Value<DateTime?> lastPlayedAt;
  final Value<DateTime?> downloadedAt;
  const EpisodesCompanion({
    this.id = const Value.absent(),
    this.podcastId = const Value.absent(),
    this.guid = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.played = const Value.absent(),
    this.favorite = const Value.absent(),
    this.downloadPath = const Value.absent(),
    this.queueIndex = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.downloadedAt = const Value.absent(),
  });
  EpisodesCompanion.insert({
    this.id = const Value.absent(),
    required int podcastId,
    required String guid,
    required String title,
    this.description = const Value.absent(),
    required String audioUrl,
    this.mimeType = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.played = const Value.absent(),
    this.favorite = const Value.absent(),
    this.downloadPath = const Value.absent(),
    this.queueIndex = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.downloadedAt = const Value.absent(),
  }) : podcastId = Value(podcastId),
       guid = Value(guid),
       title = Value(title),
       audioUrl = Value(audioUrl);
  static Insertable<Episode> custom({
    Expression<int>? id,
    Expression<int>? podcastId,
    Expression<String>? guid,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? audioUrl,
    Expression<String>? mimeType,
    Expression<int>? durationSeconds,
    Expression<DateTime>? publishedAt,
    Expression<String>? imageUrl,
    Expression<int>? positionMs,
    Expression<bool>? played,
    Expression<bool>? favorite,
    Expression<String>? downloadPath,
    Expression<int>? queueIndex,
    Expression<DateTime>? lastPlayedAt,
    Expression<DateTime>? downloadedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (podcastId != null) 'podcast_id': podcastId,
      if (guid != null) 'guid': guid,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (mimeType != null) 'mime_type': mimeType,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (publishedAt != null) 'published_at': publishedAt,
      if (imageUrl != null) 'image_url': imageUrl,
      if (positionMs != null) 'position_ms': positionMs,
      if (played != null) 'played': played,
      if (favorite != null) 'favorite': favorite,
      if (downloadPath != null) 'download_path': downloadPath,
      if (queueIndex != null) 'queue_index': queueIndex,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
    });
  }

  EpisodesCompanion copyWith({
    Value<int>? id,
    Value<int>? podcastId,
    Value<String>? guid,
    Value<String>? title,
    Value<String>? description,
    Value<String>? audioUrl,
    Value<String?>? mimeType,
    Value<int?>? durationSeconds,
    Value<DateTime?>? publishedAt,
    Value<String?>? imageUrl,
    Value<int>? positionMs,
    Value<bool>? played,
    Value<bool>? favorite,
    Value<String?>? downloadPath,
    Value<int?>? queueIndex,
    Value<DateTime?>? lastPlayedAt,
    Value<DateTime?>? downloadedAt,
  }) {
    return EpisodesCompanion(
      id: id ?? this.id,
      podcastId: podcastId ?? this.podcastId,
      guid: guid ?? this.guid,
      title: title ?? this.title,
      description: description ?? this.description,
      audioUrl: audioUrl ?? this.audioUrl,
      mimeType: mimeType ?? this.mimeType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      publishedAt: publishedAt ?? this.publishedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      positionMs: positionMs ?? this.positionMs,
      played: played ?? this.played,
      favorite: favorite ?? this.favorite,
      downloadPath: downloadPath ?? this.downloadPath,
      queueIndex: queueIndex ?? this.queueIndex,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      downloadedAt: downloadedAt ?? this.downloadedAt,
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
    if (queueIndex.present) {
      map['queue_index'] = Variable<int>(queueIndex.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
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
          ..write('description: $description, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('mimeType: $mimeType, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('positionMs: $positionMs, ')
          ..write('played: $played, ')
          ..write('favorite: $favorite, ')
          ..write('downloadPath: $downloadPath, ')
          ..write('queueIndex: $queueIndex, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PodcastsTable podcasts = $PodcastsTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [podcasts, episodes];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'podcasts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('episodes', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PodcastsTableCreateCompanionBuilder = PodcastsCompanion Function({
  Value<int> id,
  required String feedUrl,
  required String title,
  Value<String> author,
  Value<String> description,
  Value<String?> imageUrl,
  Value<String?> link,
  required DateTime subscribedAt,
  Value<DateTime?> refreshedAt,
  Value<bool> preferred,
});
typedef $$PodcastsTableUpdateCompanionBuilder = PodcastsCompanion Function({
  Value<int> id,
  Value<String> feedUrl,
  Value<String> title,
  Value<String> author,
  Value<String> description,
  Value<String?> imageUrl,
  Value<String?> link,
  Value<DateTime> subscribedAt,
  Value<DateTime?> refreshedAt,
  Value<bool> preferred,
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

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

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
          PrefetchHooks Function({bool episodesRefs})
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
                Value<String> author = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<DateTime> subscribedAt = const Value.absent(),
                Value<DateTime?> refreshedAt = const Value.absent(),
                Value<bool> preferred = const Value.absent(),
              }) => PodcastsCompanion(
                id: id,
                feedUrl: feedUrl,
                title: title,
                author: author,
                description: description,
                imageUrl: imageUrl,
                link: link,
                subscribedAt: subscribedAt,
                refreshedAt: refreshedAt,
                preferred: preferred,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String feedUrl,
                required String title,
                Value<String> author = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> link = const Value.absent(),
                required DateTime subscribedAt,
                Value<DateTime?> refreshedAt = const Value.absent(),
                Value<bool> preferred = const Value.absent(),
              }) => PodcastsCompanion.insert(
                id: id,
                feedUrl: feedUrl,
                title: title,
                author: author,
                description: description,
                imageUrl: imageUrl,
                link: link,
                subscribedAt: subscribedAt,
                refreshedAt: refreshedAt,
                preferred: preferred,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PodcastsTable, Podcast>(table),
                  $$PodcastsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (episodesRefs) db.episodes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (episodesRefs)
                    await $_getPrefetchedData<Podcast, $PodcastsTable, Episode>(
                      currentTable: table,
                      referencedTable: $$PodcastsTableReferences
                          ._episodesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PodcastsTableReferences(db, table, p0).episodesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.podcastId == item.id),
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
      PrefetchHooks Function({bool episodesRefs})
    >;
typedef $$EpisodesTableCreateCompanionBuilder = EpisodesCompanion Function({
  Value<int> id,
  required int podcastId,
  required String guid,
  required String title,
  Value<String> description,
  required String audioUrl,
  Value<String?> mimeType,
  Value<int?> durationSeconds,
  Value<DateTime?> publishedAt,
  Value<String?> imageUrl,
  Value<int> positionMs,
  Value<bool> played,
  Value<bool> favorite,
  Value<String?> downloadPath,
  Value<int?> queueIndex,
  Value<DateTime?> lastPlayedAt,
  Value<DateTime?> downloadedAt,
});
typedef $$EpisodesTableUpdateCompanionBuilder = EpisodesCompanion Function({
  Value<int> id,
  Value<int> podcastId,
  Value<String> guid,
  Value<String> title,
  Value<String> description,
  Value<String> audioUrl,
  Value<String?> mimeType,
  Value<int?> durationSeconds,
  Value<DateTime?> publishedAt,
  Value<String?> imageUrl,
  Value<int> positionMs,
  Value<bool> played,
  Value<bool> favorite,
  Value<String?> downloadPath,
  Value<int?> queueIndex,
  Value<DateTime?> lastPlayedAt,
  Value<DateTime?> downloadedAt,
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
          PrefetchHooks Function({bool podcastId})
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
                Value<String> description = const Value.absent(),
                Value<String> audioUrl = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<bool> played = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<String?> downloadPath = const Value.absent(),
                Value<int?> queueIndex = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
              }) => EpisodesCompanion(
                id: id,
                podcastId: podcastId,
                guid: guid,
                title: title,
                description: description,
                audioUrl: audioUrl,
                mimeType: mimeType,
                durationSeconds: durationSeconds,
                publishedAt: publishedAt,
                imageUrl: imageUrl,
                positionMs: positionMs,
                played: played,
                favorite: favorite,
                downloadPath: downloadPath,
                queueIndex: queueIndex,
                lastPlayedAt: lastPlayedAt,
                downloadedAt: downloadedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int podcastId,
                required String guid,
                required String title,
                Value<String> description = const Value.absent(),
                required String audioUrl,
                Value<String?> mimeType = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<bool> played = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<String?> downloadPath = const Value.absent(),
                Value<int?> queueIndex = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
              }) => EpisodesCompanion.insert(
                id: id,
                podcastId: podcastId,
                guid: guid,
                title: title,
                description: description,
                audioUrl: audioUrl,
                mimeType: mimeType,
                durationSeconds: durationSeconds,
                publishedAt: publishedAt,
                imageUrl: imageUrl,
                positionMs: positionMs,
                played: played,
                favorite: favorite,
                downloadPath: downloadPath,
                queueIndex: queueIndex,
                lastPlayedAt: lastPlayedAt,
                downloadedAt: downloadedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpisodesTable, Episode>(table),
                  $$EpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({podcastId = false}) {
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
                return [];
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
      PrefetchHooks Function({bool podcastId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PodcastsTableTableManager get podcasts =>
      $$PodcastsTableTableManager(_db, _db.podcasts);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
}
