#!/usr/bin/env bash
set -euo pipefail

usage() { echo 'Usage: validate.sh OUTPUT_DIR [--platforms ig,fb,li]' >&2; }
[[ $# -ge 1 ]] || { usage; exit 2; }
output_dir=$1
shift
platforms=''
if (($#)); then
  [[ $# -eq 2 && $1 == --platforms ]] || { usage; exit 2; }
  platforms=$2
fi

python3 - "$output_dir" "$platforms" <<'PY'
import json
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

try:
    from PIL import Image
except ImportError:
    print("FAIL: Pillow is required (python3 PIL)", file=sys.stderr)
    raise SystemExit(2)

root = Path(sys.argv[1]).resolve()
requested = [p for p in sys.argv[2].split(",") if p]
asset_root = Path("/home/eva/trelew-workspace/TrelewStuAssets/dist").resolve()
matrix = {
    "ig": {(1080, 1080), (1080, 1920)},
    "fb": {(1200, 630)},
    "li": {(1200, 627), (1584, 396)},
}
errors = []
seen = {p: set() for p in matrix}
seen_posts = set()

if not root.is_dir():
    errors.append(f"output directory does not exist: {root}")
    posts = []
else:
    posts = sorted(root.rglob("post.json"))
if not posts:
    errors.append("no post.json files found")

for meta_path in posts:
    try:
        data = json.loads(meta_path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"{meta_path}: invalid JSON ({exc})")
        continue
    if not isinstance(data, dict):
        errors.append(f"{meta_path}: root must be an object")
        continue
    for field in ("caption", "hashtags", "cta_url", "image_path", "brand_assets"):
        if field not in data or data[field] in (None, "", []):
            errors.append(f"{meta_path}: missing or empty field: {field}")
    hashtags = data.get("hashtags")
    if hashtags and not (
        isinstance(hashtags, str) or
        (isinstance(hashtags, list) and all(isinstance(x, str) and x.strip() for x in hashtags))
    ):
        errors.append(f"{meta_path}: hashtags must be a string or non-empty string array")
    cta = data.get("cta_url", "")
    if isinstance(cta, str):
        parsed = urlparse(cta)
        params = parse_qs(parsed.query)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            errors.append(f"{meta_path}: cta_url must be an absolute http(s) URL")
        for key in ("utm_source", "utm_medium", "utm_campaign", "utm_content"):
            if not params.get(key) or not params[key][0].strip():
                errors.append(f"{meta_path}: cta_url missing {key}")
    else:
        errors.append(f"{meta_path}: cta_url must be a string")

    brand_assets = data.get("brand_assets")
    if not isinstance(brand_assets, list) or not brand_assets or not all(
        isinstance(value, str) and value.strip() for value in brand_assets
    ):
        errors.append(f"{meta_path}: brand_assets must be a non-empty string array")
    else:
        for value in brand_assets:
            source = (asset_root / value).resolve()
            try:
                source.relative_to(asset_root)
            except ValueError:
                errors.append(f"{meta_path}: brand asset escapes dist/: {value}")
                continue
            if not source.is_file():
                errors.append(f"{meta_path}: brand asset not found in dist/: {value}")

    try:
        relative = meta_path.relative_to(root)
        platform = relative.parts[0]
    except (ValueError, IndexError):
        platform = ""
    if platform not in matrix:
        errors.append(f"{meta_path}: platform directory must be ig, fb, or li")
        continue
    if len(relative.parts) != 3 or relative.parts[2] != "post.json":
        errors.append(f"{meta_path}: expected <platform>/<WIDTH>x<HEIGHT>/post.json")
        continue
    image_value = data.get("image_path")
    if not isinstance(image_value, str) or not image_value:
        continue
    image_path = (meta_path.parent / image_value).resolve()
    try:
        image_path.relative_to(root)
    except ValueError:
        errors.append(f"{meta_path}: image_path escapes output directory")
        continue
    if not image_path.is_file():
        errors.append(f"{meta_path}: image not found: {image_value}")
        continue
    if image_path.suffix.lower() not in (".png", ".jpg", ".jpeg"):
        errors.append(f"{image_path}: final image must be PNG or JPEG")
        continue
    try:
        with Image.open(image_path) as image:
            image.load()
            size = image.size
    except Exception as exc:
        errors.append(f"{image_path}: image does not decode ({exc})")
        continue
    if size not in matrix[platform]:
        errors.append(f"{image_path}: wrong size {size[0]}x{size[1]} for {platform}")
    else:
        expected_dir = f"{size[0]}x{size[1]}"
        if relative.parts[1] != expected_dir:
            errors.append(f"{meta_path}: size directory must be {expected_dir}")
        seen[platform].add(size)
        key = (platform, size)
        if key in seen_posts:
            errors.append(f"{meta_path}: duplicate post for {platform} {expected_dir}")
        seen_posts.add(key)

targets = requested or sorted({p.relative_to(root).parts[0] for p in posts if p.relative_to(root).parts})
for platform in targets:
    if platform not in matrix:
        errors.append(f"unsupported requested platform: {platform}")
        continue
    for size in sorted(matrix[platform] - seen[platform]):
        errors.append(f"missing required {platform} image at {size[0]}x{size[1]}")

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    print(f"Validation failed with {len(errors)} error(s).", file=sys.stderr)
    raise SystemExit(1)
print(f"PASS: validated {len(posts)} post(s) in {root}")
for platform in targets:
    for width, height in sorted(seen.get(platform, set())):
        print(f"PASS: {platform} {width}x{height} image decodes at exact dimensions")
PY
