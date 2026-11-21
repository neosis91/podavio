/// Rythme de l’analyse, lu par l’isolate sans importer le lecteur.
///
/// L’interface le met à jour. Pendant la lecture, l’isolate d’empreinte
/// laisse le cœur libre entre les blocs. Au premier plan sans lecture, il
/// ne fait que céder l’ordonnancement : l’utilisateur attend le résultat.
/// En arrière-plan, sans lecture, il va au plus vite.
class AnalysisPace {
  static var playing = false;
  static var foreground = false;

  /// `play` pendant la lecture, `front` au premier plan, sinon `fast`.
  static String get mode {
    if (playing) return 'play';
    if (foreground) return 'front';
    return 'fast';
  }
}
