import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../router.dart';
import '../widgets/messages.dart';

Future<void> subscribeToFeed(
  BuildContext context,
  WidgetRef ref,
  String url, {
  bool openPodcast = true,
  String busyMessage = 'Ajout de l’abonnement…',
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogOpen = true;
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
            Expanded(child: Text(busyMessage)),
          ],
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  void closeDialog() {
    if (!dialogOpen) return;
    dialogOpen = false;
    navigator.pop();
  }

  try {
    final result = await ref.read(feedServiceProvider).subscribe(url);
    closeDialog();
    if (!context.mounted) return;
    if (result.created) {
      showMessage(context, 'Abonnement ajouté');
    }
    if (openPodcast) {
      context.push(AppRoutes.podcast(result.podcastId));
    }
  } catch (error) {
    closeDialog();
    if (!context.mounted) return;
    showMessage(context, errorText(error));
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

  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Ouverture du podcast…')),
          ],
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  void closeDialog() {
    if (!dialogOpen) return;
    dialogOpen = false;
    navigator.pop();
  }

  try {
    final id = await ref.read(feedServiceProvider).preview(trimmed);
    closeDialog();
    if (!context.mounted) return;
    context.push(AppRoutes.podcast(id));
  } catch (error) {
    closeDialog();
    if (!context.mounted) return;
    showMessage(context, errorText(error));
  }
}

