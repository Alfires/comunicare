#!/usr/bin/env python3
"""Host-independent, explicit Git release planning. Never pushes or installs hooks."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from transaction import publish, recover, JOURNAL

TYPES = {"feat", "fix", "docs", "test", "refactor", "build", "ci", "chore", "perf", "style", "revert"}
TITLE = re.compile(r"^(\w+)(?:\(([^()\n]+)\))?(!)?: (\S.*)$")
VERSION = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-dev\.(0|[1-9]\d*))?$")


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


def plan(base, current, preview=False, head="HEAD"):
    if not VERSION.fullmatch(current) or "-" in current:
        raise ValueError("Supply an explicit stable SemVer baseline, e.g. --current 0.1.0")
    if git("rev-parse", "--is-shallow-repository") == "true":
        raise ValueError("Full history required; deepen the repository explicitly")
    baseline = git("rev-parse", "--verify", base + "^{commit}")
    if subprocess.run(["git", "merge-base", "--is-ancestor", baseline, head]).returncode:
        raise ValueError("Baseline must be reachable from HEAD")
    commits = []
    for sha in git("rev-list", "--reverse", "--topo-order", "--no-merges", baseline + ".." + head).splitlines():
        entry = parse(git("show", "-s", "--format=%B", sha))
        entry["sha"] = sha
        commits.append(entry)
    level = max((entry["level"] for entry in commits), default=0)
    major, minor, patch = map(int, current.split("."))
    if level == 3: major, minor, patch = major + 1, 0, 0
    elif level == 2: minor, patch = minor + 1, 0
    elif level == 1: patch += 1
    version = f"{major}.{minor}.{patch}"
    if preview and level: version += f"-dev.{len(commits)}"
    notes = "\n".join(f"- {c['type']}: {c['summary']} ({c['sha'][:8]})" for c in commits if c["level"])
    return {"base": baseline, "head": git("rev-parse", head), "current": current,
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


def release_notes(result, previous):
    record = json.dumps({k: result[k] for k in ["base", "head", "current", "version"]}, sort_keys=True)
    return f"## {result['version']}\n\n<!-- release-plan {record} -->\n\n{result['notes']}\n\n" + previous


def verify_release_commit(root, version, expected_base=None):
    text = (root / "CHANGELOG.md").read_text()
    match = re.search(r"^<!-- release-plan (.+) -->$", text, re.M)
    if not match: raise ValueError("Missing release-plan record; prepare metadata before tagging")
    record = json.loads(match[1])
    if set(record) != {"base", "head", "current", "version"}: raise ValueError("Invalid release plan")
    if expected_base is not None and git("rev-parse", expected_base + "^{commit}") != record["base"]:
        raise ValueError("Requested baseline differs from the prepared release plan")
    if git("rev-list", "--parents", "-n", "1", "HEAD").split()[1:] != [record["head"]]:
        raise ValueError("Release commit must directly follow the prepared source revision")
    result = plan(record["base"], record["current"], head=record["head"])
    if result["version"] != version or record["version"] != version or not result["release"]:
        raise ValueError("Release version does not match source history")
    previous = subprocess.run(["git", "show", record["head"] + ":CHANGELOG.md"], capture_output=True, text=True)
    if text != release_notes(result, previous.stdout if previous.returncode == 0 else ""):
        raise ValueError("Release notes differ from the calculated plan")
    changed = set(git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").splitlines())
    if not changed <= {"VERSION", "CHANGELOG.md", "project.godot"}:
        raise ValueError("Release commit includes non-metadata changes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["message", "plan", "prepare", "check", "tag", "recover"])
    parser.add_argument("--base")
    parser.add_argument("--current")
    parser.add_argument("--message-file")
    parser.add_argument("--version")
    parser.add_argument("--branch", help="Explicit branch allowed to prepare/tag a release")
    parser.add_argument("--preview", action="store_true", help="Calculate a dev preview; never tag it as stable")
    args = parser.parse_args()
    try:
        if args.command == "message":
            if not args.message_file: raise ValueError("--message-file required")
            parse(Path(args.message_file).read_text())
            return 0
        root = Path(git("rev-parse", "--show-toplevel"))
        if args.command == "recover":
            recover(root)
            print("Restored original metadata from recovery journal; review git diff.")
            return 0
        if (root / JOURNAL).exists(): raise ValueError("Interrupted preparation; inspect journal and run recover")
        if args.command == "check":
            print(check_metadata(root))
            return 0
        if args.command in ["plan", "prepare"]:
            if not args.base or not args.current: raise ValueError("--base and --current are required; no implicit initial release")
            result = plan(args.base, args.current, args.preview)
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
            publish(root, {"VERSION": result["version"] + "\n", "project.godot": project,
                           "CHANGELOG.md": release_notes(result, previous)})
            print("Prepared metadata only. Review/test, then commit explicitly with chore(release).")
        elif args.command == "tag":
            version = check_metadata(root)
            if version != args.version: raise ValueError("--version must match committed metadata")
            if git("log", "-1", "--format=%s") != f"chore(release): {version}":
                raise ValueError("HEAD must be the reviewed chore(release) commit")
            if not args.base: raise ValueError("Explicit --base required for tag reachability check")
            git("merge-base", "--is-ancestor", args.base, "HEAD")
            if "-" in version: raise ValueError("Preview tags are intentionally unsupported; stable tag command only")
            verify_release_commit(root, version, args.base)
            subprocess.run(["git", "tag", "-a", f"v{version}", "-m", f"Release {version}"], check=True)
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError, IndexError) as error:
        print(f"Release check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
