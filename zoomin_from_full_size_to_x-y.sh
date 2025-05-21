#!/bin/bash
# zoomin_from_full_size_to_x-y.sh

set -e # Exit immediately if a command exits with a non-zero status.


# NOTES:
# 1. IF the original image RATIO is different from the output video RATIO, the image will be stretched
# 2. SO need to resize the input image to use the same RATIO, maybe add padding to top+bottom or left+right

# Get command-line arguments
image_input="$1"
target_cx="${2:--1}"  # Default to 0 if not provided
target_cy="${3:--1}"  # Default to 0 if not provided

# Show what was passed or defaulted
echo "Image file: $image_input"
echo "Target center x: $target_cx"
echo "Target center y: $target_cy"


if [ -z "$image_input" ]; then
    echo "Error: No input image file provided."
    echo "Usage: $0 <image_input>"
    exit 1
fi

if [ ! -f "$image_input" ]; then
    echo "Error: Input file '$image_input' does not exist or is not a regular file."
    exit 1
fi

# Get the original image resolution --> this is works for all versions of ffprobe
IFS=',' read original_image_width original_image_height < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$image_input")
echo "Original image resolution (w*h): $original_image_width * $original_image_height"


# --- Video Dimensions == will be used as zoom scale ---
# NOTE: the output video size DOES NOT need to be the same RATIO as input image size
video_width=1920 
video_height=1080 
video_resolution="${video_width}x${video_height}"
echo "Output video resolution: $video_resolution"

#=========== check ratio ================

# Compute original and target aspect ratios
orig_ratio=$(echo "scale=6; $original_image_width / $original_image_height" | bc -l)
video_ratio=$(echo "scale=6; $video_width / $video_height" | bc -l)

echo "Original image aspect ratio: $orig_ratio"
echo "Target video aspect ratio: $video_ratio"

if (( $(echo "$orig_ratio != $video_ratio" | bc -l) )); then  
    echo "Aspect ratio does not match. Padding will be added."

    # Helper: round up to even number
    make_even() {
        local val=$1
        echo $(( (val + 1) / 2 * 2 ))
    }

    # Extract filename components
    filename="${image_input##*/}"
    basename="${filename%.*}"
    extension="${filename##*.}"
    padded_image="${basename}_padded.${extension}"

    if (( $(echo "$orig_ratio > $video_ratio" | bc -l) )); then
        echo "Image is too wide – adding padding to top and bottom"

        new_height=$(echo "$original_image_width / $video_ratio" | bc -l)
        new_height_rounded=$(printf "%.0f" "$new_height")
        new_height_even=$(make_even "$new_height_rounded")
        original_width_even=$(make_even "$original_image_width")

        echo "Calculated new height: $new_height → rounded and even: $new_height_even"
        echo "Adjusted width to even: $original_width_even"

        ffmpeg -hide_banner -loglevel error -i "$image_input" \
        -vf "pad=width=$original_width_even:height=$new_height_even:x=0:y=(oh-ih)/2:color=black" \
        -q:v 2 "$padded_image"

    elif (( $(echo "$orig_ratio < $video_ratio" | bc -l) )); then
        echo "Image is too tall – adding padding to left and right"

        new_width=$(echo "$original_image_height * $video_ratio" | bc -l)
        new_width_rounded=$(printf "%.0f" "$new_width")
        new_width_even=$(make_even "$new_width_rounded")
        original_height_even=$(make_even "$original_image_height")

        echo "Calculated new width: $new_width → rounded and even: $new_width_even"
        echo "Adjusted height to even: $original_height_even"

        ffmpeg -hide_banner -loglevel error -i "$image_input" \
        -vf "pad=width=$new_width_even:height=$original_height_even:x=(ow-iw)/2:y=0:color=black" \
        -q:v 2 "$padded_image"
    fi

    image_input="$padded_image"

    IFS=',' read original_image_width original_image_height < <(
        ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height -of csv=p=0 "$image_input"
    )
    echo "Recalculated image resolution (w*h): $original_image_width * $original_image_height"
fi


# ========== end of check ratio ==========

# Check if the output file exists and modify the name if it does
video_output_filename="output.mp4"
found_file=1
base_video_output_file="${video_output_filename%.*}"

while [[ -f "$video_output_filename" ]]; do    
    echo "'$video_output_filename' is already exists, use new name '${base_video_output_file}-${found_file}.mp4'"
    video_output_filename="${base_video_output_file}-${found_file}.mp4"
    ((found_file++))
done



# --- Duration and FPS ---
DUR=5
FPS=30 
total_frames=$(echo "$DUR * $FPS" | bc)


# --- Target center point to Zoom-In ---
# These are the coordinates in the ORIGINAL IMAGE that you want to zoom into
# and keep centered in the output video frame.

# target ==> user defined CENTER POINT in the original image size (not scaled)
# FFMPEG will automatically scale the image to fit the video size

if [[ "$target_cx" == "-1" ]]; then
    # default to center of the image
    target_cx=$(echo "$original_image_width / 2" | bc)
fi
if [[ "$target_cy" == "-1" ]]; then
    # default to center of the image
    target_cy=$(echo "$original_image_height / 2" | bc)
fi

# target_cx=5239
# target_cy=2246

# # values outside the image or negative values are not a problem (good)
# target_cx=7100
# target_cy=-10

# # center of the image
# target_cx=$original_image_width/2
# target_cy=$original_image_height/2

echo "Target point (x,y): ($target_cx * $target_cy)"


# choose the lowest zoom level to fit the entire image into the output frame
zoom_w=$(echo "$original_image_width / $video_width" | bc -l)
zoom_h=$(echo "$original_image_height / $video_height" | bc -l)
zoom_end=$(printf "%.1f" $(echo "if ($zoom_w < $zoom_h) $zoom_w else $zoom_h" | bc -l))

# hard coded zoom level
#zoom_end=1.2 # 20%

zoom_speed=$(printf "%.7f" $(echo "($zoom_end - 1.0)/$total_frames" | bc -l))
echo "Zoom end: $zoom_end, Zoom speed: $zoom_speed"

# zoom in to specified center point (target_cx, target_cy)
#zoompan=z='min(zoom_end, 1+on*zoom_speed)':x='target_cx - iw/zoom/2':y='target_cy - ih/zoom/2'

# calculate the zoom level for each frame
# this 'zoom' value will determine the viewport size (original image size / zoom)
zoom_expr="min($zoom_end, 1.0 + (on*$zoom_speed))"

# calculate the x and y position for each frame (zoom_expr is related to frame number)
x_expr="$target_cx - ((iw/zoom)/2)"
y_expr="$target_cy - ((ih/zoom)/2)"

# # DEBUGGING to see how the values are changing    
# for ((on=0; on<total_frames; on++)); do
#     # NOTE: x and y values could be negative --> not a problem
#     zoom=$(echo "scale=4; z = 1.0 + $on * $zoom_speed; if ($zoom_end < z) $zoom_end else z" | bc -l)

#     w=$(echo "scale=2; $original_image_width / $zoom" | bc -l)
#     h=$(echo "scale=2; $original_image_height / $zoom" | bc -l)

#     x=$(echo "scale=2; $target_cx - ($w / 2)" | bc -l)
#     y=$(echo "scale=2; $target_cy - ($h / 2)" | bc -l)

#     echo "on: $on, zoom: $zoom, x: $x, y: $y, w: $w, h: $h"
# done

cli=(ffmpeg -hide_banner -loglevel error \
    -loop 1 -t $DUR -i "$image_input" \
    -filter_complex "[0:v]zoompan=z='$zoom_expr':x='$x_expr':y='$y_expr',fps=$FPS,trim=duration=$DUR[v0]" \
    -map "[v0]" \
    -c:v libx264 \
    -r $FPS \
    -s $video_resolution \
    -pix_fmt yuv420p \
    -preset ultrafast \
    $video_output_filename
)
echo "**** going to run *********"
echo "${cli[@]}"
echo "*************************"

"${cli[@]}"
if [[ $? -ne 0 ]]; then
    echo "Error: ffmpeg command failed."
    exit 1
fi

echo "Output video saved as $video_output_filename"

