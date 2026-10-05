#!/usr/bin/env sh
# Politique squash des MR :
# - vers develop  → squash obligatoire
# - develop→main  → squash interdit
set -eu

if [ "${CI_PIPELINE_SOURCE:-}" != "merge_request_event" ]; then
  echo "Hors merge request : rien à vérifier."
  exit 0
fi

TARGET="${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:?}"
SOURCE="${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:?}"
IID="${CI_MERGE_REQUEST_IID:?}"

MR="$(curl -fsS --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
  "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests/${IID}")"
SQUASH="$(printf '%s' "$MR" | jq -r '.squash')"

echo "MR !${IID} : ${SOURCE} → ${TARGET} (squash=${SQUASH})"

if [ "$TARGET" = "develop" ]; then
  if [ "$SQUASH" != "true" ]; then
    echo "Erreur : le squash est obligatoire pour fusionner vers develop."
    echo "Cochez « Squash commits » sur la merge request."
    exit 1
  fi
  echo "OK : squash requis vers develop."
  exit 0
fi

if [ "$TARGET" = "main" ] && [ "$SOURCE" = "develop" ]; then
  if [ "$SQUASH" != "false" ]; then
    echo "Erreur : le squash est interdit pour develop → main."
    echo "Décochez « Squash commits » sur la merge request."
    exit 1
  fi
  echo "OK : pas de squash pour develop → main."
  exit 0
fi

echo "OK : aucune contrainte squash pour ${SOURCE} → ${TARGET}."
