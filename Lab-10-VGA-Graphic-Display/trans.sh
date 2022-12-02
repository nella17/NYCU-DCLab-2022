#!/bin/bash
ffmpeg -y -hide_banner -loglevel panic \
  -i "$1" -fps_mode drop "$2/%d.png"
for i in "$2"/*; do
  ffmpeg -y -hide_banner -loglevel panic \
    -f lavfi -i color=00FF00 -i "$i" \
    -filter_complex "[0][1]scale2ref[bg][gif];[bg]setsar=1[bg];[bg][gif]overlay=shortest=1" "${i/png/ppm}"
done
