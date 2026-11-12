import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';

Future<int> _userVersion(AppDatabase database) async {
  final row = await database.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

void main() {
  // Certaines versions ont déclaré les colonnes avant de monter schemaVersion.
  // Le fichier a déjà title_fold et auto_download_limit, avec un user_version
  // plus ancien. L’ouverture ne doit pas relancer l’ALTER.
  for (final staleVersion in [17, 18]) {
    test(
      'upgrades a v$staleVersion file that already has the columns',
      () async {
        final dir = await Directory.systemTemp.createTemp('podavio-migration');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/podavio.sqlite');

        final created = AppDatabase(NativeDatabase(file));
        await created.customSelect('SELECT 1').get();
        await created.customStatement('PRAGMA user_version = $staleVersion');
        await created.close();

        final reopened = AppDatabase(NativeDatabase(file));
        addTearDown(reopened.close);
        await reopened.customSelect('SELECT title_fold FROM podcasts').get();
        await reopened
            .customSelect('SELECT auto_download_limit FROM podcasts')
            .get();
        expect(await _userVersion(reopened), reopened.schemaVersion);
      },
    );
  }
}
