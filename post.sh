#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/eva/trelew-workspace/TrelewSocialMediaAds"
ASSET_REPO="/home/eva/trelew-workspace/TrelewStuAssets"
ASSET_ROOT="$ASSET_REPO/dist"
ASSET_COMMIT="354589215ac1a2f1ff0e8e5652d150b79c6a89be"
VOICE_SKILL="/home/eva/.hermes/skills/trelew-voice/SKILL.md"
UNSLOP_SKILL="$REPO_ROOT/skills/unslop/SKILL.md"
VIDEO_PYTHON="$REPO_ROOT/.video-venv/bin/python"
DEFAULT_OUT="$REPO_ROOT/out/$(date +%F)"

usage() {
  echo 'Usage: post.sh --brief "..." --platforms ig,fb,li [--out DIR]' >&2
}

brief=''
platforms=''
out_dir="$DEFAULT_OUT"
while (($#)); do
  case "$1" in
    --brief) [[ $# -ge 2 ]] || { usage; exit 2; }; brief=$2; shift 2 ;;
    --platforms) [[ $# -ge 2 ]] || { usage; exit 2; }; platforms=$2; shift 2 ;;
    --out) [[ $# -ge 2 ]] || { usage; exit 2; }; out_dir=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$brief" && -n "$platforms" ]] || { usage; exit 2; }
IFS=',' read -r -a requested <<< "$platforms"
declare -A seen_platforms=()
needs_reel=0
for platform in "${requested[@]}"; do
  case "$platform" in ig|fb|li) ;; *) echo "Unsupported platform: $platform" >&2; exit 2 ;; esac
  [[ -z "${seen_platforms[$platform]:-}" ]] || { echo "Duplicate platform: $platform" >&2; exit 2; }
  seen_platforms[$platform]=1
  [[ "$platform" == ig || "$platform" == fb ]] && needs_reel=1
done
[[ -d "$ASSET_ROOT" ]] || { echo "Brand assets not found: $ASSET_ROOT" >&2; exit 1; }
[[ -f "$UNSLOP_SKILL" ]] || { echo "Required copy-editing skill not found: $UNSLOP_SKILL" >&2; exit 1; }
ffmpeg_bin='not required for this platform selection'
if ((needs_reel)); then
  [[ -x "$VIDEO_PYTHON" ]] || {
    echo "Organic Reels require the repo-local video encoder. Run: $REPO_ROOT/setup-video-tools.sh" >&2
    exit 1
  }
  ffmpeg_bin=$("$VIDEO_PYTHON" -c 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())')
  [[ -x "$ffmpeg_bin" ]] || { echo "Video encoder is not executable: $ffmpeg_bin" >&2; exit 1; }
fi
actual_asset_commit=$(git -C "$ASSET_REPO" rev-parse HEAD)
[[ "$actual_asset_commit" == "$ASSET_COMMIT" ]] || {
  echo "Brand asset revision mismatch: expected $ASSET_COMMIT, found $actual_asset_commit" >&2
  exit 1
}

mkdir -p "$out_dir"
out_dir=$(cd "$out_dir" && pwd)
prompt_file="$REPO_ROOT/prompt.txt"
trap 'rm -f "$prompt_file"' EXIT

voice_rules='No separate T2 voice skill is installed. Keep copy direct, concise, senior, and free of hype.'
if [[ -f "$VOICE_SKILL" ]]; then
  voice_rules=$(<"$VOICE_SKILL")
fi
brand_rules=$(<"$ASSET_REPO/README.md")
unslop_rules=$(<"$UNSLOP_SKILL")

cat > "$prompt_file" <<EOF
Create one Trelew Studio social-post set for this brief:

$brief

Requested platforms: $platforms
Write all deliverables beneath: $out_dir

This is a non-deterministic creative run inside a consistent Trelew visual system. Make original layout and copy decisions for this brief, but keep the result recognisably related to other Trelew posts. Do not reuse one rigid template and do not invent a completely unrelated art direction on every run. Codex itself is the creative engine. Do not call an external image-generation API.

BRAND SAFETY — EXPORT ONLY:
- Approved artwork is immutable. Never redraw, trace, smooth, simplify, crop, reframe, substitute, or generatively edit it.
- Never stretch artwork; scale complete approved vectors uniformly and preserve clear margins.
- Never modify anything in /home/eva/trelew-workspace/TrelewStuAssets, especially src/masters, and never run pnpm refine:symbol.
- Use approved artwork only from $ASSET_ROOT as read-only input. Creativity belongs in copy, layout, and composition.
- Render final compositions by placing complete approved dist/ files on new canvases. Backgrounds, rules, geometric fields, and live copy may be newly drawn; brand artwork may only be placed and uniformly scaled.

Approved identity:
- Deep Teal #338591
- Warm Cream #FBF6E8
- Copper Camel #D4AE8C
- Deep Ink #122F34
- Typeface: Courier Prime Regular

Required size matrix:
- ig: 1080x1080 and 1080x1920
- fb: 1200x630
- li: 1200x627 and 1584x396

ORGANIC REELS — REQUIRED FOR META PLATFORMS:
- When ig is requested, also create ig/reel-1080x1920/reel.mp4 and ig/reel-1080x1920/reel.json.
- When fb is requested, also create fb/reel-1080x1920/reel.mp4 and fb/reel-1080x1920/reel.json.
- Each Reel must be exactly 20 seconds, vertical 9:16 at 1080x1920, and encoded as an MP4 suitable for Instagram or Facebook Reels. Target H.264 video at 30 frames per second and AAC audio when sound is present.
- A repo-local ffmpeg encoder is available at: $ffmpeg_bin. Use that exact binary for encoding rather than downloading or installing another tool.
- Python 3 with Pillow is available for drawing frames. Keep temporary frames, audio and render scripts beneath the output directory, then remove intermediates after a successful MP4 render.
- Make a genuine short-form motion piece, not a still image held for 20 seconds. Use 4–6 purposeful scenes with restrained movement, readable pacing and a clear beginning, middle and end.
- Show a real Trelew Studio service, client problem, working method or documented product proof related to the brief. Use real screenshots and supplied Trelew assets when available. Never fabricate a client, testimonial, result, interface or statistic.
- Use this default sequence: 0–3 seconds for one concrete hook; 3–14 seconds for the problem, proof or useful explanation; 14–18 seconds for how Trelew helps; 18–20 seconds for one restrained CTA.
- Design for sound-off viewing. Any spoken words must have accurate burned-in captions. Do not use copyrighted music or unlicensed stock footage.
- Keep text, logos and essential visual information away from the top, bottom and side interface areas. Use the central safe zone and check legibility at phone size.
- Apply the Unslop first pass to the spoken script, on-screen text, captions, post caption, CTA and hashtags before rendering.
- reel.json must contain caption, hashtags, cta_url, video_path, spoken_script, audio_strategy, on_screen_text, brand_assets and duration_seconds fields. All fields except spoken_script must be non-empty. spoken_script must be a string and may be empty when the Reel intentionally has no narration. duration_seconds must be 20. video_path must be relative to reel.json.
- If no working video encoder is available, stop and report the missing dependency. Never create a renamed image, empty file or other fake MP4 to satisfy the filename.

T2 voice rules (embedded from $VOICE_SKILL when present):
---
$voice_rules
---

MANDATORY UNSLOP FIRST PASS:
- Every piece of generated text must go through the complete Unslop skill below before it becomes final. This includes visible image copy, headlines, supporting copy, CTA labels, captions, hashtags, and any other human-readable text or metadata you create.
- Work in this order: draft text from the brief and verified facts; apply the Unslop skill as the first editorial pass; check the result against the Trelew voice and factual constraints; only then render text into an image and write post.json.
- Never postpone this pass until after rendering. Text baked into an image must already be reviewed.
- Preserve the intended language, facts, meaning, and Trelew tone while rewriting. Do not use the skill as permission to invent proof, change an offer, or remove necessary detail.
- Treat this as a required step even when the first draft appears short or clean.

Unslop skill (repo-local source: $UNSLOP_SKILL):
---
$unslop_rules
---

Output contract:
- Use directories <platform>/<WIDTH>x<HEIGHT>/ beneath the output directory.
- Each size directory must contain exactly one final image and a post.json.
- post.json must be a JSON object with non-empty caption, hashtags, cta_url, and image_path fields.
- post.json must include brand_assets: a non-empty array listing every approved source asset used, as paths relative to $ASSET_ROOT.
- hashtags must be a non-empty string or an array of non-empty strings.
- cta_url must be an absolute http(s) URL with non-empty utm_source, utm_medium, utm_campaign, and utm_content query parameters.
- image_path must be relative to its post.json and point to the final image.
- The final image must be PNG or JPEG and the size directory name must match its exact canvas dimensions.
- Meta Reel files use the separate <platform>/reel-1080x1920/ contract above and do not replace the required static images.
- Do not create files outside the output directory and do not change repository tooling.

Authoritative TrelewStuAssets README (pinned at git commit $ASSET_COMMIT):
---
$brand_rules
---

TRELEW SOCIAL CREATIVE SYSTEM:

The seven ads in $REPO_ROOT/reference_posts_from_other_companies were analysed for reusable patterns. They are inspiration only: never copy their layouts, copy, trademarks, people, screenshots or distinctive branded treatments.

Core hierarchy:
- Communicate one concrete idea per image. A viewer should understand the subject in about two seconds.
- Use a clear three-zone hierarchy: small Trelew identity at the top; one short claim in the upper or middle zone; proof, product UI or a restrained CTA in the lower zone.
- Keep important content inside the central 80% safe zone. Default to centred axial balance or a strict editorial grid. Use asymmetry only when it helps a real screenshot or photograph.
- Keep the Trelew mark secondary to the message. Preserve its supplied clear space and never use it as decorative texture.

Choose one direction per set:
1. Editorial product proof — DEFAULT. Warm Cream or one approved flat background, a concise headline, and a large real product screenshot or approved Trelew visual. Inspired by the restraint and product focus seen in the Base44, GoDaddy and Squarespace references.
2. Evidence or comparison — Use a small two-column comparison, short checklist, before/after or one honest number. Keep it calm and sourced; never imitate aggressive savings stickers or crowded pricing graphics.
3. Human studio and process — Use a real, supplied Trelew team photograph plus one interface or process point. Never generate a fake team member, testimonial or client.

Colour and composition:
- Use one dominant approved background, one high-contrast text colour and at most one accent from the approved palette. Product screenshots may introduce their own colours.
- Prefer Warm Cream + Deep Ink, with Deep Teal or Copper Camel as the single accent. Dark compositions may use Deep Ink + Warm Cream.
- Avoid neon gradients, glows, floating icon clutter, excessive shadows, savings stickers, generic laptop mockups and decorative effects that compete with the proof.
- Whitespace is part of the design. Do not fill every empty area.

Typography:
- Courier Prime Regular is the sole approved typeface for newly typeset Trelew copy. Load the exact font from $ASSET_REPO/assets/fonts/CourierPrime-Regular.ttf.
- Do not introduce another font, synthetic bold, synthetic italic, condensation or stretching unless the user explicitly approves a brand change. Create hierarchy with size, case, spacing, colour and placement.
- Because Courier Prime Regular is monospaced and relatively light, never use it for dense small paragraphs inside an image.
- On-image headline: 3–10 words, no more than 3 lines, normally sentence case. Reserve all caps for a short statement of at most 5 words.
- Supporting copy: at most 18 words and no more than 2 short lines. Put the fuller explanation in the caption.
- At final raster size, use approximately 72–120 px headlines and 32–42 px supporting copy on 1080 px assets; 54–84 px headlines and 24–32 px supporting copy on 1200×630/627 assets; 44–64 px headlines and 20–28 px supporting copy on 1584×396 assets. Adjust upward when readability requires it.
- Use tight but readable headline leading, comfortable supporting-copy leading and strong contrast. Review every export at its actual pixel dimensions.

Content and proof:
- Prefer a specific problem, outcome, category, price, timeframe or comparison over vague brand language.
- Use real screenshots, real supplied photography and documented facts whenever available. Never fabricate client interfaces, testimonials, results, discounts, prices, delivery times or performance statistics.
- If no real product proof is available, use a type-led or geometric composition in the approved palette rather than inventing evidence.
- Organic posts should prioritise useful proof or insight; an on-image button is optional. Paid ads may use one restrained CTA. Never place multiple CTAs in one asset.
- Match the language and CTA destination to the intended market. Do not combine Spanish and English in one image unless the brief explicitly requests it.

Copy tone:
- Write in a direct, calm and senior voice. Lead with the reader's problem, a useful observation or a concrete outcome—not with "we are excited to announce".
- Prefer short declarative sentences and specific nouns and verbs. Demonstrate expertise through the work instead of claiming authority.
- Avoid hype and generic AI-marketing language such as "revolutionary", "game-changing", "unlock", "seamless", "cutting-edge" and "transform your digital future".
- Keep the caption materially more informative than the image. Use one CTA and only a few specific hashtags; avoid generic hashtag clouds.

Iteration from an existing run:
- If the brief names a run reference such as 2026-09-25/runA, inspect $REPO_ROOT/out/<that-reference>/, including every image and post.json, before designing.
- Treat that run as the baseline. Preserve the elements the brief does not ask to change, improve the named weaknesses, and write the revision to the new output directory without overwriting the referenced run.

Avoid the weak patterns in the references:
- No unsupported superlatives such as "best", "unlimited" or "guaranteed".
- No large discount bursts, exaggerated urgency, crowded feature lists or hype-heavy all-caps layouts.
- No visual style chosen merely because it is loud. Trelew should feel direct, senior, product-led and calm.
EOF

codex exec -C "$REPO_ROOT" --skip-git-repo-check --approve-for-me \
  -o /tmp/codex-post-last-message.txt "$(cat "$prompt_file")"
"$REPO_ROOT/validate.sh" "$out_dir" --platforms "$platforms"
reel_platforms=''
for platform in "${requested[@]}"; do
  if [[ "$platform" == ig || "$platform" == fb ]]; then
    reel_platforms+="${reel_platforms:+,}$platform"
  fi
done
if [[ -n "$reel_platforms" ]]; then
  "$REPO_ROOT/validate_reels.py" "$out_dir" --platforms "$reel_platforms" --duration 20
fi
"$REPO_ROOT/refresh-gallery.py"
