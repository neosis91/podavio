# Podavio

[![Licence : GPL-3.0 uniquement](https://img.shields.io/badge/licence-GPL--3.0--uniquement-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Podavio est un lecteur de podcasts libre pour Android, iOS, Windows, macOS et Linux. On s’abonne à n’importe quel flux RSS, sans compte obligatoire et sans publicité dans l’application.

Les versions Android et Linux sont sur [podavio.com](https://podavio.com). Le compagnon dans le navigateur est sur [web.podavio.com](https://web.podavio.com).

## Fonctions

- Recherche de podcasts, centrée sur la France, et ajout par adresse RSS
- Import et export OPML des abonnements
- Épisodes non lus, playlist réordonnable, favoris et lectures récentes
- Lecteur avec position mémorisée, vitesse, sauts et minuteur de sommeil
- Téléchargement des épisodes pour les écouter hors ligne, y compris en automatique
- Chapitres, thème clair, sombre ou système, et mode éco
- Podavio Web : la bibliothèque du téléphone, ouverte dans le navigateur après un scan du QR code

## Retours

Un défaut ou une idée se signale dans les [tickets GitHub](https://github.com/neosis91/podavio/issues).

## Licence

Podavio est distribué sous la GNU General Public License v3.0 uniquement. Le texte est dans [LICENSE](LICENSE).

## Traduire

Les textes de l’interface sont dans `l10n/`, un fichier JSON par langue. La clé est le texte anglais. Dans `l10n/en.json`, chaque valeur recopie sa clé. Les autres fichiers portent la traduction.

Pour en ajouter une, l’écrire dans le code avec `context.tr('…')`, l’ajouter dans `l10n/en.json`, puis dans les langues déjà présentes. Ensuite :

```bash
dart run tool/l10n_generate.dart
```

Le script réécrit `lib/l10n/messages.dart`. On ne modifie pas ce fichier à la main. Une traduction absente affiche l’anglais.

## Compiler

Podavio se compile comme un projet [Flutter](https://docs.flutter.dev/install) stable.

- Linux : CMake, Ninja, Clang, GTK 3 et mpv
- Android : Android SDK
- iOS et macOS : Xcode, sur un Mac
- Windows : Visual Studio avec la charge de travail C++

```bash
flutter pub get
flutter run
```

`flutter devices` liste les appareils disponibles. Les tests :

```bash
flutter test
```

Linux : `flutter build linux` place le programme dans `build/linux/x64/release/bundle/`.

Android : `flutter build apk` produit `build/app/outputs/flutter-apk/app-release.apk`. Une release signée utilise le keystore décrit dans [docs/android-signing.md](docs/android-signing.md).

Le navigateur et le téléphone passent par le relais dans `companion/server`. Ce processus sert aussi la page, sur le port 8787. Le QR code pointe vers cette même adresse.

```bash
cd companion/web
npm install
npm run build
cd ../server
npm install
npm start
```

Puis ouvrir http://127.0.0.1:8787. `npm install` n’est utile que la première fois, ou après un changement de dépendances. Pour revoir la page après une modification, relancer `npm run build` dans `companion/web`, puis redémarrer `npm start`.
