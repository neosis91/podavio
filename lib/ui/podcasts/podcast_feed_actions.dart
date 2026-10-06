import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/feed_service.dart';
import '../../data/providers.dart';
import '../router.dart';
import '../widgets/messages.dart' show showMessage;

/// Demande un identifiant HTTP Basic. `null` si l’utilisateur annule.
Future<({String username, String password})?> askFeedCredentials(
  BuildContext context, {
  String? username,
  String? password,
}) {
  final userController = TextEditingController(text: username ?? '');
  final passController = TextEditingController(text: password ?? '');
  return showDialog<({String username, String password})>(
    context: context,
    builder: (context) {
      var errorText = '';
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Authentification requise'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ce flux demande un identifiant et un mot de passe. '
                  'Ils seront enregistrés pour ce podcast.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: userController,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Identifiant',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submitCredentials(
                    context,
                    userController,
                    passController,
                    setState,
                    (message) => errorText = message,
                  ),
                ),
                if (errorText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => _submitCredentials(
                  context,
                  userController,
                  passController,
                  setState,
                  (message) => errorText = message,
                ),
                child: const Text('Continuer'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    userController.dispose();
    passController.dispose();
  });
}

void _submitCredentials(
  BuildContext context,
  TextEditingController username,
  TextEditingController password,
  void Function(void Function()) setState,
  void Function(String message) setError,
) {
  if (username.text.trim().isEmpty && password.text.isEmpty) {
    setState(() => setError('Indiquez un identifiant ou un mot de passe.'));
    return;
  }
  Navigator.pop(context, (username: username.text, password: password.text));
}

Future<void> subscribeToFeed(
  BuildContext context,
  WidgetRef ref,
  String url, {
  bool openPodcast = true,
  String busyMessage = 'Ajout de l’abonnement…',
}) async {
  final busy = _BusyDialog(context)..show(busyMessage);

  String? username;
  String? password;
  while (true) {
    try {
      final result = await ref
          .read(feedServiceProvider)
          .subscribe(url, username: username, password: password);
      busy.close();
      if (!context.mounted) return;
      if (result.created) {
        showMessage(context, 'Abonnement ajouté');
      }
      if (openPodcast) {
        context.push(AppRoutes.podcast(result.podcastId));
      }
      return;
    } catch (error) {
      busy.close();
      if (!context.mounted) return;
      if (!isFeedUnauthorized(error)) {
        showMessage(context, describeFeedError(error));
        return;
      }
      final credentials = await askFeedCredentials(
        context,
        username: username,
        password: password,
      );
      if (!context.mounted || credentials == null) return;
      username = credentials.username;
      password = credentials.password;
      busy.show(busyMessage);
    }
  }
}

/// Ouvre la page podcast (épisodes). Charge un aperçu si pas encore en base.
Future<void> openPodcastFromFeedUrl(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;

  final known = ref.read(podcastsProvider).value ?? const [];
  for (final podcast in known) {
    if (podcast.feedUrl == trimmed) {
      context.push(AppRoutes.podcast(podcast.id));
      return;
    }
  }

  // Déjà en aperçu (hors liste d’abonnements) ?
  final existing = await ref.read(databaseProvider).findByFeedUrl(trimmed);
  if (!context.mounted) return;
  if (existing != null) {
    context.push(AppRoutes.podcast(existing.id));
    return;
  }

  const busyMessage = 'Ouverture du podcast…';
  final busy = _BusyDialog(context)..show(busyMessage);

  String? username;
  String? password;
  while (true) {
    try {
      final id = await ref
          .read(feedServiceProvider)
          .preview(trimmed, username: username, password: password);
      busy.close();
      if (!context.mounted) return;
      context.push(AppRoutes.podcast(id));
      return;
    } catch (error) {
      busy.close();
      if (!context.mounted) return;
      if (!isFeedUnauthorized(error)) {
        showMessage(context, describeFeedError(error));
        return;
      }
      final credentials = await askFeedCredentials(
        context,
        username: username,
        password: password,
      );
      if (!context.mounted || credentials == null) return;
      username = credentials.username;
      password = credentials.password;
      busy.show(busyMessage);
    }
  }
}

class _BusyDialog {
  _BusyDialog(this.context);

  final BuildContext context;
  var _ticket = 0;
  var _open = false;

  void show(String message) {
    final ticket = ++_ticket;
    _open = true;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (ticket == _ticket) _open = false;
    });
  }

  void close() {
    if (!_open) return;
    _open = false;
    Navigator.of(context, rootNavigator: true).pop();
  }
}

