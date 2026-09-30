#!/bin/sh
# Crée le prochain tag CalVer (YYYY.M.N) sur le commit courant.
# À lancer uniquement sur la branche par défaut après un merge.
# Nécessite que le job token puisse créer des tags
# (Paramètres → CI/CD → Job token permissions → repository).
set -eu

YEAR="$(date -u +%Y)"
MONTH="$(date -u +%m | sed 's/^0//')"
PREFIX="${YEAR}.${MONTH}."

api() {
  curl --fail --silent --show-error \
    --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
    "$@"
}

# Ne pas retagger un commit déjà versionné.
refs="$(api "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/repository/commits/${CI_COMMIT_SHA}/refs?type=tag")"
existing="$(printf '%s' "${refs}" | jq -r '
  [.[] | select(.name | test("^[0-9]{4}\\.[0-9]+\\.[0-9]+$")) | .name] | first // empty
')"
if [ -n "${existing}" ]; then
  echo "Commit déjà tagué : ${existing}"
  exit 0
fi

# Plus grand N pour l’année.mois courants (pagination API).
max=0
page=1
while :; do
  response="$(api "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/repository/tags?per_page=100&page=${page}")"
  count="$(printf '%s' "${response}" | jq 'length')"
  if [ "${count}" -eq 0 ]; then
    break
  fi
  page_max="$(printf '%s' "${response}" | jq -r --arg p "${PREFIX}" '
    [
      .[].name
      | select(startswith($p))
      | .[$p | length:]
      | select(test("^[0-9]+$"))
      | tonumber
    ] | max // 0
  ')"
  if [ "${page_max}" -gt "${max}" ]; then
    max="${page_max}"
  fi
  if [ "${count}" -lt 100 ]; then
    break
  fi
  page=$((page + 1))
done

next=$((max + 1))
TAG="${PREFIX}${next}"

echo "Création du tag ${TAG} sur ${CI_COMMIT_SHA}…"
api --request POST \
  --data-urlencode "tag_name=${TAG}" \
  --data-urlencode "ref=${CI_COMMIT_SHA}" \
  --data-urlencode "message=Release ${TAG}" \
  "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/repository/tags" >/dev/null

echo "Tag créé : ${TAG}"
