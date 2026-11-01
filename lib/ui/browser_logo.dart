import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String? browserName(String? id) {
  return switch (id) {
    'chrome' => 'Google Chrome',
    'chromium' => 'Chromium',
    'firefox' => 'Firefox',
    'safari' => 'Safari',
    'edge' => 'Microsoft Edge',
    'opera' => 'Opera',
    'brave' => 'Brave',
    'samsung' => 'Samsung Internet',
    'vivaldi' => 'Vivaldi',
    _ => null,
  };
}

String? osName(String? id) {
  return switch (id) {
    'linux' => 'Linux',
    'windows' => 'Windows',
    'macos' => 'macOS',
    'android' => 'Android',
    'ios' => 'iOS',
    'chromeos' => 'ChromeOS',
    _ => null,
  };
}

String? linkedDeviceLabel(String? browser, String? os) {
  final name = browserName(browser);
  final system = osName(os);
  if (name == null && system == null) return null;
  if (name == null) return system;
  if (system == null) return name;
  return '$name ($system)';
}

class BrowserLogo extends StatelessWidget {
  const BrowserLogo({super.key, required this.browser, this.size = 40});

  final String? browser;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (browser) {
      'chrome' => 'assets/brand/browsers/chrome.svg',
      'chromium' => 'assets/brand/browsers/chromium.svg',
      'firefox' => 'assets/brand/browsers/firefox.svg',
      'safari' => 'assets/brand/browsers/safari.svg',
      'edge' => 'assets/brand/browsers/edge.svg',
      'opera' => 'assets/brand/browsers/opera.svg',
      'brave' => 'assets/brand/browsers/brave.svg',
      'samsung' => 'assets/brand/browsers/samsung.svg',
      'vivaldi' => 'assets/brand/browsers/vivaldi.svg',
      _ => null,
    };
    if (asset == null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.language,
          size: size * 0.55,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class OsLogo extends StatelessWidget {
  const OsLogo({super.key, required this.os, this.size = 40});

  final String? os;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (os) {
      'linux' => 'assets/brand/os/linux.svg',
      'windows' => 'assets/brand/os/windows.svg',
      'macos' || 'ios' => 'assets/brand/os/apple.svg',
      'android' => 'assets/brand/os/android.svg',
      'chromeos' => 'assets/brand/os/chromeos.svg',
      _ => null,
    };
    if (asset == null) return const SizedBox.shrink();
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: os == 'macos' || os == 'ios'
          ? ColorFilter.mode(
              Theme.of(context).colorScheme.onSurface,
              BlendMode.srcIn,
            )
          : null,
    );
  }
}

class LinkedDeviceMark extends StatelessWidget {
  const LinkedDeviceMark({
    super.key,
    required this.browser,
    required this.os,
    this.size = 40,
  });

  final String? browser;
  final String? os;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasBrowser = browserName(browser) != null;
    final hasOs = osName(os) != null;
    if (!hasBrowser && !hasOs) return BrowserLogo(browser: browser, size: size);
    if (!hasBrowser) return OsLogo(os: os, size: size);
    if (!hasOs) return BrowserLogo(browser: browser, size: size);
    final badge = size * 0.46;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: BrowserLogo(browser: browser, size: size - badge * 0.32),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(size * 0.03),
                child: OsLogo(os: os, size: badge * 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
