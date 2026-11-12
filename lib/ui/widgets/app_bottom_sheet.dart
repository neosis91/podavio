import 'package:flutter/material.dart';

/// [showModalBottomSheet] avec fermeture au clic en dehors, pour toutes les feuilles.
///
/// Le navigateur racine place la feuille au-dessus du menu et du mini-lecteur.
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
}) {
  final sheetColor = backgroundColor;
  final callerOwnsChrome = sheetColor == Colors.transparent;
  return showModalBottomSheet<T>(
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
