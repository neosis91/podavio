#!/bin/sh
# Prépare la signature release Android en CI (ou en local avec les env vars).
# Attend les variables :
#   ANDROID_KEYSTORE_BASE64  — keystore .jks/.keystore encodé base64
#   ANDROID_KEYSTORE_PASSWORD
#   ANDROID_KEY_PASSWORD
#   ANDROID_KEY_ALIAS
#
# Alternative : ANDROID_KEYSTORE_PATH pointe déjà vers un fichier keystore existant
# (Variable GitLab de type File, ou chemin local).
#
# Écrit android/key.properties et (si besoin) android/ci-upload-keystore.jks
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="${ROOT}/android"
PROPS="${ANDROID_DIR}/key.properties"
DECODED_KEYSTORE="${ANDROID_DIR}/ci-upload-keystore.jks"

require() {
  eval "val=\${$1-}"
  if [ -z "${val}" ]; then
    echo "Erreur : variable $1 manquante (signature release Android)." >&2
    exit 1
  fi
}

if [ -n "${ANDROID_KEYSTORE_PATH:-}" ] && [ -f "${ANDROID_KEYSTORE_PATH}" ]; then
  STORE_FILE="${ANDROID_KEYSTORE_PATH}"
elif [ -n "${ANDROID_KEYSTORE_BASE64:-}" ]; then
  require ANDROID_KEYSTORE_BASE64
  printf '%s' "${ANDROID_KEYSTORE_BASE64}" | base64 -d > "${DECODED_KEYSTORE}"
  chmod 600 "${DECODED_KEYSTORE}"
  STORE_FILE="${DECODED_KEYSTORE}"
else
  echo "Erreur : fournir ANDROID_KEYSTORE_BASE64 ou ANDROID_KEYSTORE_PATH." >&2
  exit 1
fi

require ANDROID_KEYSTORE_PASSWORD
require ANDROID_KEY_PASSWORD
require ANDROID_KEY_ALIAS

# storeFile relatif à android/ si le fichier est dans android/
case "${STORE_FILE}" in
  "${ANDROID_DIR}"/*)
    STORE_FILE_PROP="$(basename "${STORE_FILE}")"
    ;;
  *)
    STORE_FILE_PROP="${STORE_FILE}"
    ;;
esac

cat > "${PROPS}" <<EOF
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyPassword=${ANDROID_KEY_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
storeFile=${STORE_FILE_PROP}
EOF
chmod 600 "${PROPS}"

# Exporte le chemin absolu pour Gradle (prioritaire sur key.properties).
export ANDROID_KEYSTORE_PATH="${STORE_FILE}"

echo "Signature Android prête (alias=${ANDROID_KEY_ALIAS}, store=${STORE_FILE})"
