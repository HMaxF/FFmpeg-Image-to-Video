#!/bin/bash

# Check if parameter is provided
if [ -z "$1" ]; then
  echo "Usage: $0 \"pattern\""
  echo "Example: $0 \"DSC*.JPG\""
  exit 1
fi

# Iterate over files matching the pattern
for img in $1; do
  # Skip if no file matches the pattern
  [ -e "$img" ] || continue

  # check if the same filename with .webp already exists
  if [ -e "${img%.*}.webp" ]; then
    echo "*** Skipping $img, ${img%.*}.webp already exists."
    continue
  fi

  # Extract filename without extension
  filename="${img%.*}"

  # tried ffmpeg but it does not keep metadata
  # tried cwebp because FASTER and keep the metadata too BUT it does NOT handle orientation correctly
  #cwebp -metadata all -q 95 "$img" -o "${filename}.webp"

  # use ImageMagick to convert to webp, it will KEEP the metadata and handle orientation correctly
  # $ magick -version
  # Version: ImageMagick 7.1.1-47 Q16-HDRI x86_64 22763 https://imagemagick.org
  # Copyright: (C) 1999 ImageMagick Studio LLC
  # License: https://imagemagick.org/script/license.php
  # Features: Cipher DPC HDRI Modules OpenMP(4.5) 
  # Delegates (built-in): bzlib cairo djvu fftw fontconfig freetype gslib gvc heic jbig jng jp2 jpeg jxl lcms lqr ltdl lzma openexr pangocairo png ps raqm raw rsvg tiff webp wmf x xml zip zlib zstd
  # Compiler: gcc (14.2)

  # quality=80
  # magick "$img" -auto-orient -quality "$quality" "${filename}_${quality}.webp"

  # quality=85
  # magick "$img" -auto-orient -quality "$quality" "${filename}_${quality}.webp"

  # quality=90
  # magick "$img" -auto-orient -quality "$quality" "${filename}_${quality}.webp"

  # quality=100
  # the output webp file is BIGGER THAN the JPG filesize and not worth it.

  # NOTES:
  # 1. After testing 80/85/90/95/100, using visual inspection, I found 95% is equal to origin JPG (4000x6000 pixel from Sony ZV E10)
  # 2. Using 90% is close but losing some details that ONLY visible in 500% zoom-in.
  # quality=95
  # magick "$img" -auto-orient -quality "$quality" "${filename}_${quality}.webp"
  magick "$img" -auto-orient -quality 95 "${filename}.webp"

  #NOTE: output "${filename}.webp" is stored in current active directory

  # print the filesize comparison
  original_size=$(stat -c%s "$img")
  webp_size=$(stat -c%s "${filename}.webp")
  reduction_in_percent=$((100 * (original_size - webp_size) / original_size))

  # format the number with commas
  original_size=$(printf "%'d" "$original_size")
  webp_size=$(printf "%'d" "$webp_size")

  echo "Converted $img ($original_size bytes) -> $filename.webp ($webp_size bytes) -> Reduction: $reduction_in_percent%"

done

