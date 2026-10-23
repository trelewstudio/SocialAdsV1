#!/usr/bin/env python3
"""Validate a Trelew paid-Reel production package before paid rendering."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from urllib.parse import parse_qs, urlparse


TEXT_FIELDS = (
    "spoken_script",
    "primary_text",
    "headline",
    "description",
    "cta_label",
)
UNSLOP_BLOCKLIST = {
    "additionally",
    "crucial",
    "delve",
    "game-changing",
    "pivotal",
    "revolutionary",
    "seamless",
    "showcase",
    "tapestry",
    "unlock",
    "utilize",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata", type=Path)
    parser.add_argument("--platforms", required=True)
    parser.add_argument("--landing-url", required=True)
    parser.add_argument("--language", required=True)
    args = parser.parse_args()

    errors: list[str] = []
    try:
        data = json.loads(args.metadata.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL: {args.metadata}: invalid JSON ({exc})")
        return 1
    if not isinstance(data, dict):
        print(f"FAIL: {args.metadata}: root must be an object")
        return 1

    required = (
        "title",
        "platforms",
        "landing_url",
        "language_code",
        "duration_target_seconds",
        "aspect_ratio",
        "spoken_script",
        "on_screen_text",
        "primary_text",
        "headline",
        "description",
        "cta_label",
        "hashtags",
        "cta_urls",
        "presenter",
        "voice_speed",
        "ai_disclosure_review_required",
    )
    for field in required:
        if data.get(field) in (None, "", []):
            errors.append(f"missing or empty field: {field}")

    expected_platforms = args.platforms.split(",")
    if data.get("platforms") != expected_platforms:
        errors.append(f"platforms must exactly equal {expected_platforms!r}")
    if data.get("landing_url") != args.landing_url:
        errors.append("landing_url does not match the requested page")
    if data.get("language_code") != args.language:
        errors.append(f"language_code must be {args.language}")
    if data.get("duration_target_seconds") != 30:
        errors.append("duration_target_seconds must be 30")
    if data.get("aspect_ratio") != "9:16":
        errors.append('aspect_ratio must be "9:16"')

    script = data.get("spoken_script", "")
    if isinstance(script, str):
        word_count = len(re.findall(r"\b[\wÀ-ÿ'-]+\b", script))
        minimum, maximum = (55, 68) if args.language == "es-ES" else (60, 72)
        if not minimum <= word_count <= maximum:
            errors.append(
                f"spoken_script has {word_count} words; expected {minimum}–{maximum} "
                "for an approximately 30-second delivery"
            )
    else:
        errors.append("spoken_script must be a string")

    presenter = data.get("presenter")
    if not isinstance(presenter, dict):
        errors.append("presenter must be an object")
    else:
        if presenter.get("synthetic") is not True:
            errors.append("presenter.synthetic must be true")
        if presenter.get("appearance") != "adult white man":
            errors.append('presenter.appearance must be "adult white man"')
        if presenter.get("role") != "presenter":
            errors.append('presenter.role must be "presenter"')
        if presenter.get("is_client") is not False:
            errors.append("presenter.is_client must be false")

    speed = data.get("voice_speed")
    if not isinstance(speed, (int, float)) or isinstance(speed, bool) or not 0.9 <= speed <= 1.1:
        errors.append("voice_speed must be a number from 0.9 to 1.1")
    if data.get("ai_disclosure_review_required") is not True:
        errors.append("ai_disclosure_review_required must be true")

    cta_urls = data.get("cta_urls")
    if not isinstance(cta_urls, dict):
        errors.append("cta_urls must be an object")
    else:
        source_by_platform = {"ig": "instagram", "fb": "facebook"}
        for platform in expected_platforms:
            value = cta_urls.get(platform)
            if not isinstance(value, str):
                errors.append(f"cta_urls.{platform} must be a string")
                continue
            parsed = urlparse(value)
            params = parse_qs(parsed.query)
            clean_url = parsed._replace(query="", fragment="").geturl()
            if clean_url != args.landing_url:
                errors.append(f"cta_urls.{platform} must point to the requested landing page")
            expected_source = source_by_platform[platform]
            if params.get("utm_source") != [expected_source]:
                errors.append(f"cta_urls.{platform} must use utm_source={expected_source}")
            if params.get("utm_medium") != ["paid_social"]:
                errors.append(f"cta_urls.{platform} must use utm_medium=paid_social")
            for key in ("utm_campaign", "utm_content"):
                if not params.get(key) or not params[key][0].strip():
                    errors.append(f"cta_urls.{platform} missing {key}")

    text_values: list[str] = []
    for field in TEXT_FIELDS:
        value = data.get(field)
        if isinstance(value, str):
            text_values.append(value)
    for field in ("on_screen_text", "hashtags"):
        value = data.get(field)
        if not isinstance(value, list) or not value or not all(
            isinstance(item, str) and item.strip() for item in value
        ):
            errors.append(f"{field} must be a non-empty string array")
        else:
            text_values.extend(value)

    combined = "\n".join(text_values)
    lowered = combined.lower()
    for phrase in sorted(UNSLOP_BLOCKLIST):
        if re.search(rf"\b{re.escape(phrase)}\b", lowered):
            errors.append(f"Unslop check found blocked wording: {phrase}")
    for character, label in (("—", "em dash"), ("–", "en dash"), ("“", "curly quote"), ("”", "curly quote")):
        if character in combined:
            errors.append(f"Unslop check found {label}: {character}")

    video_prompt = args.metadata.with_name("video-prompt.txt")
    if not video_prompt.is_file() or not video_prompt.read_text(encoding="utf-8").strip():
        errors.append(f"missing or empty video prompt: {video_prompt}")

    if errors:
        for error in errors:
            print(f"FAIL: {args.metadata}: {error}")
        print(f"Ad package validation failed with {len(errors)} error(s).")
        return 1
    print(f"PASS: validated paid-Reel package {args.metadata}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
