#!/bin/sh
# Crée le prochain tag CalVer (YYYY.M.N) sur le commit courant.
# À lancer uniquement sur la branche par défaut après un merge.
#
# Lecture des tags : API GitLab (JOB-TOKEN en lecture).
# Création : git push (le job token n’a souvent pas accès à
# POST /repository/tags, même avec « write repository »).
set -eu

YEAR="$(date -u +%Y)"
MONTH="$(date -u +%m | sed 's/^0//')"
PREFIX="${YEAR}.${MONTH}."

AUTH_HEADER="JOB-TOKEN: ${CI_JOB_TOKEN}"
if [ -n "${PODAVIO_TAG_TOKEN:-}" ]; then
  AUTH_HEADER="PRIVATE-TOKEN: ${PODAVIO_TAG_TOKEN}"
fi

api_get() {
  raw="$(curl --silent --show-error \
    --header "${AUTH_HEADER}" \
    --write-out "\n%{http_code}" \
    "$1")"
  code="$(printf '%s' "${raw}" | tail -n1)"
  body="$(printf '%s' "${raw}" | sed '$d')"
  if [ "${code}" -lt 200 ] || [ "${code}" -ge 300 ]; then
    echo "API GET échoué (${code}) : $1" >&2
    printf '%s\n' "${body}" >&2
    exit 1
  fi
  printf '%s' "${body}"
}

# Ne pas retagger un commit déjà versionné.
refs="$(api_get "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/repository/commits/${CI_COMMIT_SHA}/refs?type=tag")"
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
  response="$(api_get "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/repository/tags?per_page=100&page=${page}")"
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

echo "Création du tag ${TAG} sur ${CI_COMMIT_SHA} (git push)…"

git config user.email "${GITLAB_USER_EMAIL:-ci@podavio.local}"
git config user.name "${GITLAB_USER_NAME:-Podavio CI}"
git tag -a "${TAG}" -m "Release ${TAG}" "${CI_COMMIT_SHA}"

if [ -n "${PODAVIO_TAG_TOKEN:-}" ]; then
  # oauth2 + PAT fonctionne pour push HTTP
  push_url="https://oauth2:${PODAVIO_TAG_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git"
  git push "${push_url}" "refs/tags/${TAG}"
else
  # origin est déjà authentifié via CI_REPOSITORY_URL (job token)
  git push origin "refs/tags/${TAG}"
fi

echo "Tag créé : ${TAG}"
