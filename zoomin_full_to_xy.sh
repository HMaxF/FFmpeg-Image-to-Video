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

time_start=$(date +%s)

# Assign the arguments to variables
image_file_wild_card=$1
echo "Image file wildcard: $image_file_wild_card"

images_file_data=()
total_image_files=0

# iterate all files matching the wildcard
for filename in $(ls -v $image_file_wild_card); do

    # find image width and height (WARNING: pay attention to image rotation, it looks vertical but actually horizontal)
    IFS=',' read image_width image_height < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$filename")

    # add filename, width, and height to the array
    images_file_data+=("$filename,$image_width,$image_height")

    total_image_files=$((total_image_files + 1))
    echo "$total_image_files. $filename: ${image_width} x ${image_height}"

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
#video_width=3840 # 3840 for 4K video
#video_height=2160 # 2160 for 4K video

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
# fade_in_duration=0.5    # duration of fade-in and fade-out transition for each video (in seconds)
# fade_out_duration=0.5    # duration of fade-in and fade-out transition for each video (in seconds)
# $fade_duration will be inside $DUR !

vignette=PI/5 # PI/4 (darker) # default value == PI/5 (dark)

# iterate all images and prepare inputs for ffmpeg
inputs=""
fc="" # filter_complex
counter=0
last_map=""
concat_inputs=""


for file_data in "${images_file_data[@]}"; do

    # # stop if $counter == 5
    # if [[ $counter -ge 5 ]]; then
    #     echo "Reached maximum of 5 images, stopping."
    #     break
    # fi

    # extract the file data to variables
    IFS=',' read filename original_image_width original_image_height <<< "$file_data"

    if [[ $counter -eq $((total_image_files - 1)) ]]; then
      # last image, add extra duration
      DUR=$((DUR + 2)) # add 2 more seconds to display with SLOW fade-out 2 seconds
    fi
          
    inputs+="-loop 1 -t $DUR -i $filename " # note the space at the end of this line

    zoom_start=1.0 # initial zoom (original size)
    zoom_end=1.2 # 20% zoomed in ==> NOTE: adjust this value to zoom in more or less
    zoom_speed=$(printf "%.4f" $(echo "($zoom_end - $zoom_start)/$total_frames" | bc -l)) # variable zoom speed

    # calculate the zoom level for each frame
    # this 'zoom' value will determine the viewport size (original image size / zoom)
    zoom_expr="min($zoom_end, $zoom_start + (on*$zoom_speed))" # default is zooming in (except the last image)

    # zoom in to specified center point (target_cx, target_cy)
  
    # center x,y to zoom into ==> NOTE: adjust here if we want to zoom in to a specific point of the original image resolution (not video resolution)
    target_cx=$(echo "$original_image_width / 2" | bc)
    target_cy=$(echo "$original_image_height / 2" | bc)

    # calculate the x and y position for each frame (zoom_expr is related to frame number)
    x_expr="$target_cx - ((iw/zoom)/2)"
    y_expr="$target_cy - ((ih/zoom)/2)"

    # NOTE: found that using 'scale' and 'pad' cause jittery zoom effect, so we use 'setsar' (to avoid error) and 'zoompan' only

    fc+="[$counter:v]"
    #fc+="scale=w=$video_width:h=$video_height:force_original_aspect_ratio=decrease" #scale down IF too large    
    #fc+="scale=8000:-1"
    #fc+=",pad=$video_width:$video_height:(ow-iw)/2:(oh-ih)/2:color=black" # fill remaining space with black background
    fc+="setsar=1" # important to make sure the pixel ratio is --> to avoid error
    #fc+="zoompan=z='$zoom_expr':x='$x_expr':y='$y_expr':d=1:s=$video_resolution"
    
    
    #NOTE: first image does not need fade-in, last image needs longer fade-out
    if [[ $counter -eq 0 ]]; then
        # first image, no fade-in
        fade_in_duration=0 # no fade-in for the first image
        fade_out_duration=0.5
    elif [[ $counter -eq $((total_image_files - 1)) ]]; then
        # last image
        fade_in_duration=0.5

        # set longer fade-out duration
        fade_out_duration=2 # 2 seconds fade-out duration
        
        # zooming-in (enlarge) instead of zooming-out
        # redefine the zoom_expr to zoom in to the last image        
        #zoom_expr="max($zoom_end, $zoom_start - (on*$zoom_speed))"
        zoom_expr="max($zoom_start, $zoom_end - (on*$zoom_speed))"
        # x_expr="iw/2-(iw/zoom/2)"
        # y_expr="ih/2-(ih/zoom/2)"
    else 
        # middle images, fade-in and fade-out
        fade_in_duration=0.5
        fade_out_duration=0.5
    fi

    fc+=",zoompan=z='$zoom_expr':x='$x_expr':y='$y_expr':s=$video_resolution"
    fc+=",fps=$FPS"
    fc+=",vignette=$vignette"
    
    # check to see if fade_in_duration > 0
    #if [[ $fade_in_duration -gt 0 ]]; then # compare integer
    if (( $(echo "$fade_in_duration > 0" | bc -l) )); then # compare floating-point number
        fc+=",fade=t=in:st=0:d=$fade_in_duration"
    fi
    fc+=",fade=t=out:st=$(echo "$DUR-$fade_out_duration" | bc):d=$fade_out_duration"

    # add trim filter to limit the duration of each video segment
    fc+=",trim=duration=$DUR[v$counter];" # use trim=duration to set exact limit time
    # note the ';' at the end of each filter

    concat_inputs+="[v$counter]"

    last_map="[v$counter]" # last map for the next iteration

    counter=$((counter + 1))
done

# finalize the concat_inputs
concat_inputs="${concat_inputs}concat=n=${counter}:v=1:a=0[outv];"

last_map="[outv]" # last map for the next iteration

# add concat_inputs to the filter_complex
fc+="$concat_inputs"

# add watermark text to the video
watermark_text="hariyantoandfriends"
if [[ -n "$watermark_text" && ${#watermark_text} -gt 1 ]]; then

  font_file="MonsieurLaDoulaise-Regular.ttf"
  font="Times New Roman" #Segoe Script" 

  # use font_file as signature on the bottom CENTER side

  # because video resolution large (eg: 1440x2160) then use larger font size (48 -> 64)
  fc+="$last_map drawtext=text='$watermark_text'"
  fc+=":fontfile='$font_file'"
  fc+=":fontcolor=white"
  fc+=":fontsize=64"
  fc+=":x=(w-text_w)/2:y=h-text_h-20[text_watermarked];"
  
  last_map="[text_watermarked]" # update last_map to the watermarked video
fi

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

# execute ffmpeg command
"${cli[@]}"

time_end=$(date +%s)
time_elapsed=$((time_end - time_start))
echo "Time elapsed: ${time_elapsed} seconds"


if [[ $? -ne 0 ]]; then
    echo "Error: ffmpeg command failed."
    exit 1
fi


echo "Output video saved as $video_output_filename"