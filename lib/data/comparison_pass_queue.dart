import 'dart:async';

/// Demande de recherche globale en attente.
///
/// [except] vaut `null` quand la reprise doit parcourir tous les podcasts :
/// soit une demande ne sautait personne, soit les demandes n’étaient pas
/// d’accord sur le podcast à sauter.
class _SpreadPending {
  const _SpreadPending(this.except);

  final int? except;

  static _SpreadPending merge(_SpreadPending? prior, int? except) {
    if (prior == null) return _SpreadPending(except);
    if (prior.except == null || except == null || prior.except != except) {
      return const _SpreadPending(null);
    }
    return _SpreadPending(except);
  }
}

/// File des rapprochements : un passage à la fois.
///
/// [spread] fusionne les recherches arrivées pendant qu’une tourne, ou
/// déjà enfilées derrière un autre passage. Elles ne lancent qu’une
/// reprise. Le dernier [body] fourni sert à cette reprise : l’appelant
/// passe toujours le même.
class ComparisonPassQueue {
  Future<void> _chain = Future<void>.value();
  Completer<void>? _spreadGate;
  _SpreadPending? _spreadPending;
  Future<void> Function(int? exceptPodcastId)? _spreadBody;

  /// Enfile [body]. Le suivant n’attend pas qu’un échec précédent.
  Future<void> run(Future<void> Function() body) {
    final done = Completer<void>();
    _chain = _chain.catchError((Object _) {}).then((_) async {
      try {
        await body();
        if (!done.isCompleted) done.complete();
      } catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      }
    });
    return done.future;
  }

  /// Recherche globale. [exceptPodcastId] est le podcast déjà traité,
  /// sauté par cette demande.
  Future<void> spread(
    int? exceptPodcastId,
    Future<void> Function(int? exceptPodcastId) body,
  ) {
    _spreadPending = _SpreadPending.merge(_spreadPending, exceptPodcastId);
    _spreadBody = body;
    final gate = _spreadGate;
    if (gate != null) return gate.future;
    final created = Completer<void>();
    _spreadGate = created;
    unawaited(_drain(created));
    return created.future;
  }

  Future<void> _drain(Completer<void> created) async {
    Object? error;
    StackTrace? stack;
    try {
      await run(() async {
        while (_spreadPending != null) {
          final request = _spreadPending!;
          final action = _spreadBody;
          _spreadPending = null;
          if (action == null) continue;
          try {
            await action(request.except);
          } catch (caught, caughtStack) {
            error ??= caught;
            stack ??= caughtStack;
          }
        }
      });
    } finally {
      _spreadGate = null;
      _spreadBody = null;
      if (!created.isCompleted) {
        if (error != null) {
          created.completeError(error!, stack ?? StackTrace.current);
        } else {
          created.complete();
        }
      }
    }
  }
}
