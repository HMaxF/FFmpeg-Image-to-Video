#!/bin/bash
# zoomin_full_to_xy.sh

set -e # Exit immediately if a command exits with a non-zero status.

# Check if exactly 1 argument are provided
if [ "$#" -lt 1 ]; then
    echo "--------------"
    echo "Usage: $0 [filename wildcard]" # [per-image duration]"
    echo "example:"
    echo "$0 \"MyPhoto*.jpg\" \"hariyantoandfriends\""
    exit 1
fi

# Assign the arguments to variables
image_file_wild_card=$1
echo "Image file wildcard: $image_file_wild_card"

images_file_data=()
total_image_files=0

# iterate all files matching the wildcard
for filename in $(ls -v $image_file_wild_card); do

    # find image width and height
    IFS=',' read image_width image_height < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$filename")

    # add filename, width, and height to the array
    images_file_data+=("$filename,$image_width,$image_height")

    total_image_files=$((total_image_files + 1))
    echo "$total_image_files. $filename: ${image_width}x${image_height}"

done

# display total image files
echo "Total image files found: $total_image_files"
if [ $total_image_files -lt 1 ]; then
  echo "No image files found matching wildcard '$image_file_wild_card'."
  exit 1
fi

# use large resolution video output for all Social Media
# eg: Instagram ==> 2:3 (portrait)
video_width=1440
video_height=2160 

# 4K - 16:9 (landscape)
video_width=3840 # 3840 for 4K video
video_height=2160 # 2160 for 4K video

# NOTE: any image resolution is allowed, if input image is smaller than video size then it will be pixelated but okay.

# --- Video Dimensions == will be used as zoom scale ---
# NOTE: the output video size DOES NOT need to be the same RATIO as input image size
video_resolution="${video_width}x${video_height}"
echo "Output video resolution: $video_resolution"

# Get command-line arguments
target_cx=-1 # "${2:--1}"  # Default to -1 (NOTE: --1 ==> -1) if not provided
target_cy=-1 # "${3:--1}"  # Default to -1 if not provided

# Show what was passed or defaulted
echo "Target center x: $target_cx, y: $target_cy"

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
DUR=4
FPS=30 
total_frames=$(echo "$DUR * $FPS" | bc)
fade_duration=0.5    # duration of fade-in and fade-out transition for each video (in seconds)
# $fade_duration will be inside $DUR !

vignette=PI/6 # PI/4 (darker) # default value == PI/5 (dark)

# iterate all images and prepare inputs for ffmpeg
inputs=""
fc="" # filter_complex
counter=0
last_map=""
concat_inputs=""
for file_data in "${images_file_data[@]}"; do

    if [[ $counter -eq $((total_image_files - 1)) ]]; then
      # last image, add extra duration
      DUR=$((DUR + 2)) # add 2 more seconds to display with SLOW fade-out 2 seconds
    fi

    # extract the file data to variables
    IFS=',' read filename original_image_width original_image_height <<< "$file_data"
          
    inputs+="-loop 1 -t $DUR -i $filename " # note the space at the end of this line

    zoom_start=1.0 # initial zoom (original size)
    zoom_end=1.2 # 20% zoomed in ==> NOTE: adjust this value to zoom in more or less
    zoom_speed=$(printf "%.4f" $(echo "($zoom_end - $zoom_start)/$total_frames" | bc -l)) # variable zoom speed

    # calculate the zoom level for each frame
    # this 'zoom' value will determine the viewport size (original image size / zoom)
    zoom_expr="min($zoom_end, $zoom_start + (on*$zoom_speed))"


    # zoom in to specified center point (target_cx, target_cy)
    #zoompan=z='min(zoom_end, 1+on*zoom_speed)':x='target_cx - iw/zoom/2':y='target_cy - ih/zoom/2'

    # center x,y to zoom into ==> NOTE: adjust here if we want to zoom in to a specific point of the output video resolution (not the original image resolution)
    # target_cx=1000
    # target_cy=1000
    target_cx=$(echo "$video_width / 2" | bc)
    target_cy=$(echo "$video_height / 2" | bc)

    # calculate the x and y position for each frame (zoom_expr is related to frame number)
    x_expr="$target_cx - ((iw/zoom)/2)"
    y_expr="$target_cy - ((ih/zoom)/2)"
    
    fc+="[$counter:v]scale=w=$video_width:h=$video_height:force_original_aspect_ratio=decrease" #scale down IF too large
    fc+=",pad=$video_width:$video_height:(ow-iw)/2:(oh-ih)/2:color=black" # fill remaining space with black background
    fc+=",setsar=1" # make sure the sample aspect ratio is 1:1 --> to avoid error
    fc+=",zoompan=z='$zoom_expr':x='$x_expr':y='$y_expr':s=$video_resolution"
    fc+=",fps=$FPS"
    fc+=",vignette=$vignette"
    fc+=",fade=t=in:st=0:d=$fade_duration"

    if [[ $counter -eq $((total_image_files - 1)) ]]; then
      # last image, set longer fade-out duration
      fade_duration=2 # 2 seconds fade-out duration
      DUR=$((DUR + 2)) # add 2 more seconds to display with SLOW fade-out 2 seconds
    fi

    fc+=",fade=t=out:st=$(echo "$DUR-$fade_duration" | bc):d=$fade_duration"

    fc+=",trim=duration=$DUR[v$counter];" # use trim=duration to set exact limit time
    # note the ';' at the end of each filter

    concat_inputs+="[v$counter]"

    last_map="[v$counter]" # last map for the next iteration

    counter=$((counter + 1))
done

# finalize the concat_inputs
concat_inputs="${concat_inputs}concat=n=${counter}:v=1:a=0[outv]"

last_map="[outv]" # last map for the next iteration

# add concat_inputs to the filter_complex
fc+="$concat_inputs"

# Remove only the trailing semicolon (if any, no error if not present)
fc="${fc%;}"


cli=(ffmpeg -hide_banner -loglevel error 
    $inputs    
    -filter_complex "$fc"
    -map "$last_map"
    -c:v libx264 
    -r $FPS 
    -s $video_resolution 
    -pix_fmt yuv420p 
    -preset ultrafast 
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

