# Podavio

Podavio est un lecteur de podcasts pour Android, iOS, Windows, macOS et Linux. On s’abonne à n’importe quel flux RSS, sans compte obligatoire et sans publicité dans l’application.

## Fonctions

- Recherche et tendances via l’annuaire iTunes, centré sur la France
- Ajout d’un podcast par adresse RSS
- Import et export OPML des abonnements
- Épisodes non lus, playlist réordonnable, favoris et lectures récentes
- Lecteur avec position mémorisée, vitesse, sauts et minuteur de sommeil
- Téléchargement des épisodes pour les écouter hors ligne
- Thème clair, sombre ou système
- Navigation adaptée au téléphone et au bureau

## Prérequis

- [Flutter](https://docs.flutter.dev/install) 3.47.7, canal stable
- Pour Linux : CMake, Ninja, Clang, GTK 3 et mpv (`sudo pacman -S cmake ninja clang gtk3 mpv`)
- Pour Android : Android SDK
- Pour iOS et macOS : Xcode, sur un Mac
- Pour Windows : Visual Studio avec la charge de travail C++

Sur cette machine, le SDK utilisé pour créer le projet est installé dans `/home/bertrand/development/flutter`. Ajoutez-le au `PATH` :

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

## Lancer l’application

```bash
flutter pub get
flutter run -d android
flutter run -d ios
flutter run -d linux
flutter run -d macos
flutter run -d windows
```

`flutter devices` liste les appareils disponibles. Les tests :

```bash
flutter test
```

## Podavio Web

Le navigateur et le téléphone passent par le relais dans `companion/server`. Ce processus sert aussi la page, sur le port 8787. Le QR code pointe vers cette même adresse, donc la page et le relais se lancent ensemble.

```bash
cd companion/web
npm install
npm run build
cd ../server
npm install
npm start
```

Puis ouvrir http://127.0.0.1:8787. `npm install` n’est utile que la première fois, ou après un changement de dépendances. Pour revoir la page après une modification, relancer `npm run build` dans `companion/web`, puis redémarrer `npm start`.

## Compiler

Linux :

```bash
flutter build linux
```

Le programme est dans `build/linux/x64/release/bundle/`.

Android :

```bash
flutter build apk
```

L’APK est `build/app/outputs/flutter-apk/app-release.apk`. Une release signée passe par `tool/release_local.sh`, décrit plus bas.

## Émulateur Android

L’image installée sur cette machine est `Pixel_7_API_34`.

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
flutter emulators --launch Pixel_7_API_34
flutter run -d emulator-5554
```

`flutter devices` confirme que l’émulateur est prêt avant `flutter run`.

## Publier une release

Les binaires sont compilés sur cette machine, puis envoyés avec `glab`. Ça ne consomme pas de minutes GitLab. Android et Linux uniquement.

```bash
tool/release_local.sh              # affiche la prochaine version
tool/release_local.sh 2026.10.6    # compile, tague, publie
```

Le tag est poussé avec `ci.skip`. La CI ne lance plus que les contrôles de merge request.

Le script copie ensuite les APK et l’archive Linux dans `../podavio-site/releases/<version>/`, met à jour `latest.json` et le journal, puis pousse `main` de ce dépôt. Cela se fait avant le tag, à partir de `origin/main`, donc des modifications locales dans le dépôt du site n’empêchent pas la publication. Sa CI envoie le tout sur le serveur. Un autre chemin se passe avec `PODAVIO_SITE_DIR`.

Les nouveautés se rédigent dans `CHANGELOG.md`, sous un titre `## AAAA.M.N`, une puce par ligne. Ce texte devient les notes de la release GitLab et la page Journal du site. La section `## Non publié` reste un brouillon.

## Signature Android

Les APK de release doivent être signés avec le keystore déjà en place, `android/upload-keystore.jks`, et son `android/key.properties`. Voir [docs/android-signing.md](docs/android-signing.md). Ne pas relancer la création du keystore : la signature changerait et les mises à jour in-place échoueraient.

## Suite prévue

- Contrôles de lecture dans la notification, sur l’écran de verrouillage et avec le casque
- Chapitres Podcasting 2.0
- Téléchargement automatique et suppression selon l’espace
- Synchronisation des abonnements, dans l’esprit de gPodder
