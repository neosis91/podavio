# Signature Android (release)

Sans keystore release, Gradle signe les APK en **debug** : une mise à jour
in-place échoue avec `INSTALL_FAILED_UPDATE_INCOMPATIBLE` dès que la
signature change.

## Une seule fois — créer le keystore

Sur une machine de confiance (JDK + `openssl`) :

```bash
chmod +x tool/ci/create_android_keystore.sh
tool/ci/create_android_keystore.sh
```

Ça génère (gitignorés) :

- `android/upload-keystore.jks`
- `android/key.properties`

et l’empreinte SHA-256.

`tool/release_local.sh` refuse de publier si `key.properties` ou le keystore manque. L’action GitHub lit les mêmes secrets.

**Sauvegarde hors Git** le `.jks` et les mots de passe (coffre / gestionnaire).
Si tu perds le keystore, tu ne pourras plus mettre à jour l’app installée avec
la même identité de signature (désinstall / réinstall obligatoire).

## Release

La fusion de `develop` dans `main` compile Android et Linux, puis publie sur podavio.com. Le titre `## AAAA.M.N` doit déjà être dans `CHANGELOG.md`.

`tool/release_local.sh` reste un secours sur une machine qui a le keystore.

## Migration depuis les APK debug

Les installs déjà signées en debug **ne se mettront pas à jour** avec le premier
APK release. Les utilisateurs doivent désinstaller puis réinstaller une fois.
Ensuite, les mises à jour signées avec le même keystore fonctionneront.

## Vérifier un APK

```bash
# Empreinte du keystore
keytool -list -v -keystore android/upload-keystore.jks

# Empreinte de l’APK (apksigner dans le build-tools Android SDK)
apksigner verify --print-certs dist/android/podavio-*-android-universal.apk
```

Les SHA-256 doivent correspondre.
