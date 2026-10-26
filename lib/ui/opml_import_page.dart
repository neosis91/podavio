import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/opml.dart';
import '../data/opml_import_controller.dart';
import '../data/providers.dart';
import 'widgets/cover.dart';
import 'widgets/messages.dart';

class OpmlImportPage extends ConsumerStatefulWidget {
  const OpmlImportPage({super.key, required this.entries});

  final List<OpmlEntry> entries;

  @override
  ConsumerState<OpmlImportPage> createState() => _OpmlImportPageState();
}

class _OpmlImportPageState extends ConsumerState<OpmlImportPage> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {};
  }

  Set<String> _subscribedKeys(Iterable<String> feedUrls) {
    return {for (final url in feedUrls) normalizeFeedUrl(url)};
  }

  bool _isSubscribed(OpmlEntry entry, Set<String> subscribed) {
    return subscribed.contains(normalizeFeedUrl(entry.feedUrl));
  }

  void _syncDefaultSelection(Set<String> subscribed, bool importing) {
    if (_selected.isNotEmpty || importing) return;
    final defaults = <String>{
      for (final entry in widget.entries)
        if (!_isSubscribed(entry, subscribed)) entry.feedUrl,
    };
    if (defaults.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selected.isNotEmpty) return;
      setState(() => _selected.addAll(defaults));
    });
  }

  @override
  Widget build(BuildContext context) {
    final importing = ref.watch(opmlImportProvider.select((s) => s.isRunning));
    final podcasts = ref.watch(podcastsProvider).value ?? const [];
    final subscribed = _subscribedKeys(podcasts.map((p) => p.feedUrl));
    _syncDefaultSelection(subscribed, importing);

    final selectable = widget.entries
        .where((entry) => !_isSubscribed(entry, subscribed))
        .toList();
    final selectedCount = _selected
        .where((url) => !subscribed.contains(normalizeFeedUrl(url)))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer des abonnements'),
        actions: [
          if (!importing && selectable.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  if (selectedCount == selectable.length) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(selectable.map((entry) => entry.feedUrl));
                  }
                });
              },
              child: Text(
                selectedCount == selectable.length
                    ? 'Tout décocher'
                    : 'Tout cocher',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.entries.length,
              itemBuilder: (context, index) {
                final entry = widget.entries[index];
                final already = _isSubscribed(entry, subscribed);
                final checked = already
                    ? false
                    : _selected.contains(entry.feedUrl);
                return CheckboxListTile(
                  value: already ? true : checked,
                  onChanged: already || importing
                      ? null
                      : (value) {
                          setState(() {
                            if (value ?? false) {
                              _selected.add(entry.feedUrl);
                            } else {
                              _selected.remove(entry.feedUrl);
                            }
                          });
                        },
                  secondary: PodcastCover(url: entry.imageUrl, size: 48),
                  title: Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    already ? 'Déjà abonné' : entry.feedUrl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: importing || selectedCount == 0
                    ? null
                    : _importSelected,
                child: Text(
                  importing
                      ? 'Import en cours…'
                      : selectedCount == 0
                      ? 'Importer'
                      : 'Importer ($selectedCount)',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _importSelected() {
    final podcasts = ref.read(podcastsProvider).value ?? const [];
    final subscribed = _subscribedKeys(podcasts.map((p) => p.feedUrl));
    final toImport = [
      for (final entry in widget.entries)
        if (_selected.contains(entry.feedUrl) &&
            !_isSubscribed(entry, subscribed))
          entry,
    ];
    if (toImport.isEmpty) return;

    final started = ref.read(opmlImportProvider.notifier).start(toImport);
    if (!started) {
      showMessage(context, 'Un import est déjà en cours');
      return;
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}
