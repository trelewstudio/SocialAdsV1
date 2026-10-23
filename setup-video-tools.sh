#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/eva/trelew-workspace/TrelewSocialMediaAds"
VIDEO_VENV="$REPO_ROOT/.video-venv"

python3 -m venv "$VIDEO_VENV"
"$VIDEO_VENV/bin/python" -m pip install --disable-pip-version-check \
  --requirement "$REPO_ROOT/requirements-video.txt"
ffmpeg_bin=$("$VIDEO_VENV/bin/python" -c 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())')
"$ffmpeg_bin" -version | sed -n '1p'
echo "PASS: repo-local Reel encoder installed at $ffmpeg_bin"
