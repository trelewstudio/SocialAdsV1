#!/usr/bin/env python3
"""Rebuild the static gallery manifest from validated post metadata."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out"
items = []

if OUT.is_dir():
    for metadata in sorted(OUT.rglob("post.json")):
        try:
            post = json.loads(metadata.read_text(encoding="utf-8"))
            image = (metadata.parent / post["image_path"]).resolve()
            image.relative_to(ROOT)
        except (KeyError, ValueError, json.JSONDecodeError):
            continue
        if not image.is_file():
            continue
        relative = metadata.relative_to(OUT)
        parts = relative.parts
        if len(parts) == 5:
            date, run, platform, size, _ = parts
            run_ref = f"{date}/{run}"
        elif len(parts) == 4:
            date, platform, size, _ = parts
            run = date
            run_ref = date
        else:
            continue
        items.append(
            {
                "slug": f"{date}-{run}-{platform}-{size}",
                "title": f"{run} · {platform.upper()} · {size}",
                "date": date,
                "run": run,
                "run_ref": run_ref,
                "platform": platform,
                "size": size,
                "caption": post.get("caption", ""),
                "cta_url": post.get("cta_url", ""),
                "image_path": image.relative_to(ROOT).as_posix(),
                "alt": f"Trelew Studio {platform.upper()} social post, {size}",
            }
        )

(ROOT / "manifest.json").write_text(
    json.dumps({"sets": items}, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
print(f"PASS: gallery manifest lists {len(items)} generated post(s)")
