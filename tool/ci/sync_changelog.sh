#!/usr/bin/env sh
# Après une fusion develop → main, rassemble les fragments encore présents.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

if ! git rev-parse --verify -q HEAD^2 >/dev/null; then
  echo "Pas un commit de fusion."
  exit 0
fi

git fetch origin develop
second="$(git rev-parse HEAD^2)"
develop="$(git rev-parse origin/develop)"
if [ "${develop}" != "${second}" ]; then
  if ! git diff --quiet "${second}" "${develop}" -- CHANGELOG.md changelog.d; then
    echo "develop a changé le journal depuis la fusion. Les fragments restent pour la prochaine publication."
    exit 0
  fi
fi

tool/ci/collect_develop.sh
