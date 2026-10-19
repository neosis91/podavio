import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Vrai quand le contenu vertical a défilé sous la barre.
class FrostedHeaderScroll extends InheritedWidget {
  const FrostedHeaderScroll({
    super.key,
    required this.scrolled,
    required super.child,
  });

  final bool scrolled;

  static bool of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<FrostedHeaderScroll>();
    return scope?.scrolled ?? false;
  }

  @override
  bool updateShouldNotify(FrostedHeaderScroll oldWidget) {
    return scrolled != oldWidget.scrolled;
  }
}

/// Fond givré, identique à l’accueil : invisible au repos, flou et teinté au défilement.
class FrostedHeaderBackdrop extends StatelessWidget {
  const FrostedHeaderBackdrop({super.key, this.scrolled});

  /// Si absent, lit [FrostedHeaderScroll].
  final bool? scrolled;

  @override
  Widget build(BuildContext context) {
    final active = scrolled ?? FrostedHeaderScroll.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final frostAlpha = surface.computeLuminance() >= 0.5 ? 0.35 : 0.55;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: active ? 1 : 0),
      duration: const Duration(milliseconds: 300),
      builder: (context, t, _) {
        if (t == 0) return const SizedBox.expand();
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24 * t, sigmaY: 24 * t),
            child: ColoredBox(
              color: surface.withValues(alpha: frostAlpha * t),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

/// Barre transparente dont le fond se givre avec le défilement.
class FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FrostedAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      bottom: bottom,
      automaticallyImplyLeading: automaticallyImplyLeading,
      forceMaterialTransparency: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      flexibleSpace: const FrostedHeaderBackdrop(),
    );
  }
}

/// Scaffold dont le corps passe sous la barre, pour que le givre ait du contenu à flouter.
class FrostedScaffold extends StatefulWidget {
  const FrostedScaffold({super.key, this.appBar, required this.body});

  final PreferredSizeWidget? appBar;
  final Widget body;

  @override
  State<FrostedScaffold> createState() => _FrostedScaffoldState();
}

class _FrostedScaffoldState extends State<FrostedScaffold> {
  var _scrolled = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final scrolled = notification.metrics.pixels > 0;
    if (scrolled == _scrolled) return false;
    // Les métriques arrivent pendant la mise en page : le setState attend la frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _scrolled == scrolled) return;
        setState(() => _scrolled = scrolled);
      });
      return false;
    }
    setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FrostedHeaderScroll(
      scrolled: _scrolled,
      child: Scaffold(
        extendBodyBehindAppBar: widget.appBar != null,
        appBar: widget.appBar,
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.body,
        ),
      ),
    );
  }
}

/// Ajoute l’inset de la barre, et celui du menu bas, quand le padding est explicite.
///
/// Une [ListView] sans padding reprend le padding du [MediaQuery]. Un padding
/// fourni le remplace. Sous [FrostedScaffold], le haut vaut déjà la hauteur
/// de la barre. Au-dessus, il ne contient que l’inset système : on ajoute
/// alors la barre, sinon le premier élément démarre dessous. Le bas reprend
/// le chrome flottant (menu, mini-lecteur) pour que le dernier élément puisse
/// défiler au-dessus.
EdgeInsets belowFrostedBar(BuildContext context, EdgeInsets padding) {
  final media = MediaQuery.of(context);
  final underBar =
      media.padding.top >= media.viewPadding.top + kToolbarHeight - 1;
  final top = underBar
      ? media.padding.top
      : media.viewPadding.top + kToolbarHeight;
  return padding.copyWith(
    top: padding.top + top,
    bottom: padding.bottom + media.padding.bottom,
  );
}
