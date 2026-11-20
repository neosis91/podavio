import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/download_service.dart';
import 'package:podavio/data/models.dart';

void main() {
  test('a failed download keeps its bytes and resumes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final root = await Directory.systemTemp.createTemp('podavio-partial');
    addTearDown(() => root.delete(recursive: true));
    final downloads = Directory('${root.path}/downloads')..createSync();
    final partials = Directory('${root.path}/partials')..createSync();
    final bytes = List<int>.generate(8, (index) => index + 1);
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) {
      final buffer = StringBuffer();
      socket.listen((data) {
        buffer.write(utf8.decode(data));
        if (!buffer.toString().contains('\r\n\r\n')) return;
        final resume = buffer.toString().toLowerCase().contains(
          'range: bytes=4-',
        );
        if (!resume) {
          socket.add(
            utf8.encode(
              'HTTP/1.1 200 OK\r\nContent-Length: ${bytes.length}\r\n'
              'Connection: close\r\n\r\n',
            ),
          );
          socket.add(bytes.sublist(0, 4));
        } else {
          socket.add(
            utf8.encode(
              'HTTP/1.1 206 Partial Content\r\nContent-Length: 4\r\n'
              'Content-Range: bytes 4-7/${bytes.length}\r\n'
              'Connection: close\r\n\r\n',
            ),
          );
          socket.add(bytes.sublist(4));
        }
        socket.close();
      });
    });

    final podcastId = (await database.saveFeed(
      FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Premier',
            description: '',
            audioUrl: 'http://127.0.0.1:${server.port}/episode.mp3',
          ),
        ],
      ),
    )).podcastId;
    final episode = (await database.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode;
    final service = DownloadService(database, partials: partials);

    await expectLater(
      service.download(episode, directory: downloads.path),
      throwsA(isA<Exception>()),
    );
    final kept = File('${partials.path}/download-partials/${episode.id}.part');
    expect(await kept.exists(), isTrue);
    expect(await kept.readAsBytes(), bytes.sublist(0, 4));

    final progress = <double>[];
    await service.download(
      episode,
      directory: downloads.path,
      onProgress: progress.add,
    );

    final saved = File('${downloads.path}/[Essai] Premier.mp3');
    expect(await saved.readAsBytes(), bytes);
    expect(await kept.exists(), isFalse);
    expect(progress.first, 0.5);
    expect(progress.last, 1);
  });

  test('an unusable range keeps the partial when the retry fails', () async {
    final setup = await _partialSetup();
    addTearDown(setup.close);
    final kept = setup.partial;
    await kept.parent.create(recursive: true);
    await kept.writeAsBytes([1, 2, 3, 4]);
    await File('${kept.path}.url')
        .writeAsString('${setup.episode.audioUrl}\n\n');
    setup.server.listen((socket) {
      final buffer = StringBuffer();
      socket.listen((data) {
        buffer.write(utf8.decode(data));
        if (!buffer.toString().contains('\r\n\r\n')) return;
        final ranged = buffer.toString().toLowerCase().contains('range:');
        if (ranged) {
          socket.add(
            utf8.encode(
              'HTTP/1.1 416 Range Not Satisfiable\r\n'
              'Content-Range: bytes */8\r\nContent-Length: 0\r\n'
              'Connection: close\r\n\r\n',
            ),
          );
        } else {
          socket.add(
            utf8.encode(
              'HTTP/1.1 200 OK\r\nContent-Length: 8\r\nConnection: close\r\n\r\n',
            ),
          );
        }
        socket.close();
      });
    });

    await expectLater(
      setup.service.download(setup.episode, directory: setup.downloads.path),
      throwsA(isA<Exception>()),
    );
    expect(await kept.readAsBytes(), [1, 2, 3, 4]);
  });

  test(
    'a changed file is downloaded again instead of being appended',
    () async {
      final setup = await _partialSetup();
      addTearDown(setup.close);
      final kept = setup.partial;
      await kept.parent.create(recursive: true);
      await kept.writeAsBytes([1, 2, 3, 4]);
      await File('${kept.path}.url')
          .writeAsString('${setup.episode.audioUrl}\n"v1"\n');
      final requests = <String>[];
      setup.server.listen((socket) {
        final buffer = StringBuffer();
        socket.listen((data) {
          buffer.write(utf8.decode(data));
          if (!buffer.toString().contains('\r\n\r\n')) return;
          final text = buffer.toString();
          requests.add(text);
          final lower = text.toLowerCase();
          if (lower.contains('if-range: "v1"')) {
            socket.add(
              utf8.encode(
                'HTTP/1.1 200 OK\r\nContent-Length: 8\r\nETag: "v2"\r\n'
                'Connection: close\r\n\r\n',
              ),
            );
            socket.add(List<int>.filled(8, 9));
          } else {
            socket.add(
              utf8.encode(
                'HTTP/1.1 206 Partial Content\r\nContent-Length: 4\r\n'
                'Content-Range: bytes 4-7/8\r\nETag: "v2"\r\n'
                'Connection: close\r\n\r\n',
              ),
            );
            socket.add(List<int>.filled(4, 9));
          }
          socket.close();
        });
      });

      await setup.service.download(
        setup.episode,
        directory: setup.downloads.path,
      );
      final saved = File('${setup.downloads.path}/[Essai] Premier.mp3');
      expect(await saved.readAsBytes(), List<int>.filled(8, 9));
      expect(requests.single.toLowerCase(), contains('if-range: "v1"'));
    },
  );

  test('a partial longer than the file is not saved as the download', () async {
    final setup = await _partialSetup();
    addTearDown(setup.close);
    final kept = setup.partial;
    await kept.parent.create(recursive: true);
    await kept.writeAsBytes(List<int>.filled(9, 7));
    await File('${kept.path}.url')
        .writeAsString('${setup.episode.audioUrl}\n\n');
    setup.server.listen((socket) {
      final buffer = StringBuffer();
      socket.listen((data) {
        buffer.write(utf8.decode(data));
        if (!buffer.toString().contains('\r\n\r\n')) return;
        final ranged = buffer.toString().toLowerCase().contains('range:');
        if (ranged) {
          socket.add(
            utf8.encode(
              'HTTP/1.1 416 Range Not Satisfiable\r\n'
              'Content-Range: bytes */8\r\nContent-Length: 0\r\n'
              'Connection: close\r\n\r\n',
            ),
          );
        } else {
          socket.add(
            utf8.encode(
              'HTTP/1.1 200 OK\r\nContent-Length: 8\r\nConnection: close\r\n\r\n',
            ),
          );
          socket.add(List<int>.generate(8, (index) => index + 1));
        }
        socket.close();
      });
    });

    await setup.service.download(
      setup.episode,
      directory: setup.downloads.path,
    );
    final saved = File('${setup.downloads.path}/[Essai] Premier.mp3');
    expect(
      await saved.readAsBytes(),
      List<int>.generate(8, (index) => index + 1),
    );
  });

  test('saving a cached episode removes the unfinished partial', () async {
    final setup = await _partialSetup();
    addTearDown(setup.close);
    final cache = File('${setup.root.path}/cache.mp3');
    await cache.writeAsBytes([1, 2, 3]);
    await setup.database.setCachePath(setup.episode.id, cache.path);
    final kept = setup.partial;
    await kept.parent.create(recursive: true);
    await kept.writeAsBytes([9, 9]);

    await setup.service.download(
      setup.episode,
      directory: setup.downloads.path,
    );
    expect(await kept.exists(), isFalse);
    expect(
      await File('${setup.downloads.path}/[Essai] Premier.mp3').readAsBytes(),
      [1, 2, 3],
    );
  });
}

class _PartialSetup {
  _PartialSetup({
    required this.database,
    required this.root,
    required this.downloads,
    required this.server,
    required this.service,
    required this.episode,
    required this.partial,
  });

  final AppDatabase database;
  final Directory root;
  final Directory downloads;
  final ServerSocket server;
  final DownloadService service;
  final Episode episode;
  final File partial;

  Future<void> close() async {
    server.close();
    await database.close();
    if (root.existsSync()) await root.delete(recursive: true);
  }
}

Future<_PartialSetup> _partialSetup() async {
  final database = AppDatabase(NativeDatabase.memory());
  final root = await Directory.systemTemp.createTemp('podavio-partial-case');
  final downloads = Directory('${root.path}/downloads')..createSync();
  final partials = Directory('${root.path}/partials')..createSync();
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final podcastId = (await database.saveFeed(
    FeedDraft(
      feedUrl: 'https://example.com/feed.xml',
      title: 'Essai',
      author: 'Auteur',
      description: '',
      episodes: [
        EpisodeDraft(
          guid: 'ep-1',
          title: 'Premier',
          description: '',
          audioUrl: 'http://127.0.0.1:${server.port}/episode.mp3',
        ),
      ],
    ),
  )).podcastId;
  final episode =
      (await database.watchEpisodes(podcastId: podcastId).first).single.episode;
  return _PartialSetup(
    database: database,
    root: root,
    downloads: downloads,
    server: server,
    service: DownloadService(database, partials: partials),
    episode: episode,
    partial: File('${partials.path}/download-partials/${episode.id}.part'),
  );
}
