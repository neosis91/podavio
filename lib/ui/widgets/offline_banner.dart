import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/online_status.dart';
import '../../l10n/l10n.dart';

/// Bandeau fin, rouge, comme l’indication hors ligne de YouTube.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineStatusProvider);
    if (online != false) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: ColoredBox(
        key: const Key('offline-banner'),
        color: podavioRed,
        child: SizedBox(
          height: 28,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                context.tr('No internet connection'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
