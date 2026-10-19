#!/usr/bin/env python3
"""Lit CHANGELOG.md et prépare le journal publié sur podavio.com."""

import argparse
import html
import json
import re
import subprocess
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
START = "<!-- journal:start -->"
END = "<!-- journal:end -->"
MONTHS = (
    "janvier",
    "février",
    "mars",
    "avril",
    "mai",
    "juin",
    "juillet",
    "août",
    "septembre",
    "octobre",
    "novembre",
    "décembre",
)


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


def french_date(iso):
    year, month, day = (int(part) for part in iso.split("-"))
    return f"{day} {MONTHS[month - 1]} {year}"


def article(version, date, notes):
    lines = ["    <article>", "      <header>", f"        <h2>{html.escape(version)}</h2>"]
    if date:
        lines.append(
            f'        <time datetime="{date}">{html.escape(french_date(date))}</time>'
        )
    lines.append("      </header>")
    lines.append("      <ul>")
    for note in notes:
        lines.append(f"        <li>{html.escape(note)}</li>")
    lines.append("      </ul>")
    lines.append("    </article>")
    return "\n".join(lines)


def publish(version, date, site):
    if not DATE_RE.fullmatch(date):
        fail(f"Date invalide : {date}")
    notes_for(version)
    site = Path(site)
    journal = site / "journal" / "index.html"
    changelog_path = site / "changelog.json"
    if not journal.is_file():
        fail(f"Page manquante : {journal}")
    page = journal.read_text(encoding="utf-8")
    if START not in page or END not in page:
        fail(f"{journal} n'a pas les balises {START} et {END}.")

    previous_dates = {}
    if changelog_path.is_file():
        previous = json.loads(changelog_path.read_text(encoding="utf-8"))
        for item in previous.get("releases", []):
            previous_dates[item["version"]] = item.get("date") or ""

    releases = []
    for found, notes in load():
        if not notes:
            continue
        releases.append(
            {
                "version": found,
                "date": date if found == version else previous_dates.get(found, ""),
                "notes": notes,
            }
        )

    changelog_path.write_text(
        json.dumps({"releases": releases}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    body = "\n".join(article(item["version"], item["date"], item["notes"]) for item in releases)
    pre, rest = page.split(START, 1)
    _, post = rest.split(END, 1)
    journal.write_text(f"{pre}{START}\n{body}\n{END}{post}", encoding="utf-8")

    current = next(item for item in releases if item["version"] == version)
    latest = {
        "version": version,
        "date": date,
        "notes": current["notes"],
        "files": {
            "android-arm64-v8a": f"releases/{version}/podavio-{version}-android-arm64-v8a.apk",
            "android-armeabi-v7a": f"releases/{version}/podavio-{version}-android-armeabi-v7a.apk",
            "android-x86_64": f"releases/{version}/podavio-{version}-android-x86_64.apk",
            "android-universal": f"releases/{version}/podavio-{version}-android-universal.apk",
            "linux-x64": f"releases/{version}/podavio-{version}-linux-x64.tar.gz",
        },
    }
    (site / "latest.json").write_text(
        json.dumps(latest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    builder = Path(site) / "tool" / "build_pages.py"
    if builder.is_file():
        subprocess.run([sys.executable, str(builder)], check=True)


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
