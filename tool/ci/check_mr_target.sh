#!/usr/bin/env sh
# Cibles de merge request :
# - develop → main uniquement
# - toute autre branche → develop uniquement
set -eu

if [ "${CI_PIPELINE_SOURCE:-}" != "merge_request_event" ]; then
  echo "Hors merge request : rien à vérifier."
  exit 0
fi

TARGET="${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:?}"
SOURCE="${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:?}"
IID="${CI_MERGE_REQUEST_IID:?}"

echo "MR !${IID} : ${SOURCE} → ${TARGET}"

if [ "$SOURCE" = "develop" ]; then
  if [ "$TARGET" != "main" ]; then
    echo "Erreur : develop doit fusionner vers main (cible actuelle : ${TARGET})."
    exit 1
  fi
  echo "OK : develop → main."
  exit 0
fi

if [ "$TARGET" != "develop" ]; then
  echo "Erreur : ${SOURCE} doit fusionner vers develop (cible actuelle : ${TARGET})."
  exit 1
fi

echo "OK : ${SOURCE} → develop."
