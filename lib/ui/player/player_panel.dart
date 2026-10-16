import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PlayerPanel { cover, playlist }

class PlayerPanelNotifier extends Notifier<PlayerPanel> {
  @override
  PlayerPanel build() => PlayerPanel.cover;

  void toggle() {
    state = state == PlayerPanel.cover
        ? PlayerPanel.playlist
        : PlayerPanel.cover;
  }

  void close() => state = PlayerPanel.cover;
}

/// Ferme la playlist du grand lecteur. Renvoie vrai si elle était ouverte.
bool closePlayerPlaylistIfOpen(WidgetRef ref) {
  if (ref.read(playerPanelProvider) != PlayerPanel.playlist) return false;
  ref.read(playerPanelProvider.notifier).close();
  return true;
}

final playerPanelProvider = NotifierProvider<PlayerPanelNotifier, PlayerPanel>(
  PlayerPanelNotifier.new,
);

/// Zone de drag pour réduire le lecteur (swipe bas depuis le header).
class PlayerCollapseHeader extends StatelessWidget {
  const PlayerCollapseHeader({
    super.key,
    required this.child,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
  });

  final Widget child;
  final GestureDragStartCallback? onVerticalDragStart;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;
  final GestureDragCancelCallback? onVerticalDragCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: onVerticalDragStart,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      onVerticalDragCancel: onVerticalDragCancel,
      child: child,
    );
  }
}
