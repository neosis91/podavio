#!/bin/sh
# Génère un keystore Android release pour Podavio (android/key.properties).
#
# Usage :
#   tool/ci/create_android_keystore.sh
#   tool/ci/create_android_keystore.sh /chemin/vers/dossier
#
# Le fichier .jks et les mots de passe ne doivent JAMAIS être commités.
set -eu

OUT_DIR="${1:-android}"
mkdir -p "${OUT_DIR}"

KEYSTORE="${OUT_DIR}/upload-keystore.jks"
PROPS="${OUT_DIR}/key.properties"
ALIAS="${ANDROID_KEY_ALIAS:-upload}"
VALIDITY_DAYS="${ANDROID_KEYSTORE_VALIDITY_DAYS:-10000}"

if [ -e "${KEYSTORE}" ]; then
  echo "Erreur : ${KEYSTORE} existe déjà. Supprime-le ou choisis un autre dossier." >&2
  exit 1
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "Erreur : keytool introuvable (JDK requis)." >&2
  exit 1
fi

# Mot de passe : fourni ou généré (évite les invites interactives en script).
STORE_PASS="${ANDROID_KEYSTORE_PASSWORD:-}"
KEY_PASS="${ANDROID_KEY_PASSWORD:-}"
if [ -z "${STORE_PASS}" ]; then
  STORE_PASS="$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)"
fi
if [ -z "${KEY_PASS}" ]; then
  KEY_PASS="${STORE_PASS}"
fi

CN="${ANDROID_KEY_CN:-Podavio}"
OU="${ANDROID_KEY_OU:-Podavio}"
O="${ANDROID_KEY_O:-Podavio}"
L="${ANDROID_KEY_L:-}"
ST="${ANDROID_KEY_ST:-}"
C="${ANDROID_KEY_C:-FR}"

DNAME="CN=${CN}, OU=${OU}, O=${O}, C=${C}"
if [ -n "${L}" ]; then
  DNAME="${DNAME}, L=${L}"
fi
if [ -n "${ST}" ]; then
  DNAME="${DNAME}, ST=${ST}"
fi

echo "Création de ${KEYSTORE} (alias=${ALIAS}, validité=${VALIDITY_DAYS} j)…"
keytool -genkeypair \
  -v \
  -keystore "${KEYSTORE}" \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity "${VALIDITY_DAYS}" \
  -alias "${ALIAS}" \
  -storepass "${STORE_PASS}" \
  -keypass "${KEY_PASS}" \
  -dname "${DNAME}"

chmod 600 "${KEYSTORE}"

cat > "${PROPS}" <<EOF
storePassword=${STORE_PASS}
keyPassword=${KEY_PASS}
keyAlias=${ALIAS}
storeFile=$(basename "${KEYSTORE}")
EOF
chmod 600 "${PROPS}"

echo
echo "Fichiers locaux (gitignore) :"
echo "  ${KEYSTORE}"
echo "  ${PROPS}"
echo
echo "Empreinte SHA-256 (à conserver pour vérifier les APK) :"
keytool -list -v -keystore "${KEYSTORE}" -storepass "${STORE_PASS}" -alias "${ALIAS}" \
  | grep -E 'SHA256:|SHA1:' || true
echo "Sauvegarde le .jks et les mots de passe hors Git (coffre / gestionnaire)."
echo "Release : fusionner develop dans main, avec un titre ## AAAA.M.N dans CHANGELOG.md."
echo "Doc : docs/android-signing.md"
