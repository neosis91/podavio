import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_controller.dart';
import '../../settings/settings_controller.dart';
import '../app_router.dart';

/// Raccourcis clavier du lecteur (desktop / TV).
///
/// Aligné sur les usages média courants (YouTube, lecteurs podcast) et WCAG :
/// - **2.1.1** Keyboard : lecture / pause / sauts opérables au clavier
/// - **2.1.4** Character Key Shortcuts : ignorés dans un champ texte ; Espace
///   laissé aux contrôles focalisés (boutons, cases à cocher)
///
/// Aide : touche **?** ou Réglages → Lecture → Aide du lecteur.
class PlayerKeyboardShortcuts extends ConsumerStatefulWidget {
  const PlayerKeyboardShortcuts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlayerKeyboardShortcuts> createState() =>
      _PlayerKeyboardShortcutsState();
}

class _PlayerKeyboardShortcutsState
    extends ConsumerState<PlayerKeyboardShortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (_isTextInputFocused()) return false;

    final key = event.logicalKey;

    // Aide via le caractère « ? » (AZERTY = Shift+, ; QWERTY = Shift+/).
    if (event is KeyDownEvent && _isHelpShortcut(event)) {
      showPlayerKeyboardHelp();
      return true;
    }

    if (!ref.read(playerProvider).hasEpisode) return false;

    final player = ref.read(playerProvider.notifier);
    final settings = ref.read(settingsProvider);

    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyK ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      if (event is KeyRepeatEvent) return false;
      if (_focusHandlesActivation()) return false;
      player.toggle();
      return true;
    }

    if (key == LogicalKeyboardKey.mediaPlay) {
      if (event is KeyRepeatEvent) return false;
      if (!ref.read(playerProvider).playing) player.toggle();
      return true;
    }

    if (key == LogicalKeyboardKey.mediaPause) {
      if (event is KeyRepeatEvent) return false;
      if (ref.read(playerProvider).playing) player.toggle();
      return true;
    }

    if (key == LogicalKeyboardKey.keyJ ||
        key == LogicalKeyboardKey.mediaRewind) {
      player.skipBy(-settings.skipBackSeconds);
      return true;
    }

    if (key == LogicalKeyboardKey.keyL ||
        key == LogicalKeyboardKey.mediaFastForward) {
      player.skipBy(settings.skipForwardSeconds);
      return true;
    }

    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract ||
        key == LogicalKeyboardKey.bracketLeft) {
      player.nudgeVolume(-0.05);
      return true;
    }

    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.numpadAdd ||
        key == LogicalKeyboardKey.bracketRight) {
      player.nudgeVolume(0.05);
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

bool _isHelpShortcut(KeyDownEvent event) {
  if (event.character == '?') return true;
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.question) return true;
  if (key == LogicalKeyboardKey.slash &&
      HardwareKeyboard.instance.isShiftPressed) {
    return true;
  }
  // AZERTY : ? = Shift + virgule.
  if (key == LogicalKeyboardKey.comma &&
      HardwareKeyboard.instance.isShiftPressed) {
    return true;
  }
  return false;
}

/// Bottom sheet listant raccourcis et gestes (touche ? ou réglages Lecture).
Future<void> showPlayerKeyboardHelp([BuildContext? context]) {
  final navContext = context ?? rootNavigatorKey.currentContext;
  if (navContext == null || !navContext.mounted) {
    return Future<void>.value();
  }
  return showModalBottomSheet<void>(
    context: navContext,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) => const _PlayerKeyboardHelpSheet(),
  );
}

class _PlayerKeyboardHelpSheet extends ConsumerWidget {
  const _PlayerKeyboardHelpSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final back = settings.skipBackSeconds;
    final forward = settings.skipForwardSeconds;
    final shortcuts = <(String keys, String label)>[
      ('Espace ou K', 'Lecture / pause'),
      ('J', 'Reculer de $back s'),
      ('L', 'Avancer de $forward s'),
      ('− ou [', 'Baisser le volume'),
      ('= ou ]', 'Augmenter le volume'),
      ('?', 'Afficher cette aide'),
    ];
    final gestures = <(String keys, String label)>[
      ('Tap sur la cover', 'Lecture / pause'),
      ('Double-tap à gauche', 'Reculer de $back s'),
      ('Double-tap à droite', 'Avancer de $forward s'),
      ('Glisser à gauche', 'Reculer de $back s'),
      ('Glisser à droite', 'Avancer de $forward s'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Aide du lecteur',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Gestes autour de la couverture',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ),
              for (final (keys, label) in gestures)
                ListTile(
                  title: Text(label),
                  trailing: _KeyChip(keys),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Text(
                  'Raccourcis clavier',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  'Disponibles dès qu’un épisode est chargé, hors champ de saisie.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final (keys, label) in shortcuts)
                ListTile(
                  title: Text(label),
                  trailing: _KeyChip(keys),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

bool _isTextInputFocused() {
  final primary = FocusManager.instance.primaryFocus;
  final context = primary?.context;
  if (context == null) return false;
  return context.findAncestorStateOfType<EditableTextState>() != null;
}

/// Espace active déjà le contrôle focalisé (WCAG / comportement natif).
bool _focusHandlesActivation() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return Actions.maybeFind<ActivateIntent>(context) != null;
}
