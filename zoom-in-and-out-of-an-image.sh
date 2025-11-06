#!/bin/bash

# Check if parameter is provided
if [ -z "$1" ]; then
  echo "Usage: $0 [image.jpg]"
  echo "Example: $0 myimage.jpg"
  exit 1
fi

# check if the file exists
if [ ! -e "$1" ]; then
  echo "Error: File $1 does not exist."
  exit 1
fi

input="$1"
# get absolute path of input file
#input="$(realpath -- "$1")"

# define video output filename using the same name as input image
output="${1%.*}_zooming.mp4"

# if output file already exists then add a number suffix to avoid overwriting
if [ -e "$output" ]; then
  suffix=1
  while :; do
    output="${1%.*}_zooming_${suffix}.mp4"
    if [ ! -e "$output" ]; then
      break
    fi
    suffix=$((suffix + 1))
  done
fi

# IMPORTANT NOTES:
# 1. Avoid using 'scale' and 'crop' inside 'zoompan' because too slow, so pre-scale the image first.
# 2. '-color_range 2' is required to ensure full range color (0-255) [high quality] instead of limited range (16-235) for yuv420p videos.
# 3. 'zoompan=z=...:fps=${fps}' is important to set proper framerate, otherwise default is 25 !!

video_width=1080
video_height=1920
video_resolution="${video_width}x${video_height}"
echo "Video resolution: $video_resolution"


# ====== to avoid JITTERY during zoom-in/out, make sure using HIGHER RESOLUTION image than VIDEO RESOLUTION, also keep ASPECT RATIO ======
# 1st pass: to avoid scalling and cropping every frame, we scale it once here 
# tried to use png to avoid quality loss, BUT it is much larger in size (not worth it)
# use webp 95% to reduce size with minimal quality loss (should be smaller filesize than the input jpg but same quality visually)
temp_scaled_image="_temp_scaled_$(basename "${input%.*}").webp"

# Create scaled image with the same aspect ratio of the target video resolution
# NOTES:
# 1. escape the comma in the pad filter to avoid bash error
# 2. keep WIDTH constant and scale HEIGHT accordingly to maintain aspect ratio, then pad HEIGHT to fit video resolution (black bars on top and bottom)
ffmpeg -hide_banner -y -i "$input" -vf "scale=iw:-1,pad=iw:(iw*${video_height}/${video_width}):0:(ow-ih)/2:black" -q:v 95 "$temp_scaled_image"
#============


fps=30 # frames per second

zooming_in_duration=3     # seconds of ZOOMING-IN only 
zooming_in_frames=$(echo "$fps * $zooming_in_duration" | bc)

DUR=$((zooming_in_duration * 2)) # total video duration in seconds of TOTAL CYCLE (zooming-in + zooming-out)

total_frames=$(echo "$fps * $DUR" | bc)

# use zoom start and end, because we use PRE-SCALED image "temp_scaled_image"
video_zoom_in_start=1.0
video_zoom_in_end=1.3 # zoom in to 130%
zoom_diff=$(echo "$video_zoom_in_end - $video_zoom_in_start" | bc -l)

#zooming_in_speed=$(echo "$zoom_diff/$zooming_in_frames" | bc -l) # use HIGHER PRECISION for more accurate speed value per frame 
zooming_in_speed=$(printf "%.4f" $(echo "$zoom_diff/$zooming_in_frames" | bc -l)) # reduce PRECISION to 4 decimal places to fasten ffmpeg processing (is it faster???)

# Build zoom expression
# NOTE: 'on' start from 0 to (total_frames - 1)

# using only $video_zoom_in_start (without $video_zoom_in_end)
# zoom_expr="if(lt(on,$zooming_in_frames),
#   $video_zoom_in_start + (on * $zooming_in_speed),
#   $video_zoom_in_start + (($((total_frames-1)) - on) * $zooming_in_speed)
# )"

zoom_expr="if(lt(on,$zooming_in_frames),
  $video_zoom_in_start + (on * $zooming_in_speed),
  $video_zoom_in_end - ((on - $zooming_in_frames) * $zooming_in_speed)
)"

SIMULATION=0
if [ "$SIMULATION" -eq 1 ]; then
  echo "🔍 Simulating zoom values for each frame..."
  # ====== SIMULATION ======
  for ((on=0; on<=total_frames; on++)); do
    if (( on <= zooming_in_frames )); then
      zoom=$(echo "$video_zoom_in_start + ($on * $zooming_in_speed)" | bc -l)
    else
      zoom=$(echo "$video_zoom_in_start + ((($total_frames - 1) - $on) * $zooming_in_speed)" | bc -l)
    fi
    printf "Frame %3d → Zoom = %.6f\n" "$on" "$zoom"
  done

  # NOTES: simulation is CORRECTLY show the 'zoom value' from 1.0 and back to 1.0 .. BUT ffmpeg failed to produce the correct zoom effect
  echo "✅ Simulation completed."

  exit 4
fi

# ======== DEBUG INFO ========
echo "---- DEBUG INFO ----"
echo "Input image filename: $input"
echo "Temp scaled image: $temp_scaled_image"
echo "FPS: $fps"
echo "Video size: ${video_width}x${video_height}"
echo "Zoom range: $video_zoom_in_start → $video_zoom_in_end"
echo "Zoom difference: $zoom_diff"
echo "Zooming-in speed: $zooming_in_speed (per frame)"
echo "Zoom expression: $zoom_expr"
echo "Output video filename: $output"
echo "Output video duration: $DUR (seconds)"
echo "--------------------"

# scale=${video_width}*${scale_factor}:${video_height}*${scale_factor}:force_original_aspect_ratio=increase,\
# crop=${video_width}*${scale_factor}:${video_height}*${scale_factor},\

# 2nd pass: create video with zoom-in and zoom-out effect (without scaling and cropping every frame)
# NOTE: separate each field by ':' (not by ','), previously encountered problem when mixing 's=..,fps=..' in the same filter chain, the 'fps=..' is IGNORED silently by ffmpeg !!
# ======== FFmpeg Command ========
ffmpeg -hide_banner -loop 1 -t $DUR -i "$temp_scaled_image" -filter_complex "\
zoompan=z='${zoom_expr}':\
x='(iw-(iw/zoom))/2':\
y='(ih-(ih/zoom))/2':\
d=1:\
s=${video_width}x${video_height}:\
fps=${fps}
" -c:v libx264 -color_range 2 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart "$output"

echo "✅ Output video saved to: $output"

# Clean up temporary files
rm -f "$temp_scaled_image"