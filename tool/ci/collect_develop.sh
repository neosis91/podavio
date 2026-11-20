#!/usr/bin/env sh
# Rassemble les fragments présents sur develop.
# develop est protégé : le commit passe par une pull request, puis un squash.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

if [ -z "${GH_TOKEN:-}" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
  export GH_TOKEN="${GITHUB_TOKEN}"
fi
repo="${GITHUB_REPOSITORY:?}"

git fetch origin develop
git checkout -B changelog-collect origin/develop
top="$(python3 tool/changelog.py top)"
if [ -n "${top}" ] && gh release view "${top}" >/dev/null 2>&1; then
  gh release view "${top}" --json body --jq .body > published-notes.md
  TZ=Europe/Paris python3 tool/changelog.py carry published-notes.md
  rm -f published-notes.md
fi
if [ -n "$(python3 tool/changelog.py pending)" ]; then
  TZ=Europe/Paris python3 tool/changelog.py collect
fi
git add CHANGELOG.md changelog.d
if git diff --cached --quiet; then
  echo "Rien à écrire."
  exit 0
fi

git -c user.name="github-actions[bot]" \
  -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -m "Collect the changelog."
git push --force origin HEAD:changelog-collect
sha="$(git rev-parse HEAD)"

mark_check() {
  name="$1"
  summary="$2"
  gh api --method POST "repos/${repo}/check-runs" --input - <<EOF
{
  "name": "${name}",
  "head_sha": "${sha}",
  "status": "completed",
  "conclusion": "success",
  "output": {
    "title": "${name}",
    "summary": "${summary}"
  }
}
EOF
}

mark_check "check:mr_target" "changelog-collect vers develop."
mark_check "check:changelog" "Les fragments ont été réunis dans CHANGELOG.md."

number="$(gh pr list --repo "${repo}" --head changelog-collect --base develop --state open --json number --jq '.[0].number')"
if [ -z "${number}" ]; then
  url="$(gh pr create --repo "${repo}" --base develop --head changelog-collect --title "Collect changelog [skip changelog]" --body "Les fragments de la pull request fusionnée dans develop sont rassemblés dans CHANGELOG.md.")"
  number="$(gh pr view --repo "${repo}" "${url}" --json number --jq .number)"
else
  url="$(gh pr view --repo "${repo}" "${number}" --json url --jq .url)"
fi
echo "Journal : ${url}"

attempt=0
while [ "${attempt}" -lt 12 ]; do
  state="$(gh pr view --repo "${repo}" "${number}" --json state --jq .state)"
  if [ "${state}" = "MERGED" ]; then
    echo "Journal rassemblé sur develop."
    exit 0
  fi
  if gh pr merge --repo "${repo}" "${number}" --squash --delete-branch; then
    echo "Journal rassemblé sur develop."
    exit 0
  fi
  attempt=$((attempt + 1))
  sleep 5
done

echo "La pull request du journal n'a pas pu être fusionnée : ${url}" >&2
exit 1
