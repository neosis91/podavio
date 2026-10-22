import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

typedef ChoiceOption<T> = ({T value, String label});

/// Liste de choix unique. `null` si l’utilisateur ferme la fenêtre.
Future<T?> showChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<ChoiceOption<T>> options,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(context.tr(title)),
        contentPadding: const EdgeInsets.only(bottom: 12),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, option.value),
                  child: Row(
                    children: [
                      Expanded(child: Text(context.tr(option.label))),
                      if (option.value == selected)
                        const Icon(Icons.check, size: 20),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Liste à boutons radio. `null` si l’utilisateur annule.
Future<T?> showRadioChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<ChoiceOption<T>> options,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(context.tr(title)),
        contentPadding: const EdgeInsets.only(top: 8),
        content: SingleChildScrollView(
          child: RadioGroup<T>(
            groupValue: selected,
            onChanged: (value) {
              if (value == null) return;
              Navigator.pop(context, value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Radio<T>(value: option.value),
                    title: Text(context.tr(option.label)),
                    onTap: () => Navigator.pop(context, option.value),
                  ),
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
        ],
      );
    },
  );
}
