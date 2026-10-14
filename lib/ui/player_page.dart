import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cover_tone.dart';
import '../core/format.dart';
import '../data/app_database.dart';
import '../data/feed_service.dart';
import '../data/providers.dart';
import '../player/playback_source.dart';
import 'player/audio_output_sheet.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'widgets/brand.dart';
import 'widgets/cover.dart';
import 'widgets/playing_cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_tile.dart';
import 'widgets/show_notes.dart';

part 'player/player_scaffold.dart';
part 'player/player_now_playing.dart';
part 'player/player_controls.dart';
part 'player/player_sheets.dart';

EpisodeChapter? currentChapterFor(
  List<EpisodeChapter> chapters,
  Duration position,
) {
  if (chapters.isEmpty) return null;
  final ms = position.inMilliseconds;
  EpisodeChapter? current;
  for (final chapter in chapters) {
    if (chapter.startMs <= ms) {
      current = chapter;
    } else {
      break;
    }
  }
  return current;
}
