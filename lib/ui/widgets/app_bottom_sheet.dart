import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Route au premier plan d’un navigateur.
Route<dynamic>? foregroundRoute(NavigatorState navigator) {
  Route<dynamic>? top;
  navigator.popUntil((route) {
    top = route;
    return true;
  });
  return top;
}

/// Ferme la route modale au premier plan : bottom sheet, sinon dialogue.
///
/// Une page ordinaire n’est pas fermée.
bool popForegroundPopup(NavigatorState navigator) {
  final top = foregroundRoute(navigator);
  if (top is! PopupRoute<dynamic>) return false;
  navigator.pop();
  return true;
}

/// Ferme la bottom sheet si elle est la route au premier plan.
///
/// Une feuille recouverte par une autre route n’est pas fermée.
bool popForegroundBottomSheet(NavigatorState navigator) {
  if (foregroundRoute(navigator) is! ModalBottomSheetRoute<dynamic>) {
    return false;
  }
  return popForegroundPopup(navigator);
}

/// Observateur du navigateur racine : une feuille cesse d’intercepter
/// le retour dès qu’une autre route passe devant elle.
final sheetBackObserver = _SheetBackObserver();

class _SheetBackObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _defer();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _defer();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _defer();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _defer();

  void _defer() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final root = navigator;
      if (root == null) return;
      _SheetBackGuard.syncRoot(root);
    });
  }
}

class _SheetBackGuard {
  _SheetBackGuard(this.root, this.pageRoute);

  static final active = <_SheetBackGuard>[];

  final NavigatorState root;
  final ModalRoute<dynamic>? pageRoute;
  LocalHistoryEntry? _entry;
  var _silent = false;
  var _disposed = false;

  static _SheetBackGuard attach(BuildContext context) {
    final root = Navigator.of(context, rootNavigator: true);
    final nested = _nestedNavigator(context, root);
    final current = nested == null ? null : foregroundRoute(nested);
    final page =
        current is ModalRoute<dynamic> &&
            current is! ModalBottomSheetRoute<dynamic>
        ? current
        : _pageAlreadyKnown(root);
    final guard = _SheetBackGuard(root, page);
    active.add(guard);
    return guard;
  }

  void noteSheet() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) syncRoot(root);
    });
  }

  static ModalRoute<dynamic>? _pageAlreadyKnown(NavigatorState root) {
    for (final guard in active.reversed) {
      if (identical(guard.root, root) && guard.pageRoute != null) {
        return guard.pageRoute;
      }
    }
    return null;
  }

  static void syncRoot(NavigatorState root) {
    final top = foregroundRoute(root);
    final guards = [
      for (final guard in active)
        if (!guard._disposed && identical(guard.root, root)) guard,
    ];
    final capable = [
      for (final guard in guards)
        if (guard.pageRoute != null) guard,
    ];
    final cover = top is PopupRoute<dynamic> && capable.isNotEmpty;
    final keeper = cover ? capable.last : null;
    for (final guard in guards) {
      guard.hold(identical(guard, keeper));
    }
  }

  void hold(bool shouldHold) {
    if (shouldHold) {
      _ensureEntry();
      return;
    }
    final entry = _entry;
    if (entry == null) return;
    _silent = true;
    entry.remove();
    _entry = null;
    _silent = false;
  }

  void dispose() {
    _disposed = true;
    hold(false);
    active.remove(this);
  }

  void _ensureEntry() {
    final page = pageRoute;
    if (_entry != null || page == null || !page.isActive) return;
    final entry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: _onHistoryRemoved,
    );
    _entry = entry;
    page.addLocalHistoryEntry(entry);
  }

  void _onHistoryRemoved() {
    _entry = null;
    if (_silent || _disposed || !root.mounted) return;
    popForegroundPopup(root);
  }
}

NavigatorState? _nestedNavigator(BuildContext context, NavigatorState root) {
  NavigatorState? found;
  context.visitAncestorElements((element) {
    if (element is StatefulElement && element.state is NavigatorState) {
      final state = element.state as NavigatorState;
      if (!identical(state, root)) {
        found = state;
        return false;
      }
    }
    return true;
  });
  return found;
}

/// [showModalBottomSheet] avec fermeture au clic en dehors, pour toutes les feuilles.
///
/// Le navigateur racine place la feuille au-dessus du menu et du mini-lecteur.
/// Tant qu’elle est la route au premier plan, le retour la ferme avant la page.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  ThemeData? theme,
  bool isScrollControlled = false,
  bool useRootNavigator = true,
  bool showDragHandle = false,
  bool enableDrag = true,
  bool isDismissible = true,
  AnimationController? transitionAnimationController,
  BoxConstraints? constraints,
  ShapeBorder? shape,
  double? elevation,
  Clip? clipBehavior,
  bool useSafeArea = true,
  String? barrierLabel,
  Color? barrierColor,
}) async {
  final sheetColor = backgroundColor;
  final callerOwnsChrome = sheetColor == Colors.transparent;
  final guard = _SheetBackGuard.attach(context);
  try {
    return await showModalBottomSheet<T>(
      context: context,
      // Transparent pour que la zone au-dessus de la feuille reste cliquable.
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled || callerOwnsChrome,
      useRootNavigator: useRootNavigator,
      // Poignée dessinée dans notre chrome ; celle de Flutter irait en haut d’écran.
      showDragHandle: false,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      transitionAnimationController: transitionAnimationController,
      constraints: constraints,
      shape: shape,
      elevation: elevation,
      clipBehavior: clipBehavior,
      useSafeArea: useSafeArea,
      barrierLabel: barrierLabel,
      barrierColor: barrierColor,
      builder: (context) {
        guard.noteSheet();
        final sheetTheme = theme ?? Theme.of(context);
        return Theme(
          data: sheetTheme,
          child: Builder(
            builder: (context) => _sheetChrome(
              context,
              builder: builder,
              backgroundColor: sheetColor,
              callerOwnsChrome: callerOwnsChrome,
              showDragHandle: showDragHandle,
              elevation: elevation,
              shape: shape,
              clipBehavior: clipBehavior,
              isDismissible: isDismissible,
            ),
          ),
        );
      },
    );
  } finally {
    guard.dispose();
  }
}

Widget _sheetChrome(
  BuildContext context, {
  required WidgetBuilder builder,
  required Color? backgroundColor,
  required bool callerOwnsChrome,
  required bool showDragHandle,
  required double? elevation,
  required ShapeBorder? shape,
  required Clip? clipBehavior,
  required bool isDismissible,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  var sheet = builder(context);
  if (!callerOwnsChrome) {
    final color =
        backgroundColor ??
        theme.bottomSheetTheme.backgroundColor ??
        scheme.surfaceContainerLow;
    sheet = Material(
      color: color,
      elevation: elevation ?? theme.bottomSheetTheme.elevation ?? 0,
      shape:
          shape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
      clipBehavior: clipBehavior ?? Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) ...[
            const SizedBox(height: 12),
            const SheetDragHandle(),
          ],
          sheet,
        ],
      ),
    );
  }
  if (!isDismissible) {
    return Align(alignment: Alignment.bottomCenter, child: sheet);
  }
  return Stack(
    fit: StackFit.expand,
    children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
      ),
      Align(alignment: Alignment.bottomCenter, child: sheet),
    ],
  );
}

/// Thème de l’application, au-dessus de la teinte de la pochette.
ThemeData themeAboveCover(BuildContext context) {
  var seenTheme = false;
  ThemeData? outer;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is! Theme) return true;
    if (!seenTheme) {
      seenTheme = true;
      return true;
    }
    outer = widget.data;
    return false;
  });
  return outer ?? Theme.of(context);
}

/// Poignée Material, 32×4, même dans une liste qui étire ses enfants.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant
        .withValues(alpha: 0.4);
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: 32,
        height: 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
