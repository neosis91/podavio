import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../sync/gpodder_client.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_protocol.dart';
import 'widgets/list_metrics.dart';
import 'widgets/messages.dart';

enum _SyncStep { home, providers, server, login, devices, authorize }

/// Même parcours qu’AntennaPod : fournisseur, serveur, connexion, appareil.
class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  _SyncStep _step = _SyncStep.home;
  SyncProviderOption? _option;
  final _host = TextEditingController(text: 'https://gpodder.net');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _deviceName = TextEditingController(text: 'Podavio');
  var _busy = false;
  GpodderDraft? _draft;
  NextcloudLoginStart? _pendingLogin;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    _host.dispose();
    _username.dispose();
    _password.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Synchronization')),
        leading: BackButton(onPressed: _back),
      ),
      body: switch (_step) {
        _SyncStep.home => _home(status),
        _SyncStep.providers => _providers(),
        _SyncStep.server => _server(),
        _SyncStep.login => _login(),
        _SyncStep.devices => _devices(),
        _SyncStep.authorize => _authorize(),
      },
    );
  }

  Widget _home(SyncStatus status) {
    if (!status.connected) {
      return ListView(
        padding: underChrome(context, const EdgeInsets.fromLTRB(24, 8, 24, 24)),
        children: [
          Text(
            context.tr(
              'Devices need a central server to share subscriptions and listening progress. Podavio does not host that server. Connect one of the services below. Others can be added later.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(() => _step = _SyncStep.providers),
            child: Text(context.tr('Choose synchronization provider')),
          ),
        ],
      );
    }
    final provider = status.provider;
    final when = status.lastAttempt == null
        ? context.tr('Not synchronized yet')
        : context.tr('Last synchronization: {when}', {
            'when': DateFormat.yMMMd().add_Hm().format(
              status.lastAttempt!.toLocal(),
            ),
          });
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.sync),
          title: Text(context.tr(provider?.titleKey ?? 'Synchronization')),
          subtitle: Text(
            status.deviceCaption.isEmpty
                ? status.username
                : '${status.username} · ${status.deviceCaption}',
          ),
        ),
        ListTile(
          title: Text(when),
          subtitle: Text(_statusLine(context, status)),
        ),
        ListTile(
          enabled: !status.busy,
          leading: status.busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          title: Text(
            status.busy
                ? context.tr('Synchronizing…')
                : context.tr('Synchronize now'),
          ),
          onTap: status.busy
              ? null
              : () => _run(() => ref.read(syncStatusProvider.notifier).sync()),
        ),
        ListTile(
          enabled: !status.busy,
          title: Text(context.tr('Force synchronization')),
          subtitle: Text(
            context.tr(
              'Uploads the played state of episodes listened to on this device.',
            ),
          ),
          onTap: status.busy
              ? null
              : () => _run(
                  () => ref.read(syncStatusProvider.notifier).sync(force: true),
                ),
        ),
        ListTile(title: Text(context.tr('Log out')), onTap: _logout),
      ],
    );
  }

  Widget _providers() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            context.tr(
              'Devices need a central server to share subscriptions and listening progress. Podavio does not host that server. Connect one of the services below. Others can be added later.',
            ),
          ),
        ),
        for (final option in syncProviderOptions)
          ListTile(
            title: Text(context.tr(option.titleKey)),
            subtitle: Text(context.tr(option.summaryKey)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _option = option;
                _host.text = option.id == syncProviderGpodder
                    ? 'https://gpodder.net'
                    : '';
                _step = _SyncStep.server;
              });
            },
          ),
      ],
    );
  }

  Widget _server() {
    final option = _option;
    final insecure = _host.text.trim().startsWith('http://');
    return ListView(
      padding: underChrome(context, const EdgeInsets.all(24)),
      children: [
        Text(
          context.tr(
            'Enter the address (URL or IP) of your synchronization server.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: context.tr('Server address'),
            helperText: insecure
                ? context.tr('This address is not encrypted.')
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy || option == null ? null : _proceedServer,
          child: Text(
            option?.browserLogin == true
                ? context.tr('Proceed')
                : context.tr('Proceed to login'),
          ),
        ),
      ],
    );
  }

  Widget _login() {
    return ListView(
      padding: underChrome(context, const EdgeInsets.all(24)),
      children: [
        TextField(
          controller: _username,
          autocorrect: false,
          decoration: InputDecoration(labelText: context.tr('Username')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: context.tr('Password')),
          onSubmitted: (_) => _loginGpodder(),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _loginGpodder,
          child: Text(context.tr('Log in')),
        ),
      ],
    );
  }

  Widget _devices() {
    final devices = _draft?.devices ?? const <SyncDevice>[];
    return ListView(
      padding: underChrome(context, const EdgeInsets.only(bottom: 24)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            context.tr(
              'On the server, link this device to the others so they stay together.',
            ),
          ),
        ),
        if (devices.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(context.tr('No device on this account yet.')),
          ),
        for (final device in devices)
          ListTile(
            title: Text(device.caption.isEmpty ? device.id : device.caption),
            subtitle: Text(device.id),
            onTap: _busy ? null : () => _chooseDevice(device),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _deviceName,
            decoration: InputDecoration(labelText: context.tr('Device name')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton(
            onPressed: _busy ? null : () => _chooseDevice(null),
            child: Text(context.tr('Create a device')),
          ),
        ),
      ],
    );
  }

  Widget _authorize() {
    return ListView(
      padding: underChrome(context, const EdgeInsets.all(24)),
      children: [
        Text(context.tr('Authorize Podavio in the browser, then come back.')),
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _pendingLogin == null ? null : _openLogin,
          child: Text(context.tr('Open the browser')),
        ),
      ],
    );
  }

  void _back() {
    switch (_step) {
      case _SyncStep.home:
        Navigator.pop(context);
      case _SyncStep.providers:
        setState(() => _step = _SyncStep.home);
      case _SyncStep.server:
        setState(() => _step = _SyncStep.providers);
      case _SyncStep.login:
        setState(() => _step = _SyncStep.server);
      case _SyncStep.devices:
        setState(() => _step = _SyncStep.login);
      case _SyncStep.authorize:
        _poll?.cancel();
        setState(() => _step = _SyncStep.server);
    }
  }

  Future<void> _proceedServer() async {
    final option = _option;
    if (option == null) return;
    if (option.browserLogin) {
      await _startNextcloud();
      return;
    }
    setState(() => _step = _SyncStep.login);
  }

  Future<void> _loginGpodder() async {
    await _run(() async {
      final draft = await ref
          .read(syncStatusProvider.notifier)
          .authenticateGpodder(
            host: _host.text,
            username: _username.text,
            password: _password.text,
          );
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _step = _SyncStep.devices;
      });
    });
  }

  Future<void> _chooseDevice(SyncDevice? device) async {
    final draft = _draft;
    if (draft == null) return;
    await _run(() async {
      await ref
          .read(syncStatusProvider.notifier)
          .finishGpodder(
            draft: draft,
            device: device,
            newCaption: device == null ? _deviceName.text : null,
            deviceType: _deviceType(),
          );
      if (!mounted) return;
      setState(() => _step = _SyncStep.home);
    });
  }

  Future<void> _startNextcloud() async {
    await _run(() async {
      final start = await ref
          .read(syncStatusProvider.notifier)
          .beginNextcloud(_host.text);
      if (!mounted) return;
      setState(() {
        _pendingLogin = start;
        _step = _SyncStep.authorize;
      });
      await _openLogin();
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_pollNextcloud());
      });
    });
  }

  Future<void> _openLogin() async {
    final login = _pendingLogin?.login;
    if (login == null) return;
    await launchUrl(login, mode: LaunchMode.externalApplication);
  }

  Future<void> _pollNextcloud() async {
    final start = _pendingLogin;
    if (start == null || _busy) return;
    try {
      final done = await ref
          .read(syncStatusProvider.notifier)
          .finishNextcloudPoll(start: start, host: _host.text);
      if (!done || !mounted) return;
      _poll?.cancel();
      setState(() => _step = _SyncStep.home);
    } on SyncRequestException catch (error) {
      if (!mounted) return;
      showMessage(context, _errorText(context, error));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Log out')),
        content: Text(
          context.tr(
            'Log out of synchronization? Subscriptions stay on this device.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Log out')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(syncStatusProvider.notifier).logout();
  }

  Future<void> _run(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } on SyncRequestException catch (error) {
      if (mounted) showMessage(context, _errorText(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _deviceType() {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return 'mobile';
      default:
        return 'desktop';
    }
  }
}

String _statusLine(BuildContext context, SyncStatus status) {
  if (status.busy) return context.tr('Synchronizing…');
  if (status.lastOk || status.error == null) {
    return status.host;
  }
  return _errorText(context, SyncRequestException(status.error!));
}

String _errorText(BuildContext context, SyncRequestException error) {
  if (error.unauthorized || error.message == 'credentials') {
    return context.tr('Wrong username or password.');
  }
  if (error.message == 'host') {
    return context.tr(
      'Enter the address (URL or IP) of your synchronization server.',
    );
  }
  if (error.message == 'unreachable') {
    return context.tr('The synchronization server did not respond.');
  }
  return context.tr('The synchronization server did not respond.');
}
