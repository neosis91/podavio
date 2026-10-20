import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/providers.dart';
import 'widgets/app_bottom_sheet.dart';

Future<String?> askPlaylistName(
  BuildContext context, {
  String title = 'Nouvelle playlist',
  String confirm = 'Créer',
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _PlaylistNameDialog(title: title, confirm: confirm, initial: initial),
  );
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.title,
    required this.confirm,
    required this.initial,
  });

  final String title;
  final String confirm;
  final String initial;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _name.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.pop(context, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _name.text.trim();
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Nom'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: trimmed.isEmpty ? null : _submit,
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

Future<void> showPlaylistMembershipSheet(
  BuildContext context,
  WidgetRef ref,
  EpisodeEntry entry,
) {
  return showAppModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    builder: (context) => _PlaylistMembershipSheet(episodeId: entry.episode.id),
  );
}

class _PlaylistMembershipSheet extends ConsumerWidget {
  const _PlaylistMembershipSheet({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final playlists = ref.watch(playlistsProvider).asData?.value ?? const [];
    final entry = ref.watch(episodeProvider(episodeId)).asData?.value;
    final customIds =
        ref.watch(customPlaylistIdsProvider(episodeId)).asData?.value ??
        const <int>{};
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    Future<void> toggle(PlaylistSummary playlist) async {
      final database = ref.read(databaseProvider);
      if (playlist.isDefault) {
        if (entry?.episode.queueIndex == null) {
          await database.addToPlaylist(playlist.id, episodeId);
        } else {
          await database.removeFromPlaylist(playlist.id, episodeId);
        }
        return;
      }
      if (customIds.contains(playlist.id)) {
        await database.removeFromPlaylist(playlist.id, episodeId);
      } else {
        await database.addToPlaylist(playlist.id, episodeId);
      }
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const SizedBox(width: 32, height: 4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Playlists',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final playlist in playlists)
                        ListTile(
                          leading: Icon(
                            _contains(playlist, entry, customIds)
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                          ),
                          title: Text(playlist.name),
                          subtitle: playlist.isDefault
                              ? const Text('Par défaut')
                              : null,
                          onTap: () => toggle(playlist),
                        ),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Nouvelle playlist'),
                        onTap: () async {
                          final name = await askPlaylistName(context);
                          if (name == null || !context.mounted) return;
                          final id = await ref
                              .read(databaseProvider)
                              .createPlaylist(name);
                          await ref
                              .read(databaseProvider)
                              .addToPlaylist(id, episodeId);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _contains(
  PlaylistSummary playlist,
  EpisodeEntry? entry,
  Set<int> customIds,
) {
  if (playlist.isDefault) return entry?.episode.queueIndex != null;
  return customIds.contains(playlist.id);
}
