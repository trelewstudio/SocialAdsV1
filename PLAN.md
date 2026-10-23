# PLAN.md — Trelew Studio Launch: Ads, Outreach & Automation

**Purpose:** executable plan for Codex. Each task has: goal, inputs, exact outputs, verification, and required access.
**Context:** trelew.studio is in final launch. Existing ads were created ad-hoc. This plan builds the asset/skill foundation (tone of voice, image generation, outreach copy), applies it to Instagram/Facebook/LinkedIn, wires it into Hermes, audits existing ads, and closes SEO gaps.
**Working repo for code deliverables:** `/home/eva/trelew-workspace/TrelewSocialMediaAds` (new repo, see T1). It consumes brand assets from the existing `/home/eva/trelew-workspace/TrelewStuAssets` repo — do NOT modify that repo.

---

## Prerequisites & access matrix (check before each task)

| Access | Needed for | Status as of 2026-09-15 | How to obtain |
|---|---|---|---|
| Google Drive/Sheets OAuth (Hermes `google-workspace` skill) | T2 tone doc, T9 Channel Plan sheet | **NOT set up** — no token at `~/.hermes/google_token.json` | Follow `skill_view("google-workspace")` setup steps 2–5 (user creates OAuth client, pastes redirect URL) |
| Browser (Chrome Profile 1 = trelew.studio@gmail.com) | T6 Google Ads + Meta Ads UI review; private Drive links | Chrome runs **without CDP port** — pages can be opened but not read programmatically | Either use Vercel token + APIs where possible, or user exports screenshots/CSVs |
| Vercel token | T7 production checks, analytics | CLI token expires 2026-09-15 05:45 UTC; **needs a long-lived token** from vercel.com/account/tokens | Put in `~/.hermes/.env` as `VERCEL_TOKEN=...` |
| Meta Ads (Marketing API) | T6 real metrics (CTR, spend) | No token on machine | User creates a System User token in Meta Business Suite |
| Google Ads API | T6 real metrics | No token on machine | Dev token + OAuth (boring, official path; read-only) |
| GitHub | T1 repo, PRs | `gh` authenticated as `trelewstudio` | Working |
| Codex CLI | implementation | `codex exec -C <repo> --sandbox workspace-write` | Working |

**Rule for Codex:** any subtask needing browser-UI-only access (Meta/Google Ads consoles) must NOT be faked. If a metric can't be pulled via API, mark it `BLOCKED: needs manual export` and continue with the rest.

---

## T1 — `TrelewSocialMediaAds` repo: social post generator (brand-safe)

**Goal:** given a text brief, produce correctly-sized social images for IG/FB/LinkedIn by composing EXISTING approved Trelew assets — never redrawing brand artwork. Separate from the brand repo.

**Critical context — TrelewStuAssets ALREADY EXISTS** at `/home/eva/trelew-workspace/TrelewStuAssets` (GitHub `trelewstudio/TrelewStuAssets`, private). Codex MUST read its README.md and reuse its concept/outputs; it is the immutable source of brand artwork:
- Approved palette: Deep Teal `#338591`, Warm Cream `#FBF6E8`, Copper Camel `#D4AE8C`, Deep Ink `#122F34` (+ utility black/white). Typeface Courier Prime Regular.
- Forms: heritage badge, sheep isotype, wordmark, horizontal/stacked lockups, Editorial Eye favicons/avatars, Open Graph & social cards (600×315 → 4800×2520).
- `dist/` is committed — use it directly; no build needed to consume.
- **HARD RULE (from its README): export-only operations.** Social-media work may scale approved vectors uniformly and render at declared sizes. It must NEVER redraw, trace, simplify, crop, reframe, substitute, or generatively edit the artwork, and must never touch `src/masters` or run `pnpm refine:symbol`.

**Spec:**
- New repo `trelew-workspace/TrelewSocialMediaAds` (private, GitHub `trelewstudio/TrelewSocialMediaAds`).
- Reference TrelewStuAssets via pinned path/git; copy NOTHING into it except by rendering (keeps one source of truth for brand artwork).
- **Generation model: NON-deterministic, Codex-driven.** The repo's entrypoint is a bash script that delegates the creative work to Codex:
  - `post.sh --brief "..." --platforms ig,fb,li [--out DIR]`
  - It builds a prompt file (brand constraints from TrelewStuAssets README + approved palette/typography + platform size matrix + the T2 voice rules + the brief) and runs `codex exec -C <repo> --sandbox workspace-write --approve-for-me -o /tmp/codex-post-last-message.txt "$(cat prompt.txt)"`.
  - **Codex is the one that creates the image**, the caption, hashtags, CTA link and any per-post assets — choosing layout, composition and copy each run. Two runs with the same brief may legitimately produce different posts.
  - Codex must still work **export-only** on brand artwork: it may compose, scale and place approved `dist/` assets freely, but never redraw/trace/crop/generatively-edit them and never touch `src/masters` (same hard rule as above). Creativity goes into layout, copy and composition — not into the logo geometry.
  - The script then runs a deterministic VALIDATOR (independent of Codex): exact canvas sizes per platform, image opens/decodes, `post.json` schema complete (caption, hashtags, cta_url with UTMs, image path). Failed validation → script exits non-zero so the run can be retried.
  - Model/reasoning: use the standard Codex config (gpt-5.6-sol, low) unless the user says otherwise; no model overrides inside the script.
- Sizes: IG 1080×1080 + 1080×1920; FB 1200×630; LinkedIn 1200×627 + 1584×396.
- Safe zones: assets keep clear margins; isotype/lockup never stretched (uniform scale only).
- Frontend: minimal static `gallery.html` listing generated sets (boring, no framework), serve via `python -m http.server`.
- Hermes skill: `~/.hermes/skills/trelew-social-ads/SKILL.md` documenting usage (how to call `post.sh`, where output lands, how to retry failed validation).
- No external image-gen API in v1 — the creative engine is Codex itself.

**Verification:** run `post.sh` twice with the SAME brief — expect two valid, different-looking post sets (non-determinism proof); validator passes exact dimensions on every file; every visual traces back to an approved `dist/` asset; gallery renders locally.

---

## T2 — Tone-of-voice SKILL.md

**Goal:** single source of truth for all Trelew copy (ads, posts, outreach).

**Spec:**
- Create `~/.hermes/skills/trelew-voice/SKILL.md` (+ `references/` folder).
- **Input doc (Spanish):** https://drive.google.com/file/d/1nynusi353O6o8tTKECVgpfhMoWLOT89Q/view — **needs Google OAuth (prereq) or manual download by user.** Codex should attempt `gapi drive download 1nynusi353O6o8tTKECVgpfhMoWLOT89Q` after OAuth is set up.
- Content of the skill:
  - Voice attributes (from doc + existing brand): direct, resolutive, senior, no fluff; ES + EN variants.
  - Hard rules (mirrors user prefs): no hype words ("revolucionario", "sinergia"), no dash-heavy AI-isms, closing punctuation rules for WhatsApp.
  - Per-channel copy matrix: Instagram / Facebook / LinkedIn / Ads (Google + Meta) / WhatsApp / email — each with: hook style, length caps, CTA conventions, hashtag policy.
  - 5–10 vetted hook templates per channel, each tagged by product line: dashboards/consultorias, editorial, ecommerce, Shopify migration.
- Copy matrix lives in `references/copy-matrix.md` (markdown table), consumed by T3 and T4.

**Verification:** skill loads via `skill_view("trelew-voice")`; contains the ES source doc's rules paraphrased (not the whole doc); matrix covers all 6 channels.

---

## T3 — Outreach message generator (email + WhatsApp)

**Goal:** produce, for each real contact point, a ready-to-send response set.

**Spec:**
- One-shot generation committed as data, not runtime code (a `generate_outreach.py` script is optional; decide after Codex sees the volume).
- Input: `trelew-voice` skill matrix + product lines + typical inbound scenarios:
  1. Inbound page form (hola@trelew.studio) — project enquiry
  2. Inbound WhatsApp (studio number) — project enquiry
  3. Cold outreach email (we initiate)
  4. Cold outreach WhatsApp (we initiate)
  5. Follow-up (no reply, 5–7 days)
  6. Price objection / "how much" first message
- **Output format: markdown table** committed at `TrelewSocialMediaAds/outreach/messages.md` with columns:
  `Contact via | who contacted | for which product | input message sample | automatic output message`
  - ES primary, EN variant column where relevant (WhatsApp closing `?`/`!`, no inverted opening marks per house style).
- Messages must follow T2 voice. Each output ≤ 120 words, one CTA (Calendly link `calendly.com/hola-trelew/30min` or reply-question).

**Verification:** table has ≥ 12 rows covering all 6 scenarios × at least 2 product lines; each message passes the T2 rules checklist.

---

## T4 — First content set: Instagram, Facebook, LinkedIn

**Goal:** 9 posts (3 per platform) using T1 generator + T2 voice.

**Spec:**
- Themes (one set each):
  1. **Proof/demo** — live demos at dashboard/editorial/ecommerce.trelew.studio ("we show it running")
  2. **Data-heavy work** — dashboards for consultorias/ops (Bruma Energy, Cobalto Finance patterns)
  3. **Shopify/migration** — market landing pages (`/es/shopify`, `/ie/shopify-migration`, `/uk/client-reporting-portals`)
- Each post: generated via T1's `post.sh` (Codex-driven, non-deterministic), with caption (per-channel voice + length), image in the right format, CTA to specific landing page with UTM tags.
- UTM convention (mandatory): `utm_source=<platform>&utm_medium=social&utm_campaign=launch<T3-scenario>&utm_content=<slug>`.
- Output: `TrelewSocialMediaAds/posts/2026-09/` with per-platform folders; each post = image files + `post.md` (caption, hashtags, link, schedule slot).

**Verification:** 9 posts, each image correct size for its platform, captions voice-checked, UTMs present and parseable.

---

## T5 — Wire outreach messages into Hermes

**Goal:** Hermes (front-desk + owner profiles) can answer inbound with the vetted messages.

**Spec:**
- Codex edits Hermes config, NOT bridge code:
  - Add reference to `TrelewSocialMediaAds/outreach/messages.md` from the front-desk profile context (path + "use these templates as the base for replies").
  - If a structured store is needed, add `~/.hermes/profiles/front-desk/OUTREACH.md` with the same table (keep SOUL.md persona work untouched — it was carefully built; only append a pointer section).
- Do not auto-send anything. Templates are drafts requiring human send, except front-desk replies which remain under existing admin/approval rules.

**Verification:** front-desk session can quote the correct template when given a sample inbound message; `hermes profile show front-desk` reflects the pointer; no regression in existing SOUL.md content.

---

## T6 — Audit existing Google + Meta ads (keep/kill)

**Goal:** data-driven verdict per campaign/ad.

**Spec:**
- Pull what's pullable:
  - Meta: Ad Library for own page (trelew.studio) for creative/run dates; Marketing API for spend/CTR **if** System User token available — else mark BLOCKED and use UI screenshots from user.
  - Google Ads: API read-only if token available; else export from UI.
- Evaluate per ad: CTR, CPC, spend, conversions (GA4 + Meta pixel data), landing page, message fit vs T2 voice.
- Output: `TrelewSocialMediaAds/ads-audit-2026-09.md` — table: campaign | platform | spend | CTR | conversions | verdict (keep / fix / kill) | reason.
- Kill rules (default): <0.5% CTR after ≥2k impressions → kill or rewrite; no conversions after spend ≥ 2× target CPA → kill; message contradicts T2 voice → rewrite before kill.
- **Do not modify/pause campaigns without showing the user the table first.** This task ends with a recommendation, not unilateral action.

**Verification:** table covers every active campaign found; each verdict cites the specific metric threshold.

---

## T7 — SEO/Ads readiness audit of `homepage` repo

**Goal:** close SEO gaps before paid traffic scales.

**Spec:**
- Codex reads `trelew-workspace/homepage` (branch main) and checks against:
  - Per-page: title, meta description, canonical, OG/Twitter tags, JSON-LD (org, services, FAQ), sitemap.xml, robots.txt, llms.txt presence
  - hreflang for `/es/`, `/ie/`, `/uk/` market pages
  - Ad landing readiness: each campaign target page has matching headline, CTA above fold, form/Calendly, and GA4+Meta pixel events firing (quote request, contact submit, Stripe checkout)
  - Performance budgets already in repo (`npm run audit:production`) must not regress: mobile perf ≥95, LCP <2.5s — **note 2026-09-13 audit failed LCP 2.81s on mobile due to hero badge render delay; fix or document**
- Output: findings as issues/TODO list in `TrelewSocialMediaAds/seo-audit-2026-09.md`; code fixes as PRs to `homepage` (branch `seo/launch-fixes`), separate commits per fix, NO push without user approval.

**Verification:** `npm run audit:production` passes or has documented accepted exceptions; each landing page target passes the checklist.

---

## T8 — Relevance check: Lighthouse & Activepieces

**Goal:** decide if either repo earns a place in the launch stack.

**Spec:**
- **Lighthouse (GoogleChrome/lighthouse):** already used indirectly via `audit-production.mjs` (`npx lighthouse@13.0.3`). Decide: keep as npx dep (recommended) vs vendored. Output: one-paragraph decision in `seo-audit` doc.
- **Activepieces (activepieces/activepieces):** evaluate for (a) automating lead intake → WhatsApp/email notifications, (b) social posting automation. Check: self-host footprint (Docker), MIT community vs EE license split for needed features, MCP server angle for internal tooling. Output: adopt/defer/reject with reasons in `TrelewSocialMediaAds/tooling-notes.md`.
- Constraint: user prefers boring official paths — default Docker install only if adopt; no improvising wrappers.

**Verification:** both decisions written with evidence (license text, resource requirements), not vibes.

---

## T9 — Channel Plan sheet integration

**Goal:** read and reconcile the existing plan with this PLAN.md.

**Spec:**
- Sheet: https://docs.google.com/spreadsheets/d/1zOBIex7VAUjYhETrw48f4A_8xrgba_zt/edit?gid=2109511863#gid=2109511863
- **Needs Google OAuth (prereq).** After setup: `gapi sheets get 1zOBIex7VAUjYhETrw48f4A_8xrgba_zt "Sheet1!A1:Z100"` (adjust range/sheet name after listing sheets).
- Codex: diff the sheet's channel plan against T2/T4 outputs; flag contradictions; update THIS PLAN.md with a "Reconciliation" section listing: what the sheet says, what this plan says, and the merged decision (user decides conflicts).
- If sheet is private and OAuth isn't set up: BLOCKED — ask user to export as CSV into `TrelewSocialMediaAds/inputs/channel-plan.csv`.

**Verification:** reconciliation section exists with per-channel merge status; no silent conflicts ignored.

---

## Execution order & dependencies

```
T2 (voice) ──► T3 (outreach) ──► T5 (Hermes wiring)
   │
   └──► T4 (posts) ── needs T1 (assets)
T1 (assets repo) ──► T4
T6, T7 independent — start anytime; T6 partly BLOCKED on Meta/Google tokens
T8 independent
T9 after OAuth setup
```

Suggested Codex batches (each = one `codex exec` run in the right repo):
1. T1 repo scaffold + generator + gallery (repo: TrelewSocialMediaAds; TrelewStuAssets read-only)
2. T2 skill (repo: TrelewSocialMediaAds for source data + hermes skills dir)
3. T3 outreach table
4. T4 content set
5. T7 audit + fix PRs (repo: homepage)
6. T6 + T8 + T9 analysis docs

**Standing rules for all Codex runs:**
- KISS/Pareto: smallest thing that works; no frameworks, no wrappers around official CLIs.
- Verify claims: every "done" needs a real artifact (file, test output, API response).
- Secrets: read from `~/.hermes/.env` only; never in chat, never in repo.
- Push/commit only what the task names; ask before pushing to `homepage`.
- Anything needing the user's Chrome UI or private credentials → mark `BLOCKED: needs manual step`, report, move on.
