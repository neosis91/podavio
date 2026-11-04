import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Message qui s’affichait en bandeau. Il vit dans la feuille de notifications.
class ActivityMessage {
  const ActivityMessage({required this.id, required this.text});

  final int id;
  final String text;
}

final activityMessagesProvider =
    NotifierProvider<ActivityMessagesNotifier, List<ActivityMessage>>(
      ActivityMessagesNotifier.new,
    );

class ActivityMessagesNotifier extends Notifier<List<ActivityMessage>> {
  var _next = 0;

  @override
  List<ActivityMessage> build() => const [];

  void add(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _next += 1;
    final next = <ActivityMessage>[
      ActivityMessage(id: _next, text: trimmed),
      ...state,
    ];
    state = next.length > 30 ? next.sublist(0, 30) : next;
  }

  void dismiss(int id) {
    state = [
      for (final message in state)
        if (message.id != id) message,
    ];
  }
}
