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
}
