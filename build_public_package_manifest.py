"""Build public-package checksums without circularly hashing the manifests."""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parent
EXCLUDE = {"PACKAGE_MANIFEST.json", "PACKAGE_SHA256SUMS.txt"}
EXCLUDE_DIRS = {".git", "__pycache__"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


files = []
for path in sorted(ROOT.rglob("*")):
    relative_parts = path.relative_to(ROOT).parts
    if not path.is_file() or path.name in EXCLUDE or any(part in EXCLUDE_DIRS for part in relative_parts):
        continue
    relative = path.relative_to(ROOT).as_posix()
    files.append({"path": relative, "bytes": path.stat().st_size, "sha256": sha256(path)})

manifest = {
    "schema": "systems-submission-reproducibility-package-v1",
    "release_status": "public release v1.0.0; persistent archive identifier recorded separately",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "file_count": len(files),
    "files": files,
}
(ROOT / "PACKAGE_MANIFEST.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
)
(ROOT / "PACKAGE_SHA256SUMS.txt").write_text(
    "".join(f"{item['sha256']}  {item['path']}\n" for item in files), encoding="utf-8"
)
print(f"Package manifest written for {len(files)} files.")
