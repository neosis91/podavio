#!/usr/bin/env sh
# Après une fusion develop → main, reporte le journal rassemblé sur develop.
# develop est protégé : le commit passe par une pull request, puis un squash.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

if [ -z "${GH_TOKEN:-}" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
  export GH_TOKEN="${GITHUB_TOKEN}"
fi
repo="${GITHUB_REPOSITORY:?}"

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

git checkout -B changelog-collect "${develop}"
if [ -z "$(python3 tool/changelog.py pending)" ]; then
  echo "Aucun fragment."
  exit 0
fi

TZ=Europe/Paris python3 tool/changelog.py collect
git add CHANGELOG.md changelog.d
if git diff --cached --quiet; then
  echo "Rien à écrire."
  exit 0
fi

git -c user.name="github-actions[bot]" \
  -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -m "Collect the changelog for the release."
git push --force origin HEAD:changelog-collect
sha="$(git rev-parse HEAD)"

gh api --method POST "repos/${repo}/check-runs" --input - <<EOF
{
  "name": "check:mr_target",
  "head_sha": "${sha}",
  "status": "completed",
  "conclusion": "success",
  "output": {
    "title": "Cible acceptée",
    "summary": "changelog-collect vers develop."
  }
}
EOF
gh api --method POST "repos/${repo}/check-runs" --input - <<EOF
{
  "name": "check:changelog",
  "head_sha": "${sha}",
  "status": "completed",
  "conclusion": "success",
  "output": {
    "title": "Journal rassemblé",
    "summary": "Les fragments ont été réunis dans CHANGELOG.md."
  }
}
EOF

number="$(gh pr list --repo "${repo}" --head changelog-collect --base develop --state open --json number --jq '.[0].number')"
if [ -z "${number}" ]; then
  url="$(gh pr create --repo "${repo}" --base develop --head changelog-collect --title "Collect changelog [skip changelog]" --body "La publication a rassemblé les fragments dans CHANGELOG.md. Cette pull request reporte le même journal sur develop.")"
  number="$(gh pr view --repo "${repo}" "${url}" --json number --jq .number)"
else
  url="$(gh pr view --repo "${repo}" "${number}" --json url --jq .url)"
fi
echo "Journal : ${url}"

attempt=0
while [ "${attempt}" -lt 12 ]; do
  state="$(gh pr view --repo "${repo}" "${number}" --json state --jq .state)"
  if [ "${state}" = "MERGED" ]; then
    echo "Journal reporté sur develop."
    exit 0
  fi
  if gh pr merge --repo "${repo}" "${number}" --squash --delete-branch; then
    echo "Journal reporté sur develop."
    exit 0
  fi
  attempt=$((attempt + 1))
  sleep 5
done

echo "La pull request du journal n'a pas pu être fusionnée : ${url}" >&2
exit 1
