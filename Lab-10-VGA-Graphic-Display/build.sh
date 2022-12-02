#!/bin/bash
set -x
for i in images/fish*.gif; do
  d="${i/.gif/}"
  mkdir -p "$d"
  ./trans.sh "$i" "$d"
done
rm images.mem
./ppm2mem.exe images/seabed.ppm images/fish*/*.ppm
