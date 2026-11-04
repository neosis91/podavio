/// Attend que les téléchargements soient au repos.
///
/// L’actualisation s’interrompt entre deux flux pour ne pas charger le réseau
/// en même temps qu’un téléchargement déjà en cours.
Future<void> waitUntilDownloadsIdle({
  required bool Function() busy,
  bool Function()? alive,
}) async {
  final stillAlive = alive ?? () => true;
  while (stillAlive() && busy()) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

/// Vrai tant qu’un fichier se télécharge ou attend un créneau.
bool downloadsAreBusy({required int running, required int waiting}) {
  return running > 0 || waiting > 0;
}
