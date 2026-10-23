#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/eva/trelew-workspace/TrelewSocialMediaAds"
CONFIG_FILE="$REPO_ROOT/.env.heygen"

[[ -t 0 ]] || {
  echo "Run this setup from an interactive terminal." >&2
  exit 2
}

if [[ -f "$CONFIG_FILE" ]]; then
  read -r -p ".env.heygen already exists. Replace it? [y/N] " replace
  [[ "$replace" =~ ^[Yy]$ ]] || { echo "No changes made."; exit 0; }
fi

echo "Paste the replacement HeyGen credentials and IDs. Input is saved only in the ignored .env.heygen file."
read -r -s -p "New HeyGen API key: " api_key
echo
read -r -p "Licensed white male avatar ID: " avatar_id
read -r -p "Spain Spanish voice ID: " voice_es
read -r -p "British English voice ID: " voice_gb
read -r -p "Irish English voice ID (press Enter to reuse British): " voice_ie
voice_ie=${voice_ie:-$voice_gb}

for value_name in api_key avatar_id voice_es voice_gb voice_ie; do
  [[ -n "${!value_name}" ]] || { echo "Every required value must be provided." >&2; exit 2; }
done

umask 077
temporary_file=$(mktemp "$REPO_ROOT/.env.heygen.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT
{
  printf 'export HEYGEN_API_KEY=%q\n' "$api_key"
  printf 'export HEYGEN_WHITE_MALE_AVATAR_ID=%q\n' "$avatar_id"
  printf 'export HEYGEN_VOICE_ID_ES_ES=%q\n' "$voice_es"
  printf 'export HEYGEN_VOICE_ID_EN_GB=%q\n' "$voice_gb"
  printf 'export HEYGEN_VOICE_ID_EN_IE=%q\n' "$voice_ie"
} > "$temporary_file"
chmod 600 "$temporary_file"
mv "$temporary_file" "$CONFIG_FILE"
trap - EXIT

echo "PASS: HeyGen settings saved in $CONFIG_FILE with owner-only permissions."
