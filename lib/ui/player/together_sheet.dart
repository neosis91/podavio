import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../player/player_controller.dart';
import '../../together/together_controller.dart';

Future<void> showTogetherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const TogetherSheet(),
      );
    },
  );
}

class TogetherSheet extends ConsumerStatefulWidget {
  const TogetherSheet({super.key});

  @override
  ConsumerState<TogetherSheet> createState() => _TogetherSheetState();
}

class _TogetherSheetState extends ConsumerState<TogetherSheet> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  var _filledName = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final together = ref.watch(togetherProvider);
    final hasEpisode = ref.watch(
      playerProvider.select((state) => state.hasEpisode),
    );
    if (!_filledName) {
      _filledName = true;
      final stored = together.name;
      if (stored.isNotEmpty && stored != 'Guest') _name.text = stored;
    }
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, bottom > 0 ? 8 : 24),
        child: switch (together.role) {
          TogetherRole.idle => _idle(context, together, hasEpisode, theme),
          TogetherRole.host => _live(context, together, theme),
          TogetherRole.guest => _guest(context, together, theme),
        },
      ),
    );
  }

  Widget _idle(
    BuildContext context,
    TogetherUiState together,
    bool hasEpisode,
    ThemeData theme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr('Listen together'), style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          context.tr('On the same Wi-Fi. Podavio does not use a server.'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.tr('Your name'),
            hintText: context.tr('Guest'),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: !hasEpisode || together.busy
              ? null
              : () => ref
                    .read(togetherProvider.notifier)
                    .startHost(_spokenName(context)),
          child: Text(context.tr('Start a session')),
        ),
        if (!hasEpisode)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr('Play an episode to start a session.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(labelText: context.tr('Code')),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: together.busy
              ? null
              : () => ref
                    .read(togetherProvider.notifier)
                    .join(_code.text, _spokenName(context)),
          child: Text(context.tr('Join')),
        ),
        if (together.error != null) ...[
          const SizedBox(height: 12),
          Text(
            context.tr(together.error!),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (together.busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _live(
    BuildContext context,
    TogetherUiState together,
    ThemeData theme,
  ) {
    final count = together.peers.length;
    final people = count == 0
        ? context.tr('Waiting for the others.')
        : count == 1
        ? context.tr('1 person is listening.')
        : context.tr('{count} people are listening.', {'count': '$count'});
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr('Listen together'), style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(
          together.code,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(letterSpacing: 8),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('Share this code with people on the same network.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(people, textAlign: TextAlign.center),
        if (together.peers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              together.peers.join(', '),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        if (together.error != null) ...[
          const SizedBox(height: 12),
          Text(
            context.tr(together.error!),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => ref.read(togetherProvider.notifier).leave(),
          child: Text(context.tr('Leave')),
        ),
      ],
    );
  }

  Widget _guest(
    BuildContext context,
    TogetherUiState together,
    ThemeData theme,
  ) {
    final count = together.people;
    final people = count <= 1
        ? context.tr('1 person is listening.')
        : context.tr('{count} people are listening.', {'count': '$count'});
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          together.room,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        if (count > 0) ...[
          const SizedBox(height: 12),
          Text(people, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => ref.read(togetherProvider.notifier).leave(),
          child: Text(context.tr('Leave')),
        ),
      ],
    );
  }

  String _spokenName(BuildContext context) {
    final typed = _name.text.trim();
    return typed.isEmpty ? context.tr('Guest') : typed;
  }
}
