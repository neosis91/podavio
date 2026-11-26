import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/skip_segments.dart';
import '../l10n/l10n.dart';
import '../settings/global_skip.dart';

/// Pastille de la couleur SponsorBlock du type.
class SkipKindMark extends StatelessWidget {
  const SkipKindMark(this.kind, {super.key, this.size = 14});

  final SkipSegmentKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color(skipKindArgb(kind)),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface
              .withValues(alpha: 0.28),
        ),
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}

/// Pastille et nombre, sur une ligne de gestion.
class SkipKindCount extends StatelessWidget {
  const SkipKindCount({super.key, required this.kind, required this.count});

  final SkipSegmentKind kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final shown = shownSkipKind(kind);
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Tooltip(
      message: context.tr(skipKindLabel(shown)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SkipKindMark(shown, size: 10),
          const SizedBox(width: 4),
          Text('$count', style: style),
        ],
      ),
    );
  }
}

/// Interrupteur d’un type. La pub entraîne le sponsor, et l’inverse.
class SkipKindSwitch extends ConsumerWidget {
  const SkipKindSwitch(this.kind, {super.key});

  final SkipSegmentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(globalSkipSettingsProvider).kinds;
    final shown = shownSkipKind(kind);
    final enabled = shown == SkipSegmentKind.ad
        ? selected.contains(SkipSegmentKind.ad) ||
              selected.contains(SkipSegmentKind.sponsor)
        : selected.contains(kind);
    return SwitchListTile(
      secondary: SkipKindMark(shown),
      title: Text(context.tr(skipKindLabel(shown))),
      value: enabled,
      onChanged: (value) {
        final notifier = ref.read(globalSkipSettingsProvider.notifier);
        if (shown == SkipSegmentKind.ad) {
          notifier.setKinds(const [
            SkipSegmentKind.ad,
            SkipSegmentKind.sponsor,
          ], enabled: value);
        } else {
          notifier.setKind(kind, enabled: value);
        }
      },
    );
  }
}
