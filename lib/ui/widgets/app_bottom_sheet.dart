import 'package:flutter/material.dart';

/// [showModalBottomSheet] avec fermeture au clic en dehors, pour toutes les feuilles.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
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
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      var sheet = builder(context);
      if (!callerOwnsChrome) {
        final color =
            sheetColor ??
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
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const SizedBox(width: 32, height: 4),
                  ),
                ),
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
    },
  );
}
