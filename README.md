# Podavio

Podavio est un lecteur de podcasts pour Android, iOS, Windows, macOS et Linux. On s’abonne à n’importe quel flux RSS, sans compte obligatoire et sans publicité dans l’application.

## Fonctions

- Recherche et tendances via l’annuaire iTunes, centré sur la France
- Ajout d’un podcast par adresse RSS
- Import et export OPML des abonnements
- Épisodes non lus, playlist réordonnable, favoris et historique
- Lecteur avec position mémorisée, vitesse, sauts et minuteur de sommeil
- Téléchargement des épisodes pour les écouter hors ligne
- Thème clair, sombre ou système
- Navigation adaptée au téléphone et au bureau

## Prérequis

- [Flutter](https://docs.flutter.dev/install) 3.47, canal stable
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

## Publier une release

Les binaires sont compilés sur cette machine, puis envoyés avec `glab`. Ça ne consomme pas de minutes GitLab. Android et Linux uniquement.

```bash
tool/release_local.sh              # affiche la prochaine version
tool/release_local.sh 2026.10.6    # compile, tague, publie
```

Le tag est poussé avec `ci.skip`. La CI ne lance plus que les contrôles de merge request.

## Signature Android

Les APK de release doivent être signés avec le keystore déjà en place, `android/upload-keystore.jks`, et son `android/key.properties`. Voir [docs/android-signing.md](docs/android-signing.md). Ne pas relancer la création du keystore : la signature changerait et les mises à jour in-place échoueraient.

## Suite prévue

- Contrôles de lecture dans la notification, sur l’écran de verrouillage et avec le casque
- Chapitres Podcasting 2.0
- Téléchargement automatique et suppression selon l’espace
- Synchronisation des abonnements, dans l’esprit de gPodder
