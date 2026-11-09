#!/usr/bin/env sh
# Release lancée par .github/workflows/release.yml
# quand develop est fusionné dans main par un commit de merge.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

VERSION="${PODAVIO_RELEASE_VERSION:-}"
SHA_FULL="${GITHUB_SHA:-$(git rev-parse HEAD)}"
SHA="$(printf '%s' "${SHA_FULL}" | cut -c1-7)"

fail() {
  echo "$1" >&2
  exit 1
}

changelog_version() {
  python3 - <<'PY'
from pathlib import Path
import re
text = Path("CHANGELOG.md").read_text(encoding="utf-8")
heading = re.compile(r"^[0-9]{4}\.[0-9]+\.[0-9]+$")
for line in text.splitlines():
    if not line.startswith("## "):
        continue
    title = line[3:].strip()
    if title == "Non publié":
        continue
    title = title.split(" - ", 1)[0].strip("[]")
    if heading.fullmatch(title):
        print(title)
        raise SystemExit(0)
raise SystemExit("CHANGELOG.md n'a pas de titre ## AAAA.M.N à publier. Renommez « ## Non publié » avant de fusionner develop dans main.")
PY
}

build_ids() {
  rest="${VERSION#*.}"
  month="${rest%%.*}"
  patch="${VERSION##*.}"
  year="${VERSION%%.*}"
  if [ "${month}" -lt 1 ] || [ "${month}" -gt 12 ]; then
    fail "Mois invalide dans ${VERSION}."
  fi
  if [ "${patch}" -gt 99 ]; then
    fail "Le numéro ${patch} dépasse 99."
  fi
  BUILD="$(printf '%d%02d%02d' "${year}" "${month}" "${patch}")"
}

defines() {
  printf '%s\n' \
    --build-name="${VERSION}" \
    --build-number="${BUILD}" \
    --dart-define=PODAVIO_VERSION="${VERSION}" \
    --dart-define=GITLAB_COMMIT_SHA="${SHA}"
}

case "${1:-}" in
  gate)
    if ! git rev-parse --verify -q HEAD^2 >/dev/null; then
      echo "Pas un commit de fusion. Pas de release."
      echo "release=false" >> "${GITHUB_OUTPUT:?}"
      exit 0
    fi
    git fetch origin develop
    second="$(git rev-parse HEAD^2)"
    develop="$(git rev-parse origin/develop)"
    if [ "${second}" != "${develop}" ]; then
      echo "Le second parent n'est pas develop. Pas de release."
      echo "release=false" >> "${GITHUB_OUTPUT:?}"
      exit 0
    fi
    VERSION="$(changelog_version)"
    remote="$(git ls-remote --tags origin "refs/tags/${VERSION}" | awk 'END { print $1 }')"
    if [ -n "${remote}" ] && [ "${remote}" != "${SHA_FULL}" ]; then
      if gh release view "${VERSION}" >/dev/null 2>&1; then
        echo "La release ${VERSION} est déjà publiée."
        echo "release=false" >> "${GITHUB_OUTPUT:?}"
        exit 0
      fi
      fail "Le tag ${VERSION} existe déjà et pointe vers un autre commit, sans release GitHub."
    fi
    if [ "${remote}" = "${SHA_FULL}" ]; then
      echo "Le tag ${VERSION} est déjà sur ce commit."
      echo "release=false" >> "${GITHUB_OUTPUT:?}"
      exit 0
    fi
    python3 tool/changelog.py check "${VERSION}"
    echo "release=true" >> "${GITHUB_OUTPUT:?}"
    echo "version=${VERSION}" >> "${GITHUB_OUTPUT:?}"
    echo "Release ${VERSION} pour ${SHA}."
    ;;

  keystore)
    [ -n "${ANDROID_KEYSTORE_BASE64:-}" ] || fail "Secret ANDROID_KEYSTORE_BASE64 manquant."
    [ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ] || fail "Secret ANDROID_KEYSTORE_PASSWORD manquant."
    [ -n "${ANDROID_KEY_PASSWORD:-}" ] || fail "Secret ANDROID_KEY_PASSWORD manquant."
    [ -n "${ANDROID_KEY_ALIAS:-}" ] || fail "Secret ANDROID_KEY_ALIAS manquant."
    printf '%s' "${ANDROID_KEYSTORE_BASE64}" | base64 -d > android/upload-keystore.jks
    umask 077
    cat > android/key.properties <<EOF
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyPassword=${ANDROID_KEY_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
storeFile=upload-keystore.jks
EOF
    ;;

  build-android)
    [ -n "${VERSION}" ] || fail "PODAVIO_RELEASE_VERSION manquant."
    [ -f android/key.properties ] || fail "android/key.properties manquant."
    [ -f android/upload-keystore.jks ] || fail "android/upload-keystore.jks manquant."
    build_ids
    # shellcheck disable=SC2046
    flutter build apk --release $(defines)
    # shellcheck disable=SC2046
    flutter build apk --release --split-per-abi $(defines)
    mkdir -p dist/android
    cp build/app/outputs/flutter-apk/app-release.apk \
      "dist/android/podavio-${VERSION}-android-universal.apk"
    cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk \
      "dist/android/podavio-${VERSION}-android-armeabi-v7a.apk"
    cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
      "dist/android/podavio-${VERSION}-android-arm64-v8a.apk"
    cp build/app/outputs/flutter-apk/app-x86_64-release.apk \
      "dist/android/podavio-${VERSION}-android-x86_64.apk"
    PODAVIO_STORE_PASS="$(sed -n 's/^storePassword=//p' android/key.properties | head -1)"
    export PODAVIO_STORE_PASS
    expected="$(
      keytool -list -v -keystore android/upload-keystore.jks \
        -storepass:env PODAVIO_STORE_PASS 2>/dev/null \
        | sed -n 's/^[[:space:]]*SHA256: //p' | head -1 | tr -d ':' | tr 'A-F' 'a-f'
    )"
    unset PODAVIO_STORE_PASS
    [ -n "${expected}" ] || fail "Impossible de lire l'empreinte du keystore."
    apksigner="$(find "${ANDROID_HOME:-$ANDROID_SDK_ROOT}/build-tools" -name apksigner -type f | sort | tail -1)"
    [ -n "${apksigner}" ] || fail "apksigner introuvable."
    for apk in dist/android/podavio-"${VERSION}"-android-*.apk; do
      actual="$(
        "${apksigner}" verify --print-certs "${apk}" \
          | sed -n 's/.*SHA-256 digest: //p' | head -1 | tr 'A-F' 'a-f'
      )"
      [ "${actual}" = "${expected}" ] || fail "Signature incorrecte : ${apk}"
    done
    ;;

  build-linux)
    [ -n "${VERSION}" ] || fail "PODAVIO_RELEASE_VERSION manquant."
    build_ids
    # shellcheck disable=SC2046
    flutter build linux --release $(defines)
    mkdir -p dist/linux
    bundle="dist/linux/podavio-${VERSION}-linux-x64"
    cp -a build/linux/x64/release/bundle "${bundle}"
    tar -C dist/linux -czf "${bundle}.tar.gz" "$(basename "${bundle}")"
    rm -rf "${bundle}"
    ;;

  build-windows)
    [ -n "${VERSION}" ] || fail "PODAVIO_RELEASE_VERSION manquant."
    build_ids
    flutter config --enable-windows-desktop
    # shellcheck disable=SC2046
    flutter build windows --release $(defines)
    source="$(cygpath -w "${PWD}/build/windows/x64/runner/Release")"
    year="${VERSION%%.*}"
    rest="${VERSION#*.}"
    month="${rest%%.*}"
    patch="${VERSION##*.}"
    msi_version="$(printf '%d.%s.%s' "$((year % 100))" "${month}" "${patch}")"
    dotnet tool install --global wix --version 7.0.1
    export PATH="${HOME}/.dotnet/tools:${PATH}"
    mkdir -p dist/windows
    # WiX 7 refuse de démarrer sans cet accord. En dessous de 10 000 $
    # de revenu annuel, la redevance de maintenance ne s’applique pas.
    wix build windows/installer/podavio.wxs \
      -acceptEula wix7 \
      -arch x64 \
      -d "ProductVersion=${msi_version}" \
      -d "SourceDir=${source}" \
      -o "dist/windows/podavio-${VERSION}-windows-x64.msi"
    ;;

  publish)
    [ -n "${VERSION}" ] || fail "PODAVIO_RELEASE_VERSION manquant."
    if [ -z "${GH_TOKEN:-}" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
      export GH_TOKEN="${GITHUB_TOKEN}"
    fi
    [ -n "${GH_TOKEN:-}" ] || fail "GH_TOKEN manquant."
    python3 tool/changelog.py check "${VERSION}"
    if ! git rev-parse -q --verify "refs/tags/${VERSION}" >/dev/null; then
      git -c user.name="neosis91" -c user.email="bertrand.jaunet@posteo.net" \
        tag -a "${VERSION}" -m "Podavio ${VERSION}"
    fi
    git push origin "refs/tags/${VERSION}"
    notes="$(python3 tool/changelog.py gitlab "${VERSION}")"
    if gh release view "${VERSION}" >/dev/null 2>&1; then
      echo "Release GitHub ${VERSION} déjà présente."
    else
      gh release create "${VERSION}" \
        --title "Podavio ${VERSION}" \
        --notes "${notes}" \
        "dist/android/podavio-${VERSION}-android-universal.apk#APK universel" \
        "dist/android/podavio-${VERSION}-android-armeabi-v7a.apk#APK armeabi-v7a" \
        "dist/android/podavio-${VERSION}-android-arm64-v8a.apk#APK arm64-v8a" \
        "dist/android/podavio-${VERSION}-android-x86_64.apk#APK x86_64" \
        "dist/linux/podavio-${VERSION}-linux-x64.tar.gz#Linux x64 (.tar.gz)" \
        "dist/windows/podavio-${VERSION}-windows-x64.msi#Windows x64 (.msi)"
    fi
    echo "Release ${VERSION} publiée."
    ;;

  *)
    fail "Usage : tool/ci/github_release.sh gate|keystore|build-android|build-linux|build-windows|publish"
    ;;
esac
