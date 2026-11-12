import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Efficacité de la suppression des silences.
enum SilenceStrength {
  low('low', 'Faible'),
  medium('medium', 'Moyen'),
  high('high', 'Élevée'),
  veryHigh('veryHigh', 'Très élevée'),
  extreme('extreme', 'Extrême');

  const SilenceStrength(this.id, this.label);

  final String id;
  final String label;

  static SilenceStrength byId(String? id) {
    for (final strength in values) {
      if (strength.id == id) return strength;
    }
    return high;
  }
}

/// Réglages de la feuille Effets audios.
class AudioEffects {
  const AudioEffects({
    this.amplify = false,
    this.stabilizeVolume = false,
    this.mono = false,
    this.skipSilence = false,
    this.silenceStrength = SilenceStrength.high,
  });

  final bool amplify;
  final bool stabilizeVolume;
  final bool mono;
  final bool skipSilence;
  final SilenceStrength silenceStrength;

  AudioEffects copyWith({
    bool? amplify,
    bool? stabilizeVolume,
    bool? mono,
    bool? skipSilence,
    SilenceStrength? silenceStrength,
  }) {
    return AudioEffects(
      amplify: amplify ?? this.amplify,
      stabilizeVolume: stabilizeVolume ?? this.stabilizeVolume,
      mono: mono ?? this.mono,
      skipSilence: skipSilence ?? this.skipSilence,
      silenceStrength: silenceStrength ?? this.silenceStrength,
    );
  }
}

class AudioEffectsNotifier extends Notifier<AudioEffects> {
  static const _amplifyKey = 'audioEffectAmplify';
  static const _stabilizeKey = 'audioEffectStabilize';
  static const _monoKey = 'audioEffectMono';
  static const _silenceKey = 'audioEffectSkipSilence';
  static const _strengthKey = 'audioEffectSilenceStrength';

  @override
  AudioEffects build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return AudioEffects(
      amplify: preferences.getBool(_amplifyKey) ?? false,
      stabilizeVolume: preferences.getBool(_stabilizeKey) ?? false,
      mono: preferences.getBool(_monoKey) ?? false,
      skipSilence: preferences.getBool(_silenceKey) ?? false,
      silenceStrength: SilenceStrength.byId(
        preferences.getString(_strengthKey),
      ),
    );
  }

  Future<void> setAmplify(bool enabled) => _save(
    state.copyWith(amplify: enabled),
    () {
      return ref.read(sharedPreferencesProvider).setBool(_amplifyKey, enabled);
    },
  );

  Future<void> setStabilizeVolume(bool enabled) =>
      _save(state.copyWith(stabilizeVolume: enabled), () {
        return ref
            .read(sharedPreferencesProvider)
            .setBool(_stabilizeKey, enabled);
      });

  Future<void> setMono(bool enabled) =>
      _save(state.copyWith(mono: enabled), () {
        return ref.read(sharedPreferencesProvider).setBool(_monoKey, enabled);
      });

  Future<void> setSkipSilence(bool enabled) => _save(
    state.copyWith(skipSilence: enabled),
    () {
      return ref.read(sharedPreferencesProvider).setBool(_silenceKey, enabled);
    },
  );

  Future<void> setSilenceStrength(SilenceStrength strength) =>
      _save(state.copyWith(silenceStrength: strength), () {
        return ref
            .read(sharedPreferencesProvider)
            .setString(_strengthKey, strength.id);
      });

  Future<void> _save(AudioEffects next, Future<bool> Function() write) async {
    state = next;
    await write();
  }
}

final audioEffectsProvider =
    NotifierProvider<AudioEffectsNotifier, AudioEffects>(
      AudioEffectsNotifier.new,
    );
