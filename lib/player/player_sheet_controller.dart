import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demandes d’ouverture / fermeture du lecteur expansible (mini ↔ plein écran).
final playerSheetProvider =
    NotifierProvider<PlayerSheetNotifier, PlayerSheetRequest>(
      PlayerSheetNotifier.new,
    );

class PlayerSheetRequest {
  const PlayerSheetRequest({this.id = 0, this.expand = false});

  final int id;
  final bool expand;
}

class PlayerSheetNotifier extends Notifier<PlayerSheetRequest> {
  @override
  PlayerSheetRequest build() => const PlayerSheetRequest();

  void expand() {
    state = PlayerSheetRequest(id: state.id + 1, expand: true);
  }

  void collapse() {
    state = PlayerSheetRequest(id: state.id + 1, expand: false);
  }
}

void openPlayer(WidgetRef ref) {
  ref.read(playerSheetProvider.notifier).expand();
}
