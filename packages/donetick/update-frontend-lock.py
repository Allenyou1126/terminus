#!/usr/bin/env python3
"""Fill in missing `resolved`/`integrity` fields in an npm package-lock.json.

nixpkgs' prefetch-npm-deps only caches packages that have a `resolved` URL, so
any entry without one is dropped from the dependency cache and the offline
`npm ci` inside buildNpmPackage fails with ENOTCACHED. Some upstream projects
(for example donetick/frontend v1.2.78) ship a lockfile generated from an
existing node_modules tree, where 907 of 1385 entries have neither `resolved`
nor `integrity`.

The script resolves the exact locked version through the registry packument and
adds the tarball URL plus its integrity, leaving every version untouched. Its
output is what `frontend.nix` installs over the upstream lockfile.

Usage:
    ./update-frontend-lock.py <upstream package-lock.json> <output.json>
"""

import json
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

REGISTRY = "https://registry.npmjs.org"

lock_in, lock_out = sys.argv[1], sys.argv[2]

with open(lock_in) as f:
    lock = json.load(f)

packages = lock["packages"]


def package_name(key: str, entry: dict) -> str:
    # Aliases (e.g. `"string-width-cjs": "npm:string-width@^4.2.3"`) record the
    # real package name in the entry, nested entries are addressed by their
    # `node_modules/...` suffix.
    if "name" in entry:
        return entry["name"]
    return key.rsplit("node_modules/", 1)[-1]


def needs_fix(entry: dict) -> bool:
    return (
        "resolved" not in entry
        and "link" not in entry
        and "extraneous" not in entry
        and "version" in entry
    )


targets = {
    key: entry
    for key, entry in packages.items()
    if key.startswith("node_modules/") and needs_fix(entry)
}
print(f"entries needing resolved: {len(targets)}")

by_name: dict[str, list[tuple[str, dict]]] = {}
for key, entry in targets.items():
    by_name.setdefault(package_name(key, entry), []).append((key, entry))

print(f"distinct package names: {len(by_name)}")


def fetch_packument(name: str) -> dict | None:
    url = f"{REGISTRY}/{urllib.parse.quote(name, safe='@')}"
    error: Exception | None = None
    for _ in range(4):
        try:
            request = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except Exception as exc:  # noqa: BLE001 - report and retry
            error = exc
    print(f"WARN: packument failed for {name}: {error}", file=sys.stderr)
    return None


solved = 0
unsolved: list[str] = []
with ThreadPoolExecutor(max_workers=16) as pool:
    for name, packument in zip(by_name, pool.map(fetch_packument, by_name)):
        if packument is None:
            unsolved.extend(key for key, _ in by_name[name])
            continue
        versions = packument.get("versions", {})
        for key, entry in by_name[name]:
            info = versions.get(entry["version"])
            if not info or "dist" not in info:
                unsolved.append(key)
                continue
            dist = info["dist"]
            entry["resolved"] = dist["tarball"]
            if "integrity" in dist:
                entry["integrity"] = dist["integrity"]
            solved += 1

print(f"filled: {solved}, unsolved: {len(unsolved)}")
for key in unsolved[:30]:
    print(f"  UNSOLVED {key} {packages[key].get('version')}", file=sys.stderr)

remaining = [key for key in targets if needs_fix(packages[key])]
if remaining:
    print(f"still missing resolved: {len(remaining)}", file=sys.stderr)
    sys.exit(1)

with open(lock_out, "w") as f:
    json.dump(lock, f, indent=2)
    f.write("\n")
print(f"wrote {lock_out}")
