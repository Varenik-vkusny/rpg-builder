#!/usr/bin/env bash
# Склейка кадров build/video/<имя>/ в build/video/<имя>.mp4 (30 кадров в секунду, H.264).
set -e
cd "$(dirname "$0")/.."
name="$1"
[ -d "build/video/$name" ] || { echo "нет кадров build/video/$name"; exit 1; }
ffmpeg -y -loglevel error -framerate 30 -i "build/video/$name/f%05d.png" \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
  "build/video/$name.mp4"
ls -la "build/video/$name.mp4"
