#!/bin/sh
# Calcule la version CalVer Podavio : année.mois.numéro
# - En CI GitLab : numéro = CI_PIPELINE_IID (incrémenté à chaque pipeline)
# - En local : numéro = 0 (sauf si PODAVIO_BUILD_NUMBER est fixé)
# Identifiant unique GitLab : CI_PIPELINE_ID
set -eu

YEAR="$(date -u +%Y)"
# Mois sans zéro initial : 2026.9.42 et non 2026.09.42
MONTH="$(date -u +%m | sed 's/^0//')"

if [ -n "${CI_PIPELINE_IID:-}" ]; then
  NUMBER="${CI_PIPELINE_IID}"
elif [ -n "${PODAVIO_BUILD_NUMBER:-}" ]; then
  NUMBER="${PODAVIO_BUILD_NUMBER}"
else
  NUMBER="0"
fi

PODAVIO_VERSION="${YEAR}.${MONTH}.${NUMBER}"
PODAVIO_BUILD="${NUMBER}"
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
