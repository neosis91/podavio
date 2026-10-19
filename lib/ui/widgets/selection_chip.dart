import 'package:flutter/material.dart';

/// Pastille : plein `primary` si elle est choisie, sinon seulement un contour.
/// Pas de coche.
class SelectionChip extends StatelessWidget {
  const SelectionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      avatar: avatar,
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      elevation: 0,
      pressElevation: 0,
      shape: const StadiumBorder(),
      side: BorderSide(
        color: selected ? Colors.transparent : scheme.outlineVariant,
      ),
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return Colors.transparent;
      }),
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
