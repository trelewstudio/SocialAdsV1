#!/usr/bin/env python3
"""Validate the Reel output contract for organic posts."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--platforms", required=True)
    parser.add_argument("--duration", type=float, required=True)
    args = parser.parse_args()

    root = args.output_dir.resolve()
    platforms = [value for value in args.platforms.split(",") if value]
    errors: list[str] = []
    validator = Path(__file__).resolve().with_name("validate_video.py")

    for platform in platforms:
        if platform not in {"ig", "fb"}:
            errors.append(f"unsupported Reel platform: {platform}")
            continue
        directory = root / platform / "reel-1080x1920"
        metadata = directory / "reel.json"
        if not metadata.is_file():
            errors.append(f"missing {platform} Reel metadata: {metadata}")
            continue
        try:
            data = json.loads(metadata.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{metadata}: invalid JSON ({exc})")
            continue
        for field in (
            "caption",
            "hashtags",
            "cta_url",
            "video_path",
            "audio_strategy",
            "on_screen_text",
            "brand_assets",
            "duration_seconds",
        ):
            if data.get(field) in (None, "", []):
                errors.append(f"{metadata}: missing or empty field: {field}")
        if not isinstance(data.get("spoken_script"), str):
            errors.append(f"{metadata}: spoken_script must be a string")
        if data.get("duration_seconds") != args.duration:
            errors.append(
                f"{metadata}: duration_seconds must be {args.duration:g}"
            )
        cta = data.get("cta_url")
        if isinstance(cta, str):
            parsed = urlparse(cta)
            params = parse_qs(parsed.query)
            if parsed.scheme not in {"http", "https"} or not parsed.netloc:
                errors.append(f"{metadata}: cta_url must be absolute http(s)")
            for key in ("utm_source", "utm_medium", "utm_campaign", "utm_content"):
                if not params.get(key) or not params[key][0].strip():
                    errors.append(f"{metadata}: cta_url missing {key}")
        else:
            errors.append(f"{metadata}: cta_url must be a string")

        video_value = data.get("video_path")
        if not isinstance(video_value, str) or not video_value:
            continue
        video = (directory / video_value).resolve()
        try:
            video.relative_to(root)
        except ValueError:
            errors.append(f"{metadata}: video_path escapes output directory")
            continue
        if video.suffix.lower() != ".mp4" or not video.is_file():
            errors.append(f"{metadata}: Reel MP4 not found: {video_value}")
            continue
        result = subprocess.run(
            [
                sys.executable,
                str(validator),
                str(video),
                "--duration",
                str(args.duration),
                "--tolerance",
                "1",
                "--width",
                "1080",
                "--height",
                "1920",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode:
            errors.extend(line for line in result.stdout.splitlines() if line)
        elif result.stdout.strip():
            print(result.stdout.strip())

    if errors:
        for error in errors:
            print(f"FAIL: {error}" if not error.startswith("FAIL:") else error, file=sys.stderr)
        print(f"Reel validation failed with {len(errors)} error(s).", file=sys.stderr)
        return 1
    print(f"PASS: validated {len(platforms)} organic Reel(s) in {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
