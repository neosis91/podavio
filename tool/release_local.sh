#!/usr/bin/env sh
# Compile Android + Linux sur cette machine et publie une release GitLab.
# Aucun runner SaaS : le tag est poussé avec ci.skip.
#
# Usage :
#   tool/release_local.sh              # affiche la prochaine version CalVer
#   tool/release_local.sh 2026.10.6
#
# Prérequis : flutter, glab (connecté), android/key.properties + keystore.
# Le dépôt du site (../podavio-site, ou PODAVIO_SITE_DIR) doit être sur main,
# propre et à jour : les binaires y sont commités puis poussés. La CI du site
# les copie sur le VPS. Le binaire Windows n'est pas produit ici.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

if [ -x "${HOME}/development/flutter/bin/flutter" ]; then
  PATH="${HOME}/development/flutter/bin:${PATH}"
fi

suggest_next() {
  year="$(date -u +%Y)"
  month="$(date -u +%m | sed 's/^0//')"
  prefix="${year}.${month}."
  max=0
  for tag in $(git tag --list "${prefix}*"); do
    n="${tag##*.}"
    case "${n}" in
      ''|*[!0-9]*) continue ;;
    esac
    if [ "${n}" -gt "${max}" ]; then
      max="${n}"
    fi
  done
  echo "${prefix}$((max + 1))"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -eq 0 ]; then
  echo "Récupération des tags…"
  git fetch --tags origin
  next="$(suggest_next)"
  echo "Usage : tool/release_local.sh <YYYY.M.N>"
  echo "Prochaine version : ${next}"
  echo "Exemple : tool/release_local.sh ${next}"
  echo "Journal : un titre ## ${next} dans CHANGELOG.md, avec une puce par changement."
  exit 0
fi

if [ $# -ne 1 ]; then
  echo "Usage : tool/release_local.sh <YYYY.M.N>" >&2
  exit 2
fi

VERSION="$1"
if ! printf '%s' "${VERSION}" | grep -Eq '^[0-9]{4}\.[0-9]+\.[0-9]+$'; then
  echo "Version invalide : ${VERSION} (attendu YYYY.M.N, ex. 2026.10.6)." >&2
  exit 2
fi

echo "Récupération des tags…"
git fetch --tags origin

SHA_FULL="$(git rev-parse HEAD)"
SHA="$(git rev-parse --short HEAD)"
# Nom affiché = tag, mois sans zéro (2026.9.12).
# Entier Android = CalVer AAAAMMNN, le même sur chaque APK (20260912).
rest="${VERSION#*.}"
month="${rest%%.*}"
patch="${VERSION##*.}"
year="${VERSION%%.*}"
if [ "${month}" -lt 1 ] || [ "${month}" -gt 12 ]; then
  echo "Mois invalide dans ${VERSION}." >&2
  exit 2
fi
if [ "${patch}" -gt 99 ]; then
  echo "Le numéro ${patch} dépasse 99." >&2
  exit 2
fi
BUILD="$(printf '%d%02d%02d' "${year}" "${month}" "${patch}")"

if [ -n "$(git status --porcelain)" ]; then
  echo "Arbre de travail modifié. Commit ou stash avant une release." >&2
  git status --porcelain >&2
  exit 1
fi

for cmd in flutter glab git tar python3; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Commande manquante : ${cmd}" >&2
    exit 1
  fi
done

prop() {
  sed -n "s/^$1=//p" android/key.properties | head -n 1
}

if [ ! -f android/key.properties ]; then
  echo "android/key.properties manquant." >&2
  echo "Le keystore android/upload-keystore.jks est déjà là : remets le key.properties qui va avec." >&2
  echo "Ne relance pas create_android_keystore.sh, ça changerait la signature des mises à jour." >&2
  exit 1
fi

for key in storePassword keyPassword keyAlias storeFile; do
  if [ -z "$(prop "${key}")" ]; then
    echo "android/key.properties : ${key} manquant." >&2
    exit 1
  fi
done

store_file="$(prop storeFile)"
case "${store_file}" in
  /*) ;;
  *) store_file="android/${store_file}" ;;
esac
if [ ! -f "${store_file}" ]; then
  echo "Keystore introuvable : ${store_file}" >&2
  exit 1
fi

remote_commit="$(git ls-remote --tags origin "refs/tags/${VERSION}" | awk '/\^\{\}$/ { print $1; exit }')"
if [ -z "${remote_commit}" ]; then
  remote_commit="$(git ls-remote --tags origin "refs/tags/${VERSION}" | awk '{ print $1; exit }')"
fi
if [ -n "${remote_commit}" ] && [ "${remote_commit}" != "${SHA_FULL}" ]; then
  echo "Le tag ${VERSION} existe déjà sur origin et pointe vers un autre commit." >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/${VERSION}" >/dev/null; then
  local_commit="$(git rev-parse "${VERSION}^{}")"
  if [ "${local_commit}" != "${SHA_FULL}" ]; then
    echo "Le tag local ${VERSION} pointe vers un autre commit." >&2
    exit 1
  fi
fi

python3 tool/changelog.py check "${VERSION}"

echo "Podavio ${VERSION} (build ${BUILD}, commit ${SHA})"

flutter build apk --release \
  --build-name="${VERSION}" \
  --build-number="${BUILD}" \
  --dart-define=PODAVIO_VERSION="${VERSION}" \
  --dart-define=GITLAB_COMMIT_SHA="${SHA}"
flutter build apk --release --split-per-abi \
  --build-name="${VERSION}" \
  --build-number="${BUILD}" \
  --dart-define=PODAVIO_VERSION="${VERSION}" \
  --dart-define=GITLAB_COMMIT_SHA="${SHA}"
flutter build linux --release \
  --build-name="${VERSION}" \
  --build-number="${BUILD}" \
  --dart-define=PODAVIO_VERSION="${VERSION}" \
  --dart-define=GITLAB_COMMIT_SHA="${SHA}"

rm -rf dist/android dist/linux
mkdir -p dist/android dist/linux

cp build/app/outputs/flutter-apk/app-release.apk \
  "dist/android/podavio-${VERSION}-android-universal.apk"
cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk \
  "dist/android/podavio-${VERSION}-android-armeabi-v7a.apk"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  "dist/android/podavio-${VERSION}-android-arm64-v8a.apk"
cp build/app/outputs/flutter-apk/app-x86_64-release.apk \
  "dist/android/podavio-${VERSION}-android-x86_64.apk"

# Un APK signé debug s'installe, mais ne met pas à jour l'application release.
PODAVIO_STORE_PASS="$(prop storePassword)"
export PODAVIO_STORE_PASS
expected_sha="$(
  keytool -list -v -keystore "${store_file}" -storepass:env PODAVIO_STORE_PASS 2>/dev/null \
    | sed -n 's/^[[:space:]]*SHA256: //p' | head -1 | tr -d ':' | tr 'A-F' 'a-f'
)"
unset PODAVIO_STORE_PASS
if [ -z "${expected_sha}" ]; then
  echo "Impossible de lire l'empreinte du keystore." >&2
  exit 1
fi
apksigner=""
for dir in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "${HOME}/Android/Sdk"; do
  [ -n "${dir}" ] || continue
  found="$(find "${dir}/build-tools" -name apksigner -type f 2>/dev/null | sort | tail -1)"
  if [ -n "${found}" ]; then
    apksigner="${found}"
    break
  fi
done
if [ -z "${apksigner}" ]; then
  echo "apksigner introuvable : impossible de vérifier la signature des APK." >&2
  exit 1
fi
for apk in dist/android/podavio-"${VERSION}"-android-*.apk; do
  actual_sha="$(
    "${apksigner}" verify --print-certs "${apk}" \
      | sed -n 's/.*SHA-256 digest: //p' | head -1 | tr 'A-F' 'a-f'
  )"
  if [ "${actual_sha}" != "${expected_sha}" ]; then
    echo "Signature incorrecte : ${apk}" >&2
    echo "L'APK n'est pas signé avec android/upload-keystore.jks." >&2
    exit 1
  fi
done

bundle="dist/linux/podavio-${VERSION}-linux-x64"
cp -a build/linux/x64/release/bundle "${bundle}"
tar -C dist/linux -czf "${bundle}.tar.gz" "$(basename "${bundle}")"
rm -rf "${bundle}"

if [ -n "$(git status --porcelain)" ]; then
  echo "La compilation a modifié des fichiers suivis. Tag non créé." >&2
  git status --porcelain >&2
  exit 1
fi

if ! git rev-parse -q --verify "refs/tags/${VERSION}" >/dev/null; then
  git tag -a "${VERSION}" -m "Podavio ${VERSION}"
fi

git push -o ci.skip origin "refs/tags/${VERSION}"

NOTES="$(python3 tool/changelog.py gitlab "${VERSION}")
Commit : ${SHA}"

if glab release view "${VERSION}" >/dev/null 2>&1; then
  echo "Release GitLab ${VERSION} déjà présente."
else
  glab release create "${VERSION}" \
    --name "Podavio ${VERSION}" \
    --notes "${NOTES}" \
    --use-package-registry \
    --package-name podavio \
    "dist/android/podavio-${VERSION}-android-universal.apk#APK universel" \
    "dist/android/podavio-${VERSION}-android-armeabi-v7a.apk#APK armeabi-v7a" \
    "dist/android/podavio-${VERSION}-android-arm64-v8a.apk#APK arm64-v8a" \
    "dist/android/podavio-${VERSION}-android-x86_64.apk#APK x86_64" \
    "dist/linux/podavio-${VERSION}-linux-x64.tar.gz#Linux x64 (.tar.gz)"
fi

publish_site() {
  if [ -n "${PODAVIO_SITE_DIR:-}" ]; then
    site="${PODAVIO_SITE_DIR}"
  else
    site="${ROOT}/../podavio-site"
  fi
  if [ ! -d "${site}/.git" ]; then
    echo "Dépôt du site introuvable : ${site}" >&2
    exit 1
  fi
  site="$(CDPATH= cd -- "${site}" && pwd)"

  if [ "$(git -C "${site}" branch --show-current)" != "main" ]; then
    echo "Le dépôt du site n'est pas sur main (${site})." >&2
    exit 1
  fi
  if [ -n "$(git -C "${site}" status --porcelain)" ]; then
    echo "Le dépôt du site a des modifications. Commit ou stash avant une release." >&2
    git -C "${site}" status --porcelain >&2
    exit 1
  fi

  echo "Mise à jour du site…"
  git -C "${site}" fetch origin main
  if [ "$(git -C "${site}" rev-parse HEAD)" != "$(git -C "${site}" rev-parse origin/main)" ]; then
    echo "Le dépôt du site n'est pas à jour avec origin/main." >&2
    exit 1
  fi

  dest="${site}/releases/${VERSION}"
  rm -rf "${dest}"
  mkdir -p "${dest}"
  for name in \
    "podavio-${VERSION}-android-universal.apk" \
    "podavio-${VERSION}-android-armeabi-v7a.apk" \
    "podavio-${VERSION}-android-arm64-v8a.apk" \
    "podavio-${VERSION}-android-x86_64.apk"
  do
    cp "dist/android/${name}" "${dest}/${name}"
  done
  cp "dist/linux/podavio-${VERSION}-linux-x64.tar.gz" \
    "${dest}/podavio-${VERSION}-linux-x64.tar.gz"

  python3 "${ROOT}/tool/changelog.py" publish \
    --version "${VERSION}" \
    --date "$(date -u +%F)" \
    --site "${site}"

  git -C "${site}" add latest.json changelog.json journal/index.html "releases/${VERSION}"
  if git -C "${site}" diff --cached --quiet; then
    echo "Le site contient déjà les fichiers ${VERSION}."
    return 0
  fi

  git -C "${site}" commit -m "$(cat <<EOF
Publier Podavio ${VERSION} sur podavio.com.

EOF
)"
  git -C "${site}" push origin main
  echo "Site poussé. La CI copie les fichiers sur le serveur."
}

publish_site

echo "Release ${VERSION} publiée (commit ${SHA})."
