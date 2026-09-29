#!/bin/sh
# Publie les artefacts dans le Package Registry puis crée la release GitLab.
set -eu

VERSION="${PODAVIO_VERSION:?PODAVIO_VERSION manquant}"
PACKAGE_NAME="podavio"
API="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${VERSION}"
OUT_DIR="${CI_PROJECT_DIR}/dist/release"
LINKS_FILE="${CI_PROJECT_DIR}/release-assets.links"

mkdir -p "${OUT_DIR}"
: > "${LINKS_FILE}"

upload() {
  src="$1"
  name="$2"
  label="$3"
  cp "${src}" "${OUT_DIR}/${name}"
  echo "Upload ${name}…"
  curl --fail --silent --show-error \
    --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
    --upload-file "${src}" \
    "${API}/${name}"
  url="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${VERSION}/${name}"
  printf '%s\t%s\n' "${label}" "${url}" >> "${LINKS_FILE}"
}

if [ -d dist/android ]; then
  for apk in dist/android/*.apk; do
    [ -f "${apk}" ] || continue
    base="$(basename "${apk}")"
    case "${base}" in
      *armeabi-v7a*)
        upload "${apk}" "podavio-${VERSION}-android-armeabi-v7a.apk" "APK armeabi-v7a"
        ;;
      *arm64-v8a*)
        upload "${apk}" "podavio-${VERSION}-android-arm64-v8a.apk" "APK arm64-v8a"
        ;;
      *x86_64*)
        upload "${apk}" "podavio-${VERSION}-android-x86_64.apk" "APK x86_64"
        ;;
      *universal*)
        upload "${apk}" "podavio-${VERSION}-android-universal.apk" "APK universel"
        ;;
      *)
        upload "${apk}" "podavio-${VERSION}-android-${base}" "APK ${base}"
        ;;
    esac
  done
fi

if [ -d dist/linux ]; then
  for archive in dist/linux/*.tar.gz; do
    [ -f "${archive}" ] || continue
    upload "${archive}" "podavio-${VERSION}-linux-x64.tar.gz" "Linux x64 (.tar.gz)"
  done
fi

echo "Fichiers de release :"
ls -lh "${OUT_DIR}"

if [ ! -s "${LINKS_FILE}" ]; then
  echo "Aucun artefact à publier" >&2
  exit 1
fi

set --
while IFS="$(printf '\t')" read -r label url; do
  [ -n "${url}" ] || continue
  set -- "$@" --assets-link "{\"name\":\"${label}\",\"url\":\"${url}\",\"link_type\":\"package\"}"
done < "${LINKS_FILE}"

DESCRIPTION="Compilation CalVer **${VERSION}**

- Identifiant GitLab : \`${PODAVIO_GITLAB_ID}\`
- Commit : ${CI_COMMIT_SHORT_SHA}

## Fichiers
- APK universel
- APK armeabi-v7a / arm64-v8a / x86_64
- Linux x64 (.tar.gz)"

release-cli create \
  --name "Podavio ${VERSION}" \
  --tag-name "${VERSION}" \
  --ref "${CI_COMMIT_SHA}" \
  --description "${DESCRIPTION}" \
  "$@"
