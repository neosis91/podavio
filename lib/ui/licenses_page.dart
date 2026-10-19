import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../core/build_info.dart';
import '../core/licenses.dart';
import 'widgets/brand.dart';
import 'widgets/frosted_header.dart';

final _packageInfo = PackageInfo.fromPlatform();

class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  late final Future<List<_PackageLicense>> _licenses = _loadLicenses();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FrostedScaffold(
      appBar: FrostedAppBar(title: Text(context.tr('Licenses'))),
      body: FutureBuilder<List<_PackageLicense>>(
        future: _licenses,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final packages = snapshot.data!;
          return ListView.builder(
            itemCount: packages.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    children: [
                      const PodavioLogo(width: 120),
                      const SizedBox(height: 12),
                      FutureBuilder<PackageInfo>(
                        future: _packageInfo,
                        builder: (context, info) {
                          final packaged = info.data?.version;
                          final version = BuildInfo.version.isNotEmpty
                              ? BuildInfo.version
                              : packaged;
                          if (version == null || version.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            version,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Logiciels tiers inclus dans Podavio. '
                        'Leurs licences sont listées automatiquement.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }
              final package = packages[index - 1];
              final creators = package.creators.join(' · ');
              return ListTile(
                title: Text(package.displayName),
                subtitle: creators.isEmpty
                    ? null
                    : Text(
                        creators,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => _LicenseDetailPage(package: package),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LicenseDetailPage extends StatelessWidget {
  const _LicenseDetailPage({required this.package});

  final _PackageLicense package;

  @override
  Widget build(BuildContext context) {
    final creators = package.creators.join('\n');
    return FrostedScaffold(
      appBar: FrostedAppBar(title: Text(package.displayName)),
      body: ListView(
        padding: belowFrostedBar(context, const EdgeInsets.all(24)),
        children: [
          if (creators.isNotEmpty) ...[
            Text(
              creators,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
          ],
          for (var i = 0; i < package.licenses.length; i++) ...[
            if (i > 0) const SizedBox(height: 24),
            SelectableText(package.licenses[i]),
          ],
        ],
      ),
    );
  }
}

class _PackageLicense {
  _PackageLicense({
    required this.name,
    required this.licenses,
    required this.creators,
  }) : displayName = friendlyLicenseName(name);

  final String name;
  final String displayName;
  final List<String> licenses;
  final List<String> creators;
}

Future<List<_PackageLicense>> _loadLicenses() async {
  final byPackage = <String, _MutablePackageLicense>{};
  await for (final entry in LicenseRegistry.licenses) {
    final text = entry.paragraphs
        .map((paragraph) => paragraph.text)
        .join('\n\n')
        .trim();
    if (text.isEmpty) continue;
    final creators = extractLicenseCreators(text);
    for (final name in entry.packages) {
      final package = byPackage.putIfAbsent(
        name,
        () => _MutablePackageLicense(name),
      );
      if (!package.licenses.contains(text)) {
        package.licenses.add(text);
      }
      for (final creator in creators) {
        if (!package.creators.contains(creator)) {
          package.creators.add(creator);
        }
      }
    }
  }
  final packages =
      [
        for (final package in byPackage.values)
          _PackageLicense(
            name: package.name,
            licenses: package.licenses,
            creators: package.creators,
          ),
      ]..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
  return packages;
}

class _MutablePackageLicense {
  _MutablePackageLicense(this.name);

  final String name;
  final licenses = <String>[];
  final creators = <String>[];
}
