#!/usr/bin/env python3
"""Journal des versions.

Chaque changement visible ajoute un fichier changelog.d/*.md.
`collect` rassemble ces fichiers sous un titre ## AAAA.M.N.
"""

import argparse
import datetime as dt
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / "CHANGELOG.md"
FRAGMENTS = ROOT / "changelog.d"
VERSION_RE = re.compile(r"^[0-9]{4}\.[0-9]+\.[0-9]+$")
HEADING_RE = re.compile(
    r"^\[?([0-9]{4}\.[0-9]+\.[0-9]+)\]?(?:\s+-\s+[0-9]{4}-[0-9]{2}-[0-9]{2})?$"
)
BULLET_RE = re.compile(r"^[-*]\s+(\S.*)$")
FRAGMENT_RE = re.compile(r"^[a-z0-9][a-z0-9-]*\.md$")
SKIP = "[skip changelog]"


def fail(message):
    raise SystemExit(message)


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


def load(path=CHANGELOG):
    if not path.is_file():
        fail(f"Fichier manquant : {path}")
    return parse(path.read_text(encoding="utf-8"))


def notes_for(version, path=CHANGELOG):
    if not VERSION_RE.fullmatch(version):
        fail(f"Version invalide : {version}")
    releases = dict(load(path))
    if version not in releases:
        fail(f"CHANGELOG.md n'a pas de titre ## {version}.")
    notes = releases[version]
    if not notes:
        fail(f"CHANGELOG.md : ## {version} n'a aucune puce.")
    return notes


def fragment_paths(directory=FRAGMENTS):
    if not directory.is_dir():
        return []
    paths = []
    for path in sorted(directory.iterdir()):
        if not path.is_file() or path.name in ("README.md", ".gitkeep"):
            continue
        if not FRAGMENT_RE.fullmatch(path.name):
            fail(
                f"{path.name} : nom invalide. "
                "Utilisez des minuscules et des tirets, par exemple ecoute.md."
            )
        paths.append(path)
    return paths


def read_fragment(path):
    text = re.sub(r"\s+", " ", path.read_text(encoding="utf-8")).strip()
    if text.startswith("- "):
        text = text[2:].strip()
    if not text:
        fail(f"{path.name} est vide.")
    return text


def version_parts(version):
    year, month, patch = (int(part) for part in version.split("."))
    return year, month, patch


def next_version(releases, today, top_released):
    if releases and not top_released:
        return releases[0][0]
    year, month = today.year, today.month
    if releases:
        last_year, last_month, last_patch = version_parts(releases[0][0])
        if last_year == year and last_month == month:
            patch = last_patch + 1
            if patch > 99:
                fail(f"Le numéro {patch} dépasse 99.")
            return f"{year}.{month}.{patch}"
    return f"{year}.{month}.0"


def tag_exists(version, root=ROOT):
    result = subprocess.run(
        ["git", "rev-parse", "-q", "--verify", f"refs/tags/{version}"],
        cwd=root,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def render_section(version, notes):
    lines = [f"## {version}", ""]
    lines.extend(f"- {note}" for note in notes)
    return "\n".join(lines) + "\n\n"


def release_notes(text):
    notes = []
    for line in text.splitlines():
        bullet = BULLET_RE.fullmatch(line.strip())
        if bullet:
            notes.append(bullet.group(1).strip())
    return notes


def rewrite_section(path, version, notes):
    lines = path.read_text(encoding="utf-8").splitlines()
    start = None
    for index, line in enumerate(lines):
        if line == f"## {version}":
            start = index
            break
    if start is None:
        fail(f"CHANGELOG.md n'a pas de titre ## {version}.")
    end = len(lines)
    for index in range(start + 1, len(lines)):
        if lines[index].startswith("## "):
            end = index
            break
    block = [f"## {version}", ""]
    block.extend(f"- {note}" for note in notes)
    block.append("")
    lines[start:end] = block
    path.write_text("\n".join(lines).rstrip("\n") + "\n", encoding="utf-8")


def carry_unpublished(path, published_text, today=None):
    """Move notes absent from an already published release into the next version."""
    today = today or dt.date.today()
    releases = load(path)
    if not releases:
        return None
    version, notes = releases[0]
    published = release_notes(published_text)
    if not published:
        return None
    fresh = [note for note in notes if note not in set(published)]
    if not fresh:
        return None
    kept = [note for note in notes if note in set(published)]
    rewrite_section(path, version, kept)
    new_version = next_version([(version, kept)], today, True)
    write_release(path, new_version, fresh, False)
    print(f"## {new_version} : {len(fresh)} puce(s).")
    return new_version


def write_release(path, version, notes, append):
    text = path.read_text(encoding="utf-8")
    if not text.endswith("\n"):
        text += "\n"
    if not append:
        marker = text.find("\n## ")
        if marker == -1:
            updated = text + "\n" + render_section(version, notes)
        else:
            updated = text[: marker + 1] + render_section(version, notes) + text[marker + 1 :]
        path.write_text(updated, encoding="utf-8")
        return
    lines = text.splitlines()
    start = None
    for index, line in enumerate(lines):
        if line == f"## {version}":
            start = index
            break
    if start is None:
        fail(f"CHANGELOG.md n'a pas de titre ## {version}.")
    end = len(lines)
    for index in range(start + 1, len(lines)):
        if lines[index].startswith("## "):
            end = index
            break
    existing = []
    for line in lines[start + 1 : end]:
        bullet = BULLET_RE.fullmatch(line.strip())
        if bullet:
            existing.append(bullet.group(1).strip())
    fresh = [note for note in notes if note not in existing]
    if not fresh:
        return
    block = [f"- {note}" for note in fresh]
    insert_at = end
    while insert_at > start + 1 and lines[insert_at - 1] == "":
        insert_at -= 1
    lines[insert_at:insert_at] = ["", *block, ""]
    path.write_text("\n".join(lines).rstrip("\n") + "\n", encoding="utf-8")


def collect(path=CHANGELOG, directory=FRAGMENTS, today=None, released=None, root=ROOT):
    today = today or dt.date.today()
    paths = fragment_paths(directory)
    if not paths:
        print("Aucun fragment.")
        return None
    notes = [read_fragment(path) for path in paths]
    releases = load(path)
    if released is None:
        released = (lambda version: tag_exists(version, root))
    top_released = bool(releases) and released(releases[0][0])
    version = next_version(releases, today, top_released)
    append = bool(releases) and releases[0][0] == version
    write_release(path, version, notes, append)
    for fragment in paths:
        fragment.unlink()
    print(f"## {version} : {len(notes)} puce(s).")
    return version


def skipped(title, labels, commits):
    if SKIP in title.lower():
        return True
    if "skip-changelog" in {label.strip().lower() for label in labels}:
        return True
    return SKIP in commits.lower()


def check_pr(base, title="", labels=None, root=ROOT):
    labels = labels or []
    diff = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=A", f"{base}...HEAD"],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if diff.returncode != 0:
        fail(diff.stderr.strip() or f"git diff {base}...HEAD a échoué.")
    added = [
        line
        for line in diff.stdout.splitlines()
        if line.startswith("changelog.d/") and FRAGMENT_RE.fullmatch(Path(line).name)
    ]
    if added:
        print(f"Fragments : {', '.join(added)}.")
        return
    log = subprocess.run(
        ["git", "log", "--format=%s%n%b", f"{base}...HEAD"],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if log.returncode != 0:
        fail(log.stderr.strip() or "git log a échoué.")
    if skipped(title, labels, log.stdout):
        print("Pas de fragment : skip changelog.")
        return
    fail(
        "Cette pull request n'ajoute pas de fichier changelog.d/*.md. "
        "Décrivez le changement en anglais dans un fragment, "
        "ou ajoutez [skip changelog] au titre s'il n'est pas visible."
    )


def check_release(directory=FRAGMENTS):
    paths = fragment_paths(directory)
    if not paths:
        print("Journal déjà rassemblé.")
        return
    names = ", ".join(path.name for path in paths)
    print(
        f"Fragments présents ({names}). "
        "Ils seront rassemblés quand cette pull request sera fusionnée dans develop."
    )


def main():
    parser = argparse.ArgumentParser(description="Journal des versions Podavio.")
    sub = parser.add_subparsers(dest="command", required=True)

    check = sub.add_parser("check")
    check.add_argument("version")

    notes = sub.add_parser("notes")
    notes.add_argument("version")

    sub.add_parser("collect")
    sub.add_parser("pending")
    sub.add_parser("top")
    carry = sub.add_parser("carry")
    carry.add_argument("published", type=Path)

    pr = sub.add_parser("check-pr")
    pr.add_argument("--base", required=True)
    pr.add_argument("--title", default="")
    pr.add_argument("--labels", default="")

    sub.add_parser("check-release")

    args = parser.parse_args()
    if args.command == "check":
        notes_for(args.version)
        return
    if args.command == "notes":
        print("\n".join(f"- {note}" for note in notes_for(args.version)))
        return
    if args.command == "collect":
        collect()
        return
    if args.command == "pending":
        for path in fragment_paths():
            print(path.name)
        return
    if args.command == "top":
        releases = load()
        if releases:
            print(releases[0][0])
        return
    if args.command == "carry":
        carry_unpublished(CHANGELOG, args.published.read_text(encoding="utf-8"))
        return
    if args.command == "check-pr":
        labels = [label for label in args.labels.split(",") if label.strip()]
        check_pr(args.base, args.title, labels)
        return
    check_release()


if __name__ == "__main__":
    main()
