#!/bin/bash
set -x
if false; then
  for i in images/fish{1,2}.gif; do
    d="${i/.gif/}"
    mkdir -p "$d"
    ./trans.sh "$i" "$d"
  done
fi
rm images.mem
./ppm2mem.exe images/seabed.ppm images/fish{1,2}/*.ppm
# ./ppm2mem.exe images/seabed.ppm
# mv images.mem background.mem
# ./ppm2mem.exe images/fish{1,2}/*.ppm
