# Trelew Social Media Ads

Small, Codex-driven tooling for composing social posts from the approved Trelew Studio brand exports.

## Use

```sh
./post.sh --brief "Show our working dashboard demo" --platforms ig,fb,li
./post.sh --brief "Editorial launch" --platforms ig --out out/2026-09-25/editorial-launch
```

`--platforms` accepts `ig`, `fb`, and `li` as a comma-separated list. The default destination is `out/<date>/`; for a browsable collection, use `out/<date>/<slug>/`. Each generated size lives at `<output>/<platform>/<width>x<height>/` with its image and `post.json`. The generator uses the standard Codex configuration and then invokes `validate.sh`.

The generator intentionally does not pass a model or reasoning override: it uses the standard Codex configuration. Layout, composition, and copy are chosen afresh by Codex on every run inside a consistent Trelew creative system: one concrete message, restrained brand colour, readable Courier Prime typography and real product proof whenever available. Identical briefs may produce different valid sets without becoming visually unrelated. No external image-generation API is used.

Before Codex renders any copy or writes `post.json`, `post.sh` injects the complete repo-local [Unslop skill](skills/unslop/SKILL.md) as a mandatory first editorial pass. It applies to headlines, supporting text, CTA labels, captions, hashtags and any other generated human-readable text. The checked-in copy comes from Cursor's [`pstack/skills/unslop`](https://github.com/cursor/plugins/blob/70b2dc8b4b85c8d5648624ca40d692c421fff32f/pstack/skills/unslop/SKILL.md) at commit `70b2dc8b4b85c8d5648624ca40d692c421fff32f`; `post.sh` stops with an error if that local file is missing.

If a brief cites a gallery reference such as `2026-09-25/runA`, the generator instructs Codex to inspect that run and preserve everything the brief does not ask to change. The reference posts in `reference_posts_from_other_companies/` informed the hierarchy rules, but their brands, copy and layouts must never be copied.

If validation fails, read every printed `FAIL:` line, remove or repair the incomplete output set, and rerun the same command. You can validate independently with:

```sh
./validate.sh out/2026-09-25/editorial-launch --platforms ig,fb,li
```

### Organic Reels

When `ig` or `fb` is requested, `post.sh` now requires a 20-second 1080×1920 MP4 Reel in `<platform>/reel-1080x1920/` as well as the existing static images. The prompt requires a short Trelew service story with real proof, phone-safe typography, sound-off readability and no invented clients, interfaces or results. `validate_reels.py` independently checks the metadata, file structure, exact frame size and duration.

Install the pinned, repo-local MP4 encoder once before generating Instagram or Facebook posts:

```sh
./setup-video-tools.sh
```

The encoder lives in the ignored `.video-venv/` directory. `post.sh` passes its exact path to the creative worker. If it is missing, generation stops before starting Codex instead of placing a renamed image or empty file at the expected path.

## Paid presenter Reels

`ad.sh` creates a 30-second paid-Reel package for Instagram, Facebook or both. It infers Spanish from `/es/` landing pages and English from `/uk/` and `/ie/` pages. Every text field receives the same Unslop first pass as organic posts. The script requires a synthetic adult white male presenter to act only as a presenter, never as a client or testimonial subject.

Create and inspect the script and production prompt without spending video credits:

```sh
./ad.sh \
  --brief "Shopify migration without losing redirects or analytics" \
  --landing-url https://trelew.studio/ie/shopify-migration \
  --platforms ig,fb \
  --out out/ads/2026-09-28/shopify-migration
```

Actual talking-presenter footage requires a video-avatar service. The first supported renderer is [HeyGen's official avatar-video API](https://developers.heygen.com/reference/create-video). Before using it, choose a commercially licensed white male avatar and suitable Spanish and English voices in your own HeyGen account. Provide their IDs and the API key through environment variables; never commit them:

```text
HEYGEN_API_KEY
HEYGEN_WHITE_MALE_AVATAR_ID
HEYGEN_VOICE_ID_ES_ES
HEYGEN_VOICE_ID_EN_GB
HEYGEN_VOICE_ID_EN_IE  # optional; EN_GB is the Ireland fallback
```

Run `./setup-heygen.sh` and paste the replacement API key, licensed avatar ID and voice IDs when prompted. It writes them to the ignored `.env.heygen` file with owner-only permissions; `ad.sh` loads that file automatically. If a key has ever appeared in a tracked or shared file, revoke it in HeyGen before creating the replacement.

After reviewing the generated `ad.json` and `video-prompt.txt`, repeat the command with `--render --use-existing`. The second flag guarantees that Codex does not regenerate the reviewed copy. Rendering makes a paid API request, waits for HeyGen, downloads the source video, and uses the pinned local encoder to finish `ad.mp4` at exactly 30 seconds and 1080×1920. The generated `ad.json` sets `ai_disclosure_review_required` so the campaign operator must review the current platform disclosure requirements before publishing.

## Brand safety

Brand artwork is export-only. Never redraw, trace, simplify, crop, reframe, substitute, stretch, or generatively edit approved artwork. Never modify `src/masters` or run `pnpm refine:symbol`. Approved inputs come exclusively from `../TrelewStuAssets/dist`, which is read-only; assets may only be uniformly scaled and composed into new canvases. `post.sh` pins and verifies TrelewStuAssets commit `354589215ac1a2f1ff0e8e5652d150b79c6a89be` before each run. Every `post.json` records the exact `dist/` sources in `brand_assets`, and the independent validator checks those paths.

Required static canvases are Instagram 1080×1080 and 1080×1920, Facebook 1200×630, and LinkedIn 1200×627 and 1584×396. Organic Instagram and Facebook runs also require a 20-second 1080×1920 Reel.

## Gallery

After each valid generation, `refresh-gallery.py` rebuilds the repository-root `manifest.json` from the post metadata under `out/`. Serve the static gallery from this directory:

```sh
python3 -m http.server 8000
```

Then open `http://127.0.0.1:8000/gallery.html`.

Use the **Filter by run** controls to isolate a generated run. Every card shows a stable reference such as `2026-09-25/runA`; include that value when asking for a revision. Click an image to open its larger preview, or use **Download picture** to save the original file. Selecting a run also updates the URL, so `gallery.html?run=2026-09-25%2FrunA` opens the same filtered view directly. For future named runs, pass a run folder explicitly:

```sh
./post.sh --brief "..." --platforms ig,fb,li --out out/2026-09-27/runC
```

## Ads dashboard

Open `http://127.0.0.1:8000/dashboard.html` from the same local server. The **Results** tab starts with two clearly marked first-launch campaign rows plus twelve recommended creative concepts across the four Trelew landing pages. Edit each row to record its platform, audience, runtime, budget/validation plan, spend, impressions, clicks, qualified inquiries and sales; summary metrics and decision signals update automatically.

The **Launch checklist** tab is a beginner-oriented path from account setup through weekly optimisation. It includes the staged campaign plan derived from `trelew_ad_research_2026.xlsm`, a read-only audit summary of the advertising/tracking support in `../homepage`, and checkable steps with explicit completion criteria.

Dashboard data and checklist progress are saved in the current browser with `localStorage`. Use **Export CSV** for a portable backup of ad results before clearing browser data or switching devices.

## Validator fixtures

`fixtures/pass` is a complete valid Instagram set. `fixtures/broken` deliberately has a wrong-sized image and incomplete metadata, proving that failures are reported and return a non-zero status.
