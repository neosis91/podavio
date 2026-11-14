<p align="center">
  <img src="assets/brand/logo.png" alt="Podavio" width="240">
</p>

<p align="center">
  A free podcast player for Android, Windows, and Linux.<br>
  Subscribe to any RSS feed, with no account and no ads in the app.
</p>

<p align="center">
  <a href="https://github.com/neosis91/podavio/releases/latest"><img alt="Download" src="https://img.shields.io/github/v/release/neosis91/podavio?label=download&color=2ea44f"></a>
  <a href="LICENSE"><img alt="GPL-3.0 only" src="https://img.shields.io/badge/license-GPL--3.0--only-blue"></a>
</p>

<p align="center">
  <a href="https://github.com/neosis91/podavio/releases/latest"><b>GitHub release</b></a>
  ·
  <a href="https://podavio.com/download"><b>podavio.com/download</b></a>
  ·
  <a href="https://web.podavio.com"><b>Podavio Web</b></a>
</p>

> Podavio Web opens the phone’s library in the browser after a QR code is scanned.

## Features

- Search Apple Podcasts, Podcast Index, and fyyd, and add a show by RSS address
- Import and export subscriptions as OPML
- Unplayed episodes, a reorderable playlist, favorites, recent plays, and statistics
- A player with a remembered position, playback speed, skips, and a sleep timer
- Episode downloads, including automatic downloads, for offline listening
- Chapters, a light, dark, or system theme, eco mode, and comfortable or compact lists
- Chromecast and Android Auto
- Podavio Web: the phone’s library in the browser
- An update check against the latest GitHub release

## Screenshots

<p align="center">
  <img src="store/play/phone-home-fr.png" alt="Home" width="240">
  <img src="store/play/phone-subscriptions-fr.png" alt="Subscriptions" width="240">
  <img src="store/play/phone-library-fr.png" alt="Library" width="240">
</p>

## Data

- A podcast is an RSS feed. The audio stays on the publisher’s server. Podavio plays it, caches it, or downloads it.
- Search and suggestions query Apple Podcasts, Podcast Index, and fyyd.
- Subscriptions are exchanged as OPML.
- The library, downloaded files, and playback position stay on the device.

## Privacy

Podavio does not ask for an account and does not show ads.

The GitHub release sends crashes to [Sentry](https://sentry.io) so they can be tied to a version. [Sentry](https://github.com/getsentry/sentry) is free software. That report includes the IP address. Only the opening of the app is traced.

A build compiled without the Sentry address sends nothing. That is the case for a local `flutter run`, and it will be the case for an F-Droid build, which compiles the repository without that secret.

## Which file to download

The [latest release](https://github.com/neosis91/podavio/releases/latest) contains:

- Android: `podavio-*-android-arm64-v8a.apk` for most phones. `universal` when the architecture is unknown. `armeabi-v7a` and `x86_64` are provided as well. Android 8 is the minimum. `podavio-*-android-wear.apk` is the Wear OS remote. It is installed on the watch, not on the phone.
- Windows: `podavio-*-windows-x64.msi`. Opening it installs Podavio for the current user and adds a Start menu shortcut. `podavio-*-windows-x64.zip` extracts and runs with `podavio.exe`, without a shortcut.
- Linux: `podavio-*-linux-amd64.deb` for Debian, Ubuntu, and derivatives. `sudo apt install ./podavio-*-linux-amd64.deb`. The `podavio-*-linux-x64.tar.gz` archive remains for a manual extract. The system provides GTK 3, libsecret, libcurl, and libmpv. On EndeavourOS and Arch Linux, the AUR package `podavio-bin` is installed with `yay -S podavio-bin`.

The page [podavio.com/download](https://podavio.com/download) points to the same files. When the app offers an update, it opens that page.

macOS and iOS build from source. They are not in the release.

## Translating

Interface strings live in `l10n/`, one JSON file per language: Arabic, Chinese, Dutch, English, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese, Russian, Spanish, and Turkish. The key is the English text. In `l10n/en.json`, each value repeats its key. The other files hold the translation.

To add a string, write it in code with `context.tr('…')`, add it to `l10n/en.json`, then to the languages that already exist. Then:

```bash
dart run tool/l10n_generate.dart
```

The script rewrites `lib/l10n/messages.dart`. Do not edit that file by hand. A missing translation shows the English text.

## Questions

**Is an account required?**
No. An RSS feed is enough.

**Where does the audio go?**
It stays with the podcast’s publisher. Podavio does not host it.

**Does the release send data?**
It sends crashes to Sentry, with the IP address, so the app can be fixed. A build without the Sentry address does not.

**How do I update?**
The app compares the installed version with the latest GitHub release. The button opens [podavio.com/download](https://podavio.com/download).

## Contributing

Report an idea or a defect in the [issues](https://github.com/neosis91/podavio/issues).

A change starts on a branch and opens toward `develop`. That merge is a squash. The merge from `develop` into `main` is a merge commit, without a squash: that merge publishes the GitHub release.

Please read the [code of conduct](CODE_OF_CONDUCT.md) before taking part.

## Sponsors

Sentry sponsors Podavio and provides crash reporting for the release.

<p align="center">
  <a href="https://sentry.io/for/open-source/"><img src="https://sentry-brand.storage.googleapis.com/sentry-wordmark-dark-280x84.png" alt="Sentry" width="280" height="84"></a>
</p>

## License

Podavio is free software, under the GNU General Public License v3.0 only. The text is in [LICENSE](LICENSE). There are no ads, no subscription, and no paid feature in the app.

Episodes stay on their publishers’ servers. Podavio reads the feed and the file. The program is provided as is, without warranty, as the license states.
