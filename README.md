# Podavio

Podavio est un lecteur de podcasts pour Android, iOS, Windows, macOS et Linux. On s’abonne à n’importe quel flux RSS, sans compte obligatoire et sans publicité dans l’application.

## Fonctions

- Recherche et tendances via l’annuaire iTunes, centré sur la France
- Ajout d’un podcast par adresse RSS
- Import et export OPML des abonnements
- Épisodes non lus, file d’attente réordonnable, favoris et historique
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

## Suite prévue

- Contrôles de lecture dans la notification, sur l’écran de verrouillage et avec le casque
- Chapitres Podcasting 2.0
- Téléchargement automatique et suppression selon l’espace
- Synchronisation des abonnements, dans l’esprit de gPodder
