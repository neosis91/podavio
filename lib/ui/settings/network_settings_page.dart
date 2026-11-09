import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../settings/settings_controller.dart';
import 'settings_section_title.dart';

class NetworkSettingsPage extends ConsumerWidget {
  const NetworkSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Network'))),
      body: ListView(
        children: [
          SettingsSectionTitle(context.tr('Data usage')),
          SwitchListTile(
            title: Text(context.tr('Episode downloads')),
            subtitle: Text(
              _networkModeLabel(context, settings.allowMobileData),
            ),
            value: settings.allowMobileData,
            onChanged: notifier.setAllowMobileData,
          ),
          SwitchListTile(
            title: Text(context.tr('Streaming')),
            subtitle: Text(
              _networkModeLabel(context, settings.allowMobileStreaming),
            ),
            value: settings.allowMobileStreaming,
            onChanged: notifier.setAllowMobileStreaming,
          ),
          SwitchListTile(
            title: Text(context.tr('Refresh')),
            subtitle: Text(
              _networkModeLabel(context, settings.allowMobileRefresh),
            ),
            value: settings.allowMobileRefresh,
            onChanged: notifier.setAllowMobileRefresh,
          ),
        ],
      ),
    );
  }
}

String _networkModeLabel(BuildContext context, bool unrestricted) {
  return context.tr(unrestricted ? 'Wi-Fi and mobile data' : 'Wi-Fi only');
}
