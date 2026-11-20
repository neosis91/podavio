import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/cover_service.dart';

void main() {
  test('sync planifiée ignorée après dispose et fermeture', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final service = CoverService(database);
    service.schedulePodcastSync();
    service.dispose();
    await database.close();

    // Le debounce est de 800 ms : la sync annulée ne doit rien lancer.
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    await service.syncMissingPodcastCovers();
  });

  test('sync déjà lancée survit à la fermeture de la base', () async {
    final database = _HoldingDatabase();
    final service = CoverService(database);
    final pending = service.syncMissingPodcastCovers();
    await Future<void>.delayed(Duration.zero);
    expect(database.queries, 1);

    service.dispose();
    database.release(StateError('Database is closed'));
    await pending;
    await database.close();
  });

  test('une erreur de sync hors import reste signalée', () async {
    final database = _HoldingDatabase();
    final service = CoverService(database);
    final pending = service.syncMissingPodcastCovers();
    await Future<void>.delayed(Duration.zero);

    database.release(StateError('lecture impossible'));
    await expectLater(pending, throwsA(isA<StateError>()));
    await database.close();
  });
}

class _HoldingDatabase extends AppDatabase {
  _HoldingDatabase() : super(NativeDatabase.memory());

  final _gate = Completer<void>();
  var queries = 0;
  Object? _error;

  void release(Object error) {
    _error = error;
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<List<Podcast>> podcastsMissingCovers() async {
    queries++;
    await _gate.future;
    throw _error!;
  }
}
