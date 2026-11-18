import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../root_navigator.dart';

/// Demande si cette action peut partir en données mobiles.
///
/// La case, décochée, mémorise le Wi-Fi et le réseau mobile pour la suite.
/// Annuler, ou fermer la fenêtre, ne change rien.
Future<({bool accepted, bool allowFuture})> confirmMobileDataAction(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required String rememberLabel,
}) async {
  var allowFuture = false;
  final choice = await showDialog<({bool accepted, bool allowFuture})>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(context.tr('Mobile data')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: allowFuture,
                  onChanged: (value) {
                    setState(() => allowFuture = value ?? false);
                  },
                  title: Text(rememberLabel),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, (
                  accepted: false,
                  allowFuture: false,
                )),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, (
                  accepted: true,
                  allowFuture: allowFuture,
                )),
                child: Text(actionLabel),
              ),
            ],
          );
        },
      );
    },
  );
  return choice ?? (accepted: false, allowFuture: false);
}

/// Même fenêtre, au-dessus de l’écran courant. `null` s’il n’y a pas d’écran.
Future<({bool accepted, bool allowFuture})?> confirmMobileDataFromRoot({
  required String message,
  required String actionLabel,
  required String rememberLabel,
}) {
  final keyContext = rootNavigatorKey.currentContext;
  final focusContext = FocusManager.instance.primaryFocus?.context;
  final context = keyContext != null && keyContext.mounted
      ? keyContext
      : focusContext != null && focusContext.mounted
      ? focusContext
      : null;
  if (context == null) return Future.value(null);
  return confirmMobileDataAction(
    context,
    message: context.tr(message),
    actionLabel: context.tr(actionLabel),
    rememberLabel: context.tr(rememberLabel),
  );
}
