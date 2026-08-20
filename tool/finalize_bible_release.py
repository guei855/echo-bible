#!/usr/bin/env python3
"""Verify published Bible assets and atomically finalize resources_manifest.json."""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import tempfile
import urllib.request
from pathlib import Path


EXPECTED = {
    "darby": (5574656, "e69c1cfc2e955966f5da3ddb294c05631e023da6eabbfa9785e2205bc4b8e66b"),
    "ostervald": (5406720, "8217c359ea427c9a976dae62e0e11d3c0d5d70079d748b9203367b7912e9bff9"),
    "neo_crampon": (5509120, "35cc527276531fd49f124a59810b5fc0ec29d254a22cd58cb3f8580b9ed8f0ec"),
    "martin": (5656576, "c3e6e651e87ea6ae1c751b12526500606a3e387be351114f42cc22258e140256"),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    for resource in EXPECTED:
        parser.add_argument(f"--{resource.replace('_', '-')}-url", required=True)
    parser.add_argument("--manifest", type=Path, default=Path("resources_manifest.json"))
    return parser.parse_args()


def verify(resource_id: str, url: str) -> None:
    if not url.startswith("https://"):
        raise ValueError(f"{resource_id}: URL non HTTPS")
    size, expected_hash = EXPECTED[resource_id]
    request = urllib.request.Request(url, headers={"User-Agent": "ECHO-BIBLE-release-verifier/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status != 200:
            raise ValueError(f"{resource_id}: HTTP {response.status}")
        content_type = response.headers.get_content_type()
        if content_type == "text/html":
            raise ValueError(f"{resource_id}: la réponse est une page HTML")
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as output:
            temporary_path = Path(output.name)

        try:
            with temporary_path.open("wb") as output:
                digest = hashlib.sha256()
                received = 0
                while chunk := response.read(1024 * 1024):
                    output.write(chunk)
                    digest.update(chunk)
                    received += len(chunk)
            if received != size:
                raise ValueError(f"{resource_id}: {received} octets au lieu de {size}")
            if digest.hexdigest() != expected_hash:
                raise ValueError(f"{resource_id}: SHA-256 incorrect")
            database = sqlite3.connect(f"file:{temporary_path}?mode=ro", uri=True)
            try:
                integrity = database.execute("PRAGMA integrity_check").fetchone()[0]
            finally:
                database.close()
            if integrity != "ok":
                raise ValueError(f"{resource_id}: integrity_check={integrity}")
        finally:
            temporary_path.unlink(missing_ok=True)
    print(f"{resource_id}: HTTP 200, {size} octets, SHA-256 et SQLite OK")


def main() -> None:
    args = parse_args()
    urls = {
        resource: getattr(args, f"{resource}_url")
        for resource in EXPECTED
    }
    for resource, url in urls.items():
        verify(resource, url)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    entries = {entry["id"]: entry for entry in manifest["resources"]}
    for resource, url in urls.items():
        entry = entries[resource]
        size, digest = EXPECTED[resource]
        if entry["sizeBytes"] != size or entry["sha256"] != digest:
            raise ValueError(f"{resource}: métadonnées locales inattendues")
        entry["downloadUrl"] = url
        entry["status"] = "available"
    temporary = args.manifest.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(args.manifest)
    print(f"Manifeste finalisé: {args.manifest}")


if __name__ == "__main__":
    main()
