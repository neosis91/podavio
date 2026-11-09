import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../settings/settings_controller.dart';
import '../../sync/sync_controller.dart';
import '../widgets/messages.dart';
import 'settings_section_title.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final syncConnected = ref.watch(
      syncStatusProvider.select((status) => status.connected),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Notifications'))),
      body: ListView(
        children: [
          SettingsSectionTitle(context.tr('Downloads')),
          SwitchListTile(
            title: Text(context.tr('Download progress')),
            subtitle: Text(
              context.tr(
                'Shows a notification while an episode downloads, and when it finishes.',
              ),
            ),
            value: settings.notifyDownloadActivity,
            onChanged: notifier.setNotifyDownloadActivity,
          ),
          SwitchListTile(
            title: Text(context.tr('Download errors')),
            subtitle: Text(
              context.tr('Shows a notification when a download fails.'),
            ),
            value: settings.notifyDownloadErrors,
            onChanged: notifier.setNotifyDownloadErrors,
          ),
          SettingsSectionTitle(context.tr('Synchronization')),
          SwitchListTile(
            title: Text(context.tr('Synchronization errors')),
            subtitle: Text(
              context.tr(
                syncConnected
                    ? 'Shows a notification when synchronization fails.'
                    : 'Connect a synchronization service to enable this.',
              ),
            ),
            value: settings.notifySyncErrors,
            onChanged: syncConnected ? notifier.setNotifySyncErrors : null,
          ),
          SettingsSectionTitle(context.tr('New episodes')),
          SwitchListTile(
            title: Text(context.tr('Notify about new episodes')),
            subtitle: Text(
              context.tr(
                'Notifies when a subscription publishes. Each podcast can be turned off in its settings. Turning this off keeps those choices.',
              ),
            ),
            value: settings.notifyNewEpisodes,
            onChanged: (enabled) =>
                _setNotifyNewEpisodes(context, ref, enabled),
          ),
        ],
      ),
    );
  }
}

Future<void> _setNotifyNewEpisodes(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  if (enabled) {
    try {
      await ref
          .read(databaseProvider)
          .enableEpisodeNotificationForSubscriptions();
    } catch (error) {
      if (context.mounted) showMessage(context, errorText(error));
      return;
    }
  }
  await ref.read(settingsProvider.notifier).setNotifyNewEpisodes(enabled);
}
