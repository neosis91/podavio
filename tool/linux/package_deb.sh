#!/bin/sh
# Construit un paquet Debian à partir du bundle Flutter Linux.
# Usage : tool/linux/package_deb.sh VERSION RÉPERTOIRE_BUNDLE FICHIER.deb
set -eu

if [ "$#" -ne 3 ]; then
  echo "Usage : tool/linux/package_deb.sh VERSION RÉPERTOIRE_BUNDLE FICHIER.deb" >&2
  exit 1
fi

VERSION="$1"
BUNDLE="$2"
OUTPUT="$3"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 manquant." >&2
  exit 1
fi
if [ ! -x "${BUNDLE}/podavio" ]; then
  echo "Bundle Linux introuvable : ${BUNDLE}/podavio" >&2
  exit 1
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/podavio-deb.XXXXXX")"
cleanup() {
  rm -rf "${work}"
}
trap cleanup EXIT

root="${work}/root"
mkdir -p \
  "${root}/usr/lib/podavio" \
  "${root}/usr/bin" \
  "${root}/usr/share/applications" \
  "${root}/usr/share/icons/hicolor/scalable/apps" \
  "${root}/usr/share/doc/podavio" \
  "${root}/DEBIAN"

cp -a "${BUNDLE}/." "${root}/usr/lib/podavio/"
chmod 755 "${root}/usr/lib/podavio/podavio"

cat > "${root}/usr/bin/podavio" <<'EOF'
#!/bin/sh
exec /usr/lib/podavio/podavio "$@"
EOF
chmod 755 "${root}/usr/bin/podavio"

desktop="${root}/usr/lib/podavio/share/applications/fr.podavio.podavio.desktop"
icon="${root}/usr/lib/podavio/share/icons/hicolor/scalable/apps/fr.podavio.podavio.svg"
if [ ! -f "${desktop}" ] || [ ! -f "${icon}" ]; then
  echo "Le bundle n'a pas le fichier .desktop ou l'icône." >&2
  exit 1
fi
cp "${desktop}" "${root}/usr/share/applications/fr.podavio.podavio.desktop"
cp "${icon}" "${root}/usr/share/icons/hicolor/scalable/apps/fr.podavio.podavio.svg"

cat > "${root}/usr/share/doc/podavio/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: Podavio
Upstream-Contact: neosis91 <bertrand.jaunet@posteo.net>
Source: https://github.com/neosis91/podavio

Files: *
Copyright: 2026 neosis91
License: GPL-3.0-only
 The full license is at https://github.com/neosis91/podavio/blob/main/LICENSE
 and, on Debian systems, in /usr/share/common-licenses/GPL-3.
EOF

size="$(du -sk "${root}" | awk '{ print $1 }')"
cat > "${root}/DEBIAN/control" <<EOF
Package: podavio
Version: ${VERSION}
Section: sound
Priority: optional
Architecture: amd64
Maintainer: neosis91 <bertrand.jaunet@posteo.net>
Homepage: https://podavio.com
Installed-Size: ${size}
Depends: libgtk-3-0t64 | libgtk-3-0, libepoxy0, libfontconfig1, libsecret-1-0, libcurl4t64 | libcurl4, libmpv2 | libmpv1, zlib1g, libc6
Description: Lecteur de podcasts
 Podavio lit des podcasts depuis un flux RSS, télécharge les épisodes
 et les joue sans réseau.
EOF

chmod 644 \
  "${root}/DEBIAN/control" \
  "${root}/usr/share/doc/podavio/copyright" \
  "${root}/usr/share/applications/fr.podavio.podavio.desktop" \
  "${root}/usr/share/icons/hicolor/scalable/apps/fr.podavio.podavio.svg"

mkdir -p "$(dirname "${OUTPUT}")"
ROOT="${root}" OUTPUT="${OUTPUT}" python3 - <<'PY'
import io
import os
import pathlib
import stat
import tarfile

root = pathlib.Path(os.environ["ROOT"])
output = pathlib.Path(os.environ["OUTPUT"])

def member(path, mode, data=None, link=None):
    info = tarfile.TarInfo(path)
    info.mode = mode
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mtime = 0
    if link is not None:
        info.type = tarfile.SYMTYPE
        info.linkname = link
    elif data is None:
        info.type = tarfile.DIRTYPE
    else:
        info.type = tarfile.REGTYPE
        info.size = len(data)
    return info

def pack(entries):
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:xz", format=tarfile.GNU_FORMAT) as archive:
        for info, data in entries:
            archive.addfile(info, None if data is None else io.BytesIO(data))
    return buffer.getvalue()

def tree(base, skip=None):
    entries = []
    seen = set()
    for current, dirs, files in os.walk(base):
        current = pathlib.Path(current)
        relative = current.relative_to(base)
        if relative.parts[:1] == (skip,):
            dirs.clear()
            continue
        arc = "." if relative == pathlib.Path(".") else "./" + relative.as_posix()
        if arc not in seen:
            entries.append((member(arc, 0o755), None))
            seen.add(arc)
        for name in sorted(dirs):
            path = current / name
            rel = path.relative_to(base)
            if rel.parts[:1] == (skip,):
                continue
            directory = "./" + rel.as_posix()
            if directory not in seen:
                entries.append((member(directory, 0o755), None))
                seen.add(directory)
        for name in sorted(files):
            path = current / name
            rel = "./" + path.relative_to(base).as_posix()
            mode = path.stat().st_mode
            if stat.S_ISLNK(mode):
                entries.append((member(rel, 0o777, link=os.readlink(path)), None))
            else:
                bits = 0o755 if mode & stat.S_IXUSR else 0o644
                entries.append((member(rel, bits, data=path.read_bytes()), path.read_bytes()))
    return entries

control = (root / "DEBIAN" / "control").read_bytes()
if not control.endswith(b"\n"):
    control += b"\n"
control_tar = pack([
    (member(".", 0o755), None),
    (member("./control", 0o644, data=control), control),
])
data_tar = pack(tree(root, skip="DEBIAN"))

def ar_entry(name, payload):
    header = (
        f"{name:<16}{0:<12}{0:<6}{0:<6}{0o100644:<8o}{len(payload):<10}`\n"
    ).encode("ascii")
    if len(header) != 60:
        raise SystemExit(f"en-tête ar invalide pour {name}")
    pad = b"\n" if len(payload) % 2 else b""
    return header + payload + pad

debian_binary = b"2.0\n"
blob = b"!<arch>\n" + ar_entry("debian-binary", debian_binary) + ar_entry(
    "control.tar.xz", control_tar
) + ar_entry("data.tar.xz", data_tar)
output.write_bytes(blob)
PY
echo "Paquet ${OUTPUT}"
