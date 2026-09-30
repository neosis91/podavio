#!/bin/sh
# Calcule la version CalVer Podavio : année.mois.numéro
# - Sur un tag CalVer (ex. 2026.9.6) : la version est le tag (seule source d’incrément)
# - Hors tag : prévisualisation YYYY.M.0 (ne consomme pas la séquence)
# Identifiant unique GitLab : CI_PIPELINE_ID
set -eu

YEAR="$(date -u +%Y)"
# Mois sans zéro initial : 2026.9.6 et non 2026.09.6
MONTH="$(date -u +%m | sed 's/^0//')"

if [ -n "${CI_COMMIT_TAG:-}" ] && echo "${CI_COMMIT_TAG}" | grep -Eq '^[0-9]{4}\.[0-9]+\.[0-9]+$'; then
  PODAVIO_VERSION="${CI_COMMIT_TAG}"
  NUMBER="${CI_COMMIT_TAG##*.}"
  PODAVIO_BUILD="${NUMBER}"
elif [ -n "${PODAVIO_BUILD_NUMBER:-}" ]; then
  NUMBER="${PODAVIO_BUILD_NUMBER}"
  PODAVIO_VERSION="${YEAR}.${MONTH}.${NUMBER}"
  PODAVIO_BUILD="${NUMBER}"
else
  # Hors tag : pas d’incrément CalVer
  NUMBER="0"
  PODAVIO_VERSION="${YEAR}.${MONTH}.0"
  PODAVIO_BUILD="${CI_PIPELINE_ID:-0}"
fi

PODAVIO_GITLAB_ID="${CI_PIPELINE_ID:-}"

export PODAVIO_VERSION PODAVIO_BUILD PODAVIO_GITLAB_ID

if [ "${1:-}" = "--dotenv" ]; then
  {
    echo "PODAVIO_VERSION=${PODAVIO_VERSION}"
    echo "PODAVIO_BUILD=${PODAVIO_BUILD}"
    echo "PODAVIO_GITLAB_ID=${PODAVIO_GITLAB_ID}"
  } > "${2:-version.env}"
fi

echo "Podavio ${PODAVIO_VERSION} (build ${PODAVIO_BUILD}, GitLab ${PODAVIO_GITLAB_ID:-local})"
