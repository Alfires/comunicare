#!/usr/bin/env python3
"""Host-independent, explicit Git release planning. Never pushes or installs hooks."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

TYPES = {"feat", "fix", "docs", "test", "refactor", "build", "ci", "chore", "perf", "style", "revert"}
TITLE = re.compile(r"^(\w+)(?:\(([^()\n]+)\))?(!)?: (\S.*)$")
VERSION = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


def git(*args):
    return subprocess.check_output(["git", *args], text=True, encoding="utf-8").strip()


def parse(message):
    lines = message.splitlines()
    match = TITLE.fullmatch(lines[0] if lines else "")
    if not match or match[1] not in TYPES:
        raise ValueError("Expected Conventional Commit: type(scope): summary")
    breaking = bool(match[3]) or any(re.match(r"^BREAKING(?: CHANGE|-CHANGE):\s*\S", line) for line in lines[1:])
    level = 3 if breaking else {"feat": 2, "fix": 1, "perf": 1}.get(match[1], 0)
    return {"type": match[1], "scope": match[2], "summary": match[4], "level": level}


def plan(base, current):
    if not VERSION.fullmatch(current):
        raise ValueError("Supply an explicit stable SemVer baseline, e.g. --current 0.1.0")
    if git("rev-parse", "--is-shallow-repository") == "true":
        raise ValueError("Full history required; deepen the repository explicitly")
    baseline = git("rev-parse", "--verify", base + "^{commit}")
    if subprocess.run(["git", "merge-base", "--is-ancestor", baseline, "HEAD"]).returncode:
        raise ValueError("Baseline must be reachable from HEAD")
    commits = []
    for sha in git("rev-list", "--reverse", "--topo-order", "--no-merges", baseline + "..HEAD").splitlines():
        entry = parse(git("show", "-s", "--format=%B", sha))
        entry["sha"] = sha
        commits.append(entry)
    level = max((entry["level"] for entry in commits), default=0)
    major, minor, patch = map(int, current.split("."))
    if level == 3: major, minor, patch = major + 1, 0, 0
    elif level == 2: minor, patch = minor + 1, 0
    elif level == 1: patch += 1
    version = f"{major}.{minor}.{patch}"
    notes = "\n".join(f"- {c['type']}: {c['summary']} ({c['sha'][:8]})" for c in commits if c["level"])
    return {"base": baseline, "head": git("rev-parse", "HEAD"), "current": current,
            "version": version, "release": bool(level), "commits": commits, "notes": notes}


def check_metadata(root):
    version = (root / "VERSION").read_text().strip()
    if not VERSION.fullmatch(version): raise ValueError("VERSION must be stable SemVer")
    project = (root / "project.godot").read_text()
    application = project.split("[application]", 1)[1].split("\n[", 1)[0]
    if f'config/version="{version}"' not in application:
        raise ValueError("VERSION and application config/version differ")
    if f"## {version}\n" not in (root / "CHANGELOG.md").read_text():
        raise ValueError("CHANGELOG has no matching version heading")
    return version


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["message", "plan", "prepare", "check", "tag"])
    parser.add_argument("--base")
    parser.add_argument("--current")
    parser.add_argument("--message-file")
    parser.add_argument("--version")
    parser.add_argument("--branch", help="Explicit branch allowed to prepare/tag a release")
    args = parser.parse_args()
    try:
        if args.command == "message":
            if not args.message_file: raise ValueError("--message-file required")
            parse(Path(args.message_file).read_text())
            return 0
        root = Path(git("rev-parse", "--show-toplevel"))
        if args.command == "check":
            print(check_metadata(root))
            return 0
        if args.command in ["plan", "prepare"]:
            if not args.base or not args.current: raise ValueError("--base and --current are required; no implicit initial release")
            result = plan(args.base, args.current)
            if args.command == "plan":
                print(json.dumps(result, indent=2))
                return 0
        if not args.branch or git("branch", "--show-current") != args.branch:
            raise ValueError("Explicit matching --branch required for mutations")
        if git("status", "--porcelain"):
            raise ValueError("Clean working tree required (including untracked files)")
        if args.command == "prepare":
            if not result["release"]: raise ValueError("No releasable commits")
            project_path = root / "project.godot"
            project = project_path.read_text()
            before, rest = project.split("[application]", 1)
            application, separator, after = rest.partition("\n[")
            application = re.sub(r'^config/version=.*\n?', '', application, flags=re.M)
            project = before + '[application]\nconfig/version="' + result["version"] + '"\n' + application + separator + after
            changelog = root / "CHANGELOG.md"
            previous = changelog.read_text() if changelog.exists() else ""
            # No commits/tags/pushes here. Review the complete diff before committing.
            (root / "VERSION").write_text(result["version"] + "\n")
            project_path.write_text(project)
            changelog.write_text(f"## {result['version']}\n\n{result['notes']}\n\n" + previous)
            print("Prepared metadata only. Review/test, then commit explicitly with chore(release).")
        elif args.command == "tag":
            version = check_metadata(root)
            if version != args.version: raise ValueError("--version must match committed metadata")
            if git("log", "-1", "--format=%s") != f"chore(release): {version}":
                raise ValueError("HEAD must be the reviewed chore(release) commit")
            if not args.base: raise ValueError("Explicit --base required for tag reachability check")
            git("merge-base", "--is-ancestor", args.base, "HEAD")
            subprocess.run(["git", "tag", "-a", f"v{version}", "-m", f"Release {version}"], check=True)
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError, IndexError) as error:
        print(f"Release check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
