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

gcd() {
    local a=$1 b=$2
    while [ "$b" -ne 0 ]; do
        local temp=$b
        b=$((a % b))
        a=$temp
    done
    echo "$a"
}


# iterate all files matching the wildcard
for filename in $(ls -v $image_file_wild_card); do

    # DEBUGGING: stop if $counter == 5
    # if [[ $total_image_files -ge 4 ]]; then
    #     echo "Reached maximum of 4 images, stopping."
    #     break
    # fi

    # find image width and height (WARNING: pay attention to image rotation, it looks vertical but actually horizontal)
    IFS=',' read image_width image_height < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$filename")

    # add filename, width, and height to the array
    images_file_data+=("$filename,$image_width,$image_height")

    gcd_val=$(gcd "$image_width" "$image_height")
    if [ "$gcd_val" -le 2 ]; then # less than or equal to 2
        # no common divisor
        if (( image_width > image_height )); then
            ratio=$(awk "BEGIN { printf \"%.1f\", $image_height / $image_width }")
            aspect_w=1
            aspect_h=$ratio
        elif (( image_height > image_width )); then
            ratio=$(awk "BEGIN { printf \"%.1f\", $image_width / $image_height }")
            aspect_w=$ratio
            aspect_h=1            
        else
            aspect_w=1
            aspect_h=1
        fi
    else
        aspect_w=$((image_width / gcd_val))
        aspect_h=$((image_height / gcd_val))
    fi
    
    total_image_files=$((total_image_files + 1))
    echo "$total_image_files. $filename: ${image_width} x ${image_height} (Aspect ratio $aspect_w:$aspect_h)"

done

# display total image files
echo "Total image files found: $total_image_files"
if [ $total_image_files -lt 1 ]; then
  echo "No image files found matching wildcard '$image_file_wild_card'."
  exit 1
fi

# use large resolution video output for all Social Media
# eg: Instagram ==> 2:3 (portrait)
# video_width=1440
# video_height=2160 

# 4K - 16:9 (landscape) -- if images are 3:2 (landscape) then it will show black bars on the sides.
video_width=1440 # 3840 # 3840 for 4K video
# video_width=3240 # 3240 (less than 4K) to maintain 3:2 aspect of photos
video_height=2160 # 3740x2160 == 16:9 4K video, 3240x2160 == 3:2 aspect ratio (landscape)
#video_height=2560 # for 4K+ video with 3:2 aspect ratio (landscape) ==> NOTE: 3840x2560 can not be viewed by Kakaotalk and standard Android player.


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
FPS=30 # 60 is less jittery than 30, but 30 is also okay 
total_frames=$(echo "$DUR * $FPS" | bc)
# fade_in_duration=0.5    # duration of fade-in and fade-out transition for each video (in seconds)
# fade_out_duration=0.5    # duration of fade-in and fade-out transition for each video (in seconds)
# $fade_duration will be inside $DUR !

vignette=PI/4 # PI/4 (darker) # default value == PI/5 (dark)

# iterate all images and prepare inputs for ffmpeg
inputs=""
fc="" # filter_complex
counter=0
last_map=""
concat_inputs=""

use_various_image_ratios=0 # 1 ==> use 'scale' and 'pad' to fit the video resolution, 0 (all image are same ratio) ==> use 'setsar' only

zoom_start=1.0 # initial zoom (original size)
zoom_end=1.2 # 20% zoomed in ==> NOTE: adjust this value to zoom in more or less
zoom_speed=$(printf "%.3f" $(echo "($zoom_end - $zoom_start)/$total_frames" | bc -l)) # variable zoom speed ==> 0.2 / 120 frames ==> 0.0016666666666666667
zoom_speed=0.003 # increasing to 0.003 is the solution to jittery or shaky zoom effect
# IMPORTANT NOTE: larger value of 'zoom_speed' will avoid jittery zoom effect, but too large will cause zooming too fast

# calculate the target center x,y position to zoom into
target_cx=$(echo "$video_width / 2" | bc)
target_cy=$(echo "$video_height / 2" | bc)

# calculate the x and y position for each frame (zoom_expr is related to frame number)
# x_expr="$target_cx - ((iw/zoom)/2)"
# y_expr="$target_cy - ((ih/zoom)/2)"
# x_expr="floor($target_cx - ((iw/zoom)/2))"
# y_expr="floor($target_cy - ((ih/zoom)/2))"
x_expr="$target_cx - ceil($target_cx/zoom)"
y_expr="$target_cy - ceil($target_cy/zoom)"

for file_data in "${images_file_data[@]}"; do

    # extract the file data to variables
    IFS=',' read filename original_image_width original_image_height <<< "$file_data"

    if [[ $counter -eq $((total_image_files - 1)) ]]; then
      # last image, add extra duration
      DUR=$((DUR + 2)) # add 2 more seconds to display with SLOW fade-out 2 seconds
    fi
          
    inputs+="-loop 1 -t $DUR -i $filename " # note the space at the end of this line

    # calculate the zoom level for each frame
    # this 'zoom' value will determine the viewport size (original image size / zoom)
    #zoom_expr="min($zoom_end, $zoom_start + (on*$zoom_speed))" # default is zooming in (except the last image)    
    zoom_expr="$zoom_start + (on*$zoom_speed)" # do not need to use "min()"
    
    # zoom in to specified center point (target_cx, target_cy)  
    # center x,y to zoom into of the image real resolution
    # NOTE: 
    # IF using 'scale' then x,y is the specific point of the scaled width,height (not original image size)
    # target_cx=$(echo "$original_image_width / 2" | bc)
    # target_cy=$(echo "$original_image_height / 2" | bc)

    # NOTE: found that using 'scale' and 'pad' cause jittery zooming-in effect, solution is increase the zoom_speed to 0.003
    fc+="[$counter:v]"

    if [[ $use_various_image_ratios -eq 0 ]]; then
        # all images are same ratio (BUT may not have same resolution), use setsar only
        fc+="setsar=1" # set sample aspect ratio to 1:1 (square pixels)

        # change the x_expr and y_expr according to the image original resolution
        target_cx=$(echo "$original_image_width / 2" | bc)
        target_cy=$(echo "$original_image_height / 2" | bc)
    else
        # use 'scale' and 'pad' to fit various image ratios & resolutions to the video ratio and resolution        

        #fc+="scale=w=$scaled_width:h=$scaled_height:force_original_aspect_ratio=decrease" # scale down IF too large
        #fc+="scale=-1:2160:force_original_aspect_ratio=decrease" # scale down IF too large
        fc+="scale=$video_width:$video_height:force_original_aspect_ratio=decrease" # scale down IF too large .. also make operation FASTER
        #fc+="scale=8000:-1:force_original_aspect_ratio=increase" # scale UP IF too small .. make operation SLOWER
        #fc+="scale=4000:-1" # do not use force_original_aspect_ratio' because redundant after using '-1' to scale UP IF too small .. make operation SLOWER

        # 'pad' is to fill the remaining space with black background
        # NOTE: if image is bigger than 'pad' size then it will be error !
        fc+=",pad=$video_width:$video_height:(ow-iw)/2:(oh-ih)/2:color=black" # fill remaining space with black background

        fc+=",setsar=1" # set sample aspect ratio to 1:1 (square pixels), needed but only after 'scale' and 'pad'

        # calculate the target center x,y position to zoom into
        target_cx=$(echo "$video_width / 2" | bc)
        target_cy=$(echo "$video_height / 2" | bc)
    fi

    x_expr="$target_cx - ceil($target_cx/zoom)"
    y_expr="$target_cy - ceil($target_cy/zoom)"

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
        #zoom_expr="max($zoom_start, $zoom_end - (on*$zoom_speed))"
        zoom_expr="$zoom_end - (on*$zoom_speed)" # do not use "max()"
    else 
        # middle images, fade-in and fade-out
        fade_in_duration=0.5
        fade_out_duration=0.5
    fi

    fc+=",zoompan=z='$zoom_expr':x='$x_expr':y='$y_expr':s=$video_resolution"
    fc+=",fps=$FPS"

    if [[ $use_various_image_ratios -eq 0 ]]; then
        fc+=",vignette=$vignette" # put vignette looks good IF all images are same ratio
    fi
    
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

  font_size=$((video_height / 30)) # 30 is the divisor to get a good font size
  fc+=":fontsize=$font_size"
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