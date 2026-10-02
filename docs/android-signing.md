# Signature Android (release)

Sans keystore release, les APK CI étaient signés en **debug** : une mise à jour
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

et affiche les valeurs à coller dans GitLab + l’empreinte SHA-256.

**Sauvegarde hors Git** le `.jks` et les mots de passe (coffre / gestionnaire).
Si tu perds le keystore, tu ne pourras plus mettre à jour l’app installée avec
la même identité de signature (désinstall / réinstall obligatoire).

Build local release après création :

```bash
flutter build apk --release
```

## GitLab CI/CD — variables

**Settings → CI/CD → Variables** (projet ou groupe) :

| Variable | Type | Protected | Masked | Contenu |
|----------|------|-----------|--------|---------|
| `ANDROID_KEYSTORE_BASE64` | Variable | oui | non* | `base64 -w0 android/upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Variable | oui | oui | store password |
| `ANDROID_KEY_PASSWORD` | Variable | oui | oui | key password |
| `ANDROID_KEY_ALIAS` | Variable | oui | oui | `upload` (par défaut) |

\* Le base64 du keystore est trop long pour *Masked* sur GitLab ; **Protected**
reste indispensable.

### Alternative : variable File

Au lieu de `ANDROID_KEYSTORE_BASE64`, tu peux créer une variable **File**
`ANDROID_KEYSTORE` et, dans le job, définir :

```yaml
variables:
  ANDROID_KEYSTORE_PATH: "$ANDROID_KEYSTORE"
```

(`setup_android_signing.sh` accepte déjà `ANDROID_KEYSTORE_PATH`.)

## Tags / branches protégés

Les variables *Protected* ne sont injectées que sur **branches et tags protégés**.

Pour Podavio (tags CalVer auto après merge sur `main`) :

1. Protège `main` (déjà probable).
2. **Settings → Repository → Protected tags** : pattern `20*`
   (CalVer fixe `année.mois.incrément`, ex. `2026.10.3`).
3. Vérifie qu’un pipeline de tag voit bien les quatre variables (job
   `build:android` échoue sinon avec un message clair).

## Ce que fait la CI

Le job `build:android` exécute `tool/ci/setup_android_signing.sh`, qui :

1. décode le keystore (ou utilise le File) ;
2. écrit `android/key.properties` (éphémère, non publié) ;
3. laisse Gradle signer en **release** via `android/app/build.gradle.kts`.

Les artefacts APK ne contiennent pas le keystore.

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
