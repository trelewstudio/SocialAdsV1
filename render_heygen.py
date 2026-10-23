#!/usr/bin/env python3
"""Render a validated Trelew talking-presenter Reel with HeyGen v3."""

from __future__ import annotations

import argparse
import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


API_ROOT = "https://api.heygen.com/v3"


def request_json(url: str, api_key: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        method="GET" if payload is None else "POST",
        headers={
            "x-api-key": api_key,
            "Content-Type": "application/json",
            "User-Agent": "TrelewSocialMediaAds/1.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HeyGen returned HTTP {exc.code}: {detail}") from exc
    except (urllib.error.URLError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"HeyGen request failed: {exc}") from exc


def nested_value(value: Any, keys: tuple[str, ...]) -> Any:
    if isinstance(value, dict):
        for key in keys:
            found = value.get(key)
            if found not in (None, ""):
                return found
        for child in value.values():
            found = nested_value(child, keys)
            if found not in (None, ""):
                return found
    elif isinstance(value, list):
        for child in value:
            found = nested_value(child, keys)
            if found not in (None, ""):
                return found
    return None


def download(url: str, destination: Path, minimum_bytes: int = 1024) -> None:
    if not url.startswith("https://"):
        raise RuntimeError("HeyGen returned a non-HTTPS video URL")
    request = urllib.request.Request(url, headers={"User-Agent": "TrelewSocialMediaAds/1.0"})
    temporary = destination.with_suffix(destination.suffix + ".part")
    with urllib.request.urlopen(request, timeout=180) as response, temporary.open("wb") as handle:
        while chunk := response.read(1024 * 1024):
            handle.write(chunk)
    if temporary.stat().st_size < minimum_bytes:
        temporary.unlink(missing_ok=True)
        raise RuntimeError("downloaded video is unexpectedly small")
    temporary.replace(destination)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--avatar-id", required=True)
    parser.add_argument("--voice-id", required=True)
    parser.add_argument("--timeout", type=int, default=1800)
    args = parser.parse_args()

    api_key = os.environ.get("HEYGEN_API_KEY", "")
    if not api_key:
        print("FAIL: HEYGEN_API_KEY is not set")
        return 2
    try:
        metadata = json.loads(args.metadata.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL: cannot read {args.metadata}: {exc}")
        return 2

    payload = {
        "type": "avatar",
        "avatar_id": args.avatar_id,
        "title": str(metadata["title"])[:120],
        "aspect_ratio": "9:16",
        "background": {"type": "color", "value": "#FBF6E8"},
        "caption": {"file_format": "srt", "style": "default"},
        "output_format": "mp4",
        "script": metadata["spoken_script"],
        "voice_id": args.voice_id,
        "voice_settings": {
            "speed": metadata.get("voice_speed", 1.0),
            "pitch": 0,
            "volume": 1,
            "locale": metadata["language_code"],
        },
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    request_path = args.output.with_name("heygen-request.json")
    request_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    try:
        created = request_json(f"{API_ROOT}/videos", api_key, payload)
        video_id = nested_value(created, ("video_id", "id"))
        if not isinstance(video_id, str) or not video_id:
            raise RuntimeError(f"HeyGen response contains no video ID: {created}")
        print(f"Submitted HeyGen video {video_id}. Waiting for rendering...")

        deadline = time.monotonic() + args.timeout
        final: dict[str, Any] | None = None
        while time.monotonic() < deadline:
            result = request_json(f"{API_ROOT}/videos/{video_id}", api_key)
            status = str(nested_value(result, ("status",)) or "").lower()
            if status in {"completed", "complete", "success", "succeeded"}:
                final = result
                break
            if status in {"failed", "error", "cancelled", "canceled"}:
                raise RuntimeError(f"HeyGen render ended with status {status}: {result}")
            print(f"HeyGen status: {status or 'pending'}")
            time.sleep(10)
        if final is None:
            raise RuntimeError(f"HeyGen render did not finish within {args.timeout} seconds")

        video_url = nested_value(final, ("video_url", "videoUrl"))
        if not isinstance(video_url, str) or not video_url:
            raise RuntimeError(f"completed HeyGen response contains no video URL: {final}")
        download(video_url, args.output)

        result_path = args.output.with_name("heygen-render.json")
        result_path.write_text(json.dumps(final, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        caption_url = nested_value(final, ("caption_url", "subtitle_url", "srt_url"))
        if isinstance(caption_url, str) and caption_url.startswith("https://"):
            download(caption_url, args.output.with_suffix(".srt"), minimum_bytes=1)
    except (KeyError, OSError, RuntimeError, urllib.error.URLError) as exc:
        print(f"FAIL: {exc}")
        return 1

    print(f"PASS: downloaded HeyGen Reel to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
