#!/usr/bin/env python3
"""Lit CHANGELOG.md pour les notes de version.

Le journal de podavio.com lit CHANGELOG.md sur GitHub. Cette commande
ne réécrit plus cette page.
"""

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / "CHANGELOG.md"
VERSION_RE = re.compile(r"^[0-9]{4}\.[0-9]+\.[0-9]+$")
HEADING_RE = re.compile(
    r"^\[?([0-9]{4}\.[0-9]+\.[0-9]+)\]?(?:\s+-\s+[0-9]{4}-[0-9]{2}-[0-9]{2})?$"
)
BULLET_RE = re.compile(r"^[-*]\s+(\S.*)$")
DATE_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")


def fail(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)


def parse(text):
    releases = []
    seen = set()
    current = None
    notes = []

    def flush():
        if current is None:
            return
        if current in seen:
            fail(f"CHANGELOG.md : {current} est en double.")
        seen.add(current)
        releases.append((current, list(notes)))

    for line in text.splitlines():
        if line.startswith("## "):
            flush()
            notes = []
            title = line[3:].strip()
            if title == "Non publié":
                current = None
                continue
            match = HEADING_RE.fullmatch(title)
            if not match:
                fail(f"CHANGELOG.md : titre invalide « {title} ».")
            current = match.group(1)
            continue
        if current is None and not releases:
            continue
        if not line.strip():
            continue
        bullet = BULLET_RE.fullmatch(line.strip())
        if not bullet:
            where = current or "Non publié"
            fail(f"CHANGELOG.md ({where}) : ligne sans puce « {line.strip()} ».")
        if current is not None:
            notes.append(bullet.group(1).strip())
    flush()
    return releases


def load():
    if not CHANGELOG.is_file():
        fail(f"Fichier manquant : {CHANGELOG}")
    return parse(CHANGELOG.read_text(encoding="utf-8"))


def notes_for(version):
    if not VERSION_RE.fullmatch(version):
        fail(f"Version invalide : {version}")
    releases = dict(load())
    if version not in releases:
        fail(
            f"CHANGELOG.md n'a pas de titre ## {version}. "
            "Renommez « ## Non publié » en ce titre, avec une puce par changement."
        )
    notes = releases[version]
    if not notes:
        fail(f"CHANGELOG.md : ## {version} n'a aucune puce.")
    return notes


def publish(version, date, site):
    if not DATE_RE.fullmatch(date):
        fail(f"Date invalide : {date}")
    notes = notes_for(version)
    site = Path(site)
    latest = {
        "version": version,
        "date": date,
        "notes": notes,
        "files": {
            "android-arm64-v8a": f"releases/{version}/podavio-{version}-android-arm64-v8a.apk",
            "android-armeabi-v7a": f"releases/{version}/podavio-{version}-android-armeabi-v7a.apk",
            "android-x86_64": f"releases/{version}/podavio-{version}-android-x86_64.apk",
            "android-universal": f"releases/{version}/podavio-{version}-android-universal.apk",
            "linux-x64": f"releases/{version}/podavio-{version}-linux-x64.tar.gz",
            "linux-amd64": f"releases/{version}/podavio-{version}-linux-amd64.deb",
        },
    }
    (site / "latest.json").write_text(
        json.dumps(latest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser(description="Journal des versions Podavio.")
    sub = parser.add_subparsers(dest="command", required=True)

    check = sub.add_parser("check")
    check.add_argument("version")

    gitlab = sub.add_parser("gitlab")
    gitlab.add_argument("version")

    published = sub.add_parser("publish")
    published.add_argument("--version", required=True)
    published.add_argument("--date", required=True)
    published.add_argument("--site", required=True)

    args = parser.parse_args()
    if args.command == "check":
        notes_for(args.version)
        return
    if args.command == "gitlab":
        print("\n".join(f"- {note}" for note in notes_for(args.version)))
        return
    publish(args.version, args.date, args.site)


if __name__ == "__main__":
    main()
