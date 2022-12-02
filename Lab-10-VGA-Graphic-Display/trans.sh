#!/bin/bash
ffmpeg -y -hide_banner -loglevel panic \
  -i "$1" -fps_mode drop "$2/%d.png"
for f in "$2"/*.png; do
  python tran2green.py "$f"
done
