import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/activity_messages.dart';

/// Envoie un message dans la feuille de notifications.
void showMessage(BuildContext context, String message) {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(activityMessagesProvider.notifier).add(message);
}

String errorText(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  if (text.startsWith('FormatException: ')) return text.substring(17);
  return text;
}
