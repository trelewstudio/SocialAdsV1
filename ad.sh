#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/eva/trelew-workspace/TrelewSocialMediaAds"
ASSET_REPO="/home/eva/trelew-workspace/TrelewStuAssets"
ASSET_ROOT="$ASSET_REPO/dist"
ASSET_COMMIT="354589215ac1a2f1ff0e8e5652d150b79c6a89be"
VOICE_SKILL="/home/eva/.hermes/skills/trelew-voice/SKILL.md"
UNSLOP_SKILL="$REPO_ROOT/skills/unslop/SKILL.md"
VIDEO_PYTHON="$REPO_ROOT/.video-venv/bin/python"
DEFAULT_OUT="$REPO_ROOT/out/ads/$(date +%F)"
HEYGEN_ENV_FILE="$REPO_ROOT/.env.heygen"

if [[ -f "$HEYGEN_ENV_FILE" ]]; then
  # This ignored, owner-readable file is created by setup-heygen.sh.
  # shellcheck disable=SC1090
  source "$HEYGEN_ENV_FILE"
fi

usage() {
  cat >&2 <<'EOF'
Usage: ad.sh --brief "..." --landing-url URL [--platforms ig,fb] [--out DIR] [--render] [--use-existing]

Without --render, creates and validates the paid-Reel production package only.
With --render, submits the approved script to HeyGen and downloads the MP4.
With --use-existing, skips Codex and validates the existing ad.json and video-prompt.txt in --out.

Required for --render:
  HEYGEN_API_KEY
  HEYGEN_WHITE_MALE_AVATAR_ID
  HEYGEN_VOICE_ID_ES_ES for /es/ landing pages
  HEYGEN_VOICE_ID_EN_GB for /uk/ landing pages
  HEYGEN_VOICE_ID_EN_IE or HEYGEN_VOICE_ID_EN_GB for /ie/ landing pages

Run ./setup-heygen.sh once to save these values in the ignored .env.heygen file.
EOF
}

brief=''
landing_url=''
platforms='ig,fb'
out_dir="$DEFAULT_OUT"
render=0
use_existing=0

while (($#)); do
  case "$1" in
    --brief) [[ $# -ge 2 ]] || { usage; exit 2; }; brief=$2; shift 2 ;;
    --landing-url) [[ $# -ge 2 ]] || { usage; exit 2; }; landing_url=$2; shift 2 ;;
    --platforms) [[ $# -ge 2 ]] || { usage; exit 2; }; platforms=$2; shift 2 ;;
    --out) [[ $# -ge 2 ]] || { usage; exit 2; }; out_dir=$2; shift 2 ;;
    --render) render=1; shift ;;
    --use-existing) use_existing=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$brief" && -n "$landing_url" ]] || { usage; exit 2; }

IFS=',' read -r -a requested <<< "$platforms"
declare -A seen_platforms=()
for platform in "${requested[@]}"; do
  case "$platform" in ig|fb) ;; *) echo "Unsupported paid-Reel platform: $platform" >&2; exit 2 ;; esac
  [[ -z "${seen_platforms[$platform]:-}" ]] || { echo "Duplicate platform: $platform" >&2; exit 2; }
  seen_platforms[$platform]=1
done

case "$landing_url" in
  https://trelew.studio/es/*)
    language_name='Spanish from Spain'
    language_code='es-ES'
    market='es'
    ;;
  https://trelew.studio/uk/*)
    language_name='British English'
    language_code='en-GB'
    market='uk'
    ;;
  https://trelew.studio/ie/*)
    language_name='English for Ireland'
    language_code='en-IE'
    market='ie'
    ;;
  *)
    echo "Landing URL must be an https://trelew.studio/es/, /uk/, or /ie/ page." >&2
    exit 2
    ;;
esac

[[ -d "$ASSET_ROOT" ]] || { echo "Brand assets not found: $ASSET_ROOT" >&2; exit 1; }
[[ -f "$UNSLOP_SKILL" ]] || { echo "Required copy-editing skill not found: $UNSLOP_SKILL" >&2; exit 1; }
actual_asset_commit=$(git -C "$ASSET_REPO" rev-parse HEAD)
[[ "$actual_asset_commit" == "$ASSET_COMMIT" ]] || {
  echo "Brand asset revision mismatch: expected $ASSET_COMMIT, found $actual_asset_commit" >&2
  exit 1
}

avatar_id=''
voice_id=''
ffmpeg_bin=''
if ((render)); then
  [[ -n "${HEYGEN_API_KEY:-}" ]] || { echo "HEYGEN_API_KEY is required with --render." >&2; exit 2; }
  [[ -n "${HEYGEN_WHITE_MALE_AVATAR_ID:-}" ]] || {
    echo "HEYGEN_WHITE_MALE_AVATAR_ID is required with --render." >&2
    exit 2
  }
  avatar_id=$HEYGEN_WHITE_MALE_AVATAR_ID
  case "$market" in
    es) voice_id=${HEYGEN_VOICE_ID_ES_ES:-} ;;
    uk) voice_id=${HEYGEN_VOICE_ID_EN_GB:-} ;;
    ie) voice_id=${HEYGEN_VOICE_ID_EN_IE:-${HEYGEN_VOICE_ID_EN_GB:-}} ;;
  esac
  [[ -n "$voice_id" ]] || {
    echo "No HeyGen voice ID is configured for $language_code." >&2
    exit 2
  }
  [[ -x "$VIDEO_PYTHON" ]] || {
    echo "Paid Reel finishing requires the repo-local encoder. Run: $REPO_ROOT/setup-video-tools.sh" >&2
    exit 1
  }
  ffmpeg_bin=$("$VIDEO_PYTHON" -c 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())')
  [[ -x "$ffmpeg_bin" ]] || { echo "Video encoder is not executable: $ffmpeg_bin" >&2; exit 1; }
fi

mkdir -p "$out_dir"
out_dir=$(cd "$out_dir" && pwd)
prompt_file="$REPO_ROOT/ad-prompt.txt"
trap 'rm -f "$prompt_file"' EXIT

voice_rules='No separate T2 voice skill is installed. Keep copy direct, concise, senior, and free of hype.'
if [[ -f "$VOICE_SKILL" ]]; then
  voice_rules=$(<"$VOICE_SKILL")
fi
brand_rules=$(<"$ASSET_REPO/README.md")
unslop_rules=$(<"$UNSLOP_SKILL")

cat > "$prompt_file" <<EOF
Create the production package for one Trelew Studio paid social Reel.

Brief:
$brief

Platforms: $platforms
Landing page: $landing_url
Market: $market
Required spoken and written language: $language_name ($language_code)
Write all deliverables beneath: $out_dir

The final ad is a 30-second vertical Reel. A licensed synthetic adult white male presenter speaks directly to camera in the required language. He is a neutral presenter, not a Trelew employee, client, founder or testimonial subject. Never imply that he personally hired Trelew or experienced the problem. Do not imitate or resemble a real person.

PAID REEL STRUCTURE:
- 0–4 seconds: state one recognisable client problem in concrete language.
- 4–15 seconds: explain the operational or commercial consequence without exaggeration.
- 15–25 seconds: explain specifically how the relevant Trelew service helps.
- 25–30 seconds: one restrained CTA that matches $landing_url.
- Write natural speech for approximately 30 seconds. Target 60–72 words in English or 55–68 words in Spanish. Use complete sentences and natural pauses.
- Do not invent metrics, delivery times, prices, guarantees, testimonials, client names, interfaces or project results.
- The presenter should sound calm, informed and conversational. No shouting, forced enthusiasm, urgency tricks or influencer mannerisms.
- The visual direction must call for a clean studio or office background, natural lighting, chest-up framing, direct eye contact, restrained gestures and enough negative space for captions.
- Use accurate burned-in captions and keep all essential content in the central safe zone of a 1080x1920 frame.
- This is paid acquisition creative. The script must connect the named problem to the landing page, not merely describe Trelew in general.

MANDATORY UNSLOP FIRST PASS:
- Draft every piece of copy from the brief and verified facts.
- Apply the complete Unslop skill below as the first editorial pass to the spoken script, on-screen text, captions, primary text, headline, description, CTA and hashtags.
- Then check the result against the Trelew voice and factual constraints before writing the deliverables.
- Preserve the required language and meaning. Never use rewriting as permission to invent evidence.

Unslop skill:
---
$unslop_rules
---

T2 voice rules:
---
$voice_rules
---

OUTPUT CONTRACT:
- Create exactly one $out_dir/ad.json and one $out_dir/video-prompt.txt. Do not create the MP4; ad.sh submits the approved script to the configured renderer after validation.
- ad.json must be valid JSON with these fields:
  - title: short internal name.
  - platforms: exactly the requested platform codes.
  - landing_url: exactly $landing_url without UTM parameters.
  - language_code: exactly $language_code.
  - duration_target_seconds: exactly 30.
  - aspect_ratio: exactly "9:16".
  - spoken_script: the presenter's complete speech.
  - on_screen_text: an array of short caption or emphasis strings.
  - primary_text, headline, description and cta_label: platform-ready ad copy in $language_name.
  - hashtags: a short array of specific hashtags.
  - cta_urls: an object with one entry per requested platform. Use utm_source=instagram for ig and utm_source=facebook for fb, utm_medium=paid_social, plus non-empty utm_campaign and utm_content.
  - presenter: {"synthetic": true, "appearance": "adult white man", "role": "presenter", "is_client": false}.
  - voice_speed: a number from 0.9 to 1.1. Prefer 1.0 and adjust only to target 30 seconds naturally.
  - ai_disclosure_review_required: true.
- video-prompt.txt must describe the complete presenter direction, framing, background, caption treatment, brand colours and timing. It must repeat that the presenter is synthetic and is not a testimonial.
- Do not create files outside $out_dir and do not change repository tooling.

BRAND SAFETY:
- Use the approved palette: Deep Teal #338591, Warm Cream #FBF6E8, Copper Camel #D4AE8C and Deep Ink #122F34.
- Use Courier Prime Regular for any newly typeset Trelew text.
- Approved artwork is immutable. Never redraw, trace, crop, stretch, substitute or generatively edit it.
- Never modify $ASSET_REPO. If video post-production later uses a logo, take it only from $ASSET_ROOT and scale it uniformly.

Authoritative TrelewStuAssets README at commit $ASSET_COMMIT:
---
$brand_rules
---
EOF

if ((use_existing)); then
  [[ -f "$out_dir/ad.json" && -f "$out_dir/video-prompt.txt" ]] || {
    echo "--use-existing requires ad.json and video-prompt.txt in $out_dir" >&2
    exit 2
  }
else
  codex exec -C "$REPO_ROOT" --skip-git-repo-check --approve-for-me \
    -o /tmp/codex-ad-last-message.txt "$(cat "$prompt_file")"
fi

"$REPO_ROOT/validate_ad.py" "$out_dir/ad.json" \
  --platforms "$platforms" \
  --landing-url "$landing_url" \
  --language "$language_code"

if ((render)); then
  "$REPO_ROOT/render_heygen.py" \
    --metadata "$out_dir/ad.json" \
    --output "$out_dir/heygen-source.mp4" \
    --avatar-id "$avatar_id" \
    --voice-id "$voice_id"
  "$ffmpeg_bin" -hide_banner -loglevel error \
    -i "$out_dir/heygen-source.mp4" \
    -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=0xFBF6E8,tpad=stop_mode=clone:stop_duration=30" \
    -af "apad=pad_dur=30" \
    -t 30 -r 30 -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k \
    -movflags +faststart -y "$out_dir/ad.mp4"
  "$REPO_ROOT/validate_video.py" "$out_dir/ad.mp4" \
    --duration 30 --tolerance 0.1 --width 1080 --height 1920
  echo "PASS: paid Reel rendered at $out_dir/ad.mp4"
else
  echo "PASS: paid-Reel production package created at $out_dir"
  echo "Run the same command with --render after configuring the documented HeyGen variables."
fi
