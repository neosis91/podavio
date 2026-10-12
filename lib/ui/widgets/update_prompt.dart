import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_release.dart';

/// Boîte affichée une fois par lancement quand podavio.com a une version plus récente.
class UpdatePrompt extends ConsumerStatefulWidget {
  const UpdatePrompt({super.key});

  @override
  ConsumerState<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends ConsumerState<UpdatePrompt> {
  var _scheduled = false;

  @override
  Widget build(BuildContext context) {
    final release = ref.watch(appUpdateProvider).asData?.value;
    if (release != null && !_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _open(release);
      });
    }
    return const SizedBox.shrink();
  }

  Future<void> _open(AppRelease release) async {
    final download = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(release: release),
    );
    if (download != true || !mounted) return;
    final uri = Uri.parse(downloadPageUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.release});

  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    final date = _releaseDate(release.date);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Mise à jour disponible'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('La version ${release.version} est disponible.'),
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text('Publication : $date'),
                ],
                if (release.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final note in release.notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $note'),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Télécharger'),
          ),
        ],
      ),
    );
  }
}

String? _releaseDate(DateTime? date) {
  if (date == null) return null;
  final day = DateTime(date.year, date.month, date.day);
  return DateFormat.yMMMd('fr').format(day);
}
