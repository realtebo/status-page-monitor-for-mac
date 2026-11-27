"""Print the release version for HEAD, reusing its tag on a workflow retry."""

import re
import subprocess


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def versions(*args):
    return [
        tag[1:] for tag in git("tag", "--list", *args).splitlines()
        if re.fullmatch(r"v[0-9]+\.[0-9]+(?:\.[0-9]+)?", tag)
    ]


def parts(version):
    major, minor, *patch = map(int, version.split("."))
    return major, minor, patch[0] if patch else 0


def next_version():
    existing = versions("--points-at", "HEAD")
    if len(existing) == 1:
        return existing[0]
    if existing:
        raise SystemExit("Multiple release versions point to HEAD.")
    tags = versions()
    if not tags:
        raise SystemExit("A previous release tag is required.")
    major, minor, patch = parts(max(tags, key=parts))
    bump = git("log", "-1", "--format=%(trailers:key=Release-Bump,valueonly)")
    if bump == "patch":
        return f"{major}.{minor:02}.{patch + 1}"
    if bump == "major":
        return f"{major + 1}.00"
    if bump in ("", "minor"):
        return f"{major}.{minor + 1:02}"
    raise SystemExit(f"Invalid Release-Bump trailer: {bump!r}")


if __name__ == "__main__":
    print(next_version())
