#!/bin/sh
# Publie les paquets (APK, archives, JSON) dans le Package Registry
# puis crée la release GitLab avec uniquement ces liens.
#
# Note : GitLab ajoute toujours des archives « Source code » sur la page
# Release (non désactivable via l’API). Pour les masquer aux visiteurs :
# Paramètres → Général → Visibilité → Dépôt = Membres uniquement,
# Releases = Tout le monde avec accès.
set -eu

VERSION="${PODAVIO_VERSION:?PODAVIO_VERSION manquant}"
PACKAGE_NAME="podavio"
API="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${VERSION}"
OUT_DIR="${CI_PROJECT_DIR}/dist/release"
LINKS_FILE="${CI_PROJECT_DIR}/release-assets.links"
MANIFEST="${OUT_DIR}/podavio-${VERSION}.json"
ASSETS_JSON="${CI_PROJECT_DIR}/release-assets.jsonl"

mkdir -p "${OUT_DIR}"
: > "${LINKS_FILE}"
: > "${ASSETS_JSON}"

sha256_of() {
  sha256sum "$1" | awk '{print $1}'
}

upload() {
  src="$1"
  name="$2"
  label="$3"
  cp "${src}" "${OUT_DIR}/${name}"
  size="$(wc -c < "${src}" | tr -d ' ')"
  digest="$(sha256_of "${src}")"
  echo "Upload ${name}…"
  curl --fail --silent --show-error \
    --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
    --upload-file "${src}" \
    "${API}/${name}"
  url="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${VERSION}/${name}"
  printf '%s\t%s\n' "${label}" "${url}" >> "${LINKS_FILE}"
  printf '{"name":"%s","label":"%s","url":"%s","size":%s,"sha256":"%s"}\n' \
    "${name}" "${label}" "${url}" "${size}" "${digest}" >> "${ASSETS_JSON}"
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

if [ -d dist/windows ]; then
  for archive in dist/windows/*.zip; do
    [ -f "${archive}" ] || continue
    upload "${archive}" "podavio-${VERSION}-windows-x64.zip" "Windows x64 (.zip, contient podavio.exe)"
  done
fi

if [ ! -s "${LINKS_FILE}" ]; then
  echo "Aucun artefact à publier" >&2
  exit 1
fi

# Manifeste JSON listant uniquement les paquets (pas le code source).
{
  printf '{\n'
  printf '  "name": "podavio",\n'
  printf '  "version": "%s",\n' "${VERSION}"
  printf '  "build": "%s",\n' "${PODAVIO_BUILD:-}"
  printf '  "pipeline_id": "%s",\n' "${PODAVIO_GITLAB_ID:-}"
  printf '  "commit": "%s",\n' "${CI_COMMIT_SHA:-}"
  printf '  "commit_short": "%s",\n' "${CI_COMMIT_SHORT_SHA:-}"
  printf '  "created_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "assets": [\n'
  first=1
  while IFS= read -r line; do
    [ -n "${line}" ] || continue
    if [ "${first}" -eq 1 ]; then
      first=0
    else
      printf ',\n'
    fi
    printf '    %s' "${line}"
  done < "${ASSETS_JSON}"
  printf '\n  ]\n}\n'
} > "${MANIFEST}"

# Upload du JSON après génération (sans l’inclure dans sa propre liste assets).
manifest_name="podavio-${VERSION}.json"
echo "Upload ${manifest_name}…"
curl --fail --silent --show-error \
  --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
  --upload-file "${MANIFEST}" \
  "${API}/${manifest_name}"
manifest_url="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${VERSION}/${manifest_name}"
printf '%s\t%s\n' "Manifeste JSON" "${manifest_url}" >> "${LINKS_FILE}"

echo "Fichiers de release :"
ls -lh "${OUT_DIR}"

set --
while IFS="$(printf '\t')" read -r label url; do
  [ -n "${url}" ] || continue
  set -- "$@" --assets-link "{\"name\":\"${label}\",\"url\":\"${url}\",\"link_type\":\"package\"}"
done < "${LINKS_FILE}"

DESCRIPTION="Compilation CalVer **${VERSION}**

Paquets uniquement (APK, Linux, Windows) + manifeste JSON.
Les archives « Source code » affichées par GitLab sont automatiques et ne font pas partie de cette publication.

- Identifiant GitLab : \`${PODAVIO_GITLAB_ID}\`
- Commit : ${CI_COMMIT_SHORT_SHA}
- Manifeste : \`podavio-${VERSION}.json\`

## Fichiers
- APK universel + ABI (armeabi-v7a, arm64-v8a, x86_64)
- Linux x64 (.tar.gz)
- Windows x64 (.zip contenant \`podavio.exe\` et ses bibliothèques)"

release-cli create \
  --name "Podavio ${VERSION}" \
  --tag-name "${VERSION}" \
  --ref "${CI_COMMIT_SHA}" \
  --description "${DESCRIPTION}" \
  "$@"
