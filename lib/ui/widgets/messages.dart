import 'package:flutter/material.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String errorText(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  if (text.startsWith('FormatException: ')) return text.substring(17);
  return text;
}
