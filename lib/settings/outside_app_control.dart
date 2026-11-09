/// Boutons latéraux hors de l’application (notification, casque, Android Auto).
enum OutsideAppControl {
  skip('skip', 'Time skip'),
  episode('episode', 'Previous and next episode');

  const OutsideAppControl(this.id, this.label);

  final String id;
  final String label;

  static OutsideAppControl byId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return OutsideAppControl.skip;
  }
}
