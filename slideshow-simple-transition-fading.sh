#!/bin/bash
# slideshow-sliding-from-right-to-left-with-watermark.sh

# Check if exactly 3 arguments are provided
if [ "$#" -lt 2 ]; then
    echo "--------------"
    # echo "Total parameters: $#"
    # echo "Not enough parameters."
    echo "Usage: $0 [filename wildcard] [per-image duration]"
    echo "example:"
    echo "$0 \"MyPhoto*.jpg\" 4 \"Hello there !!\""
    exit 1
fi

# Get the start time for performance measurement
time_start=$(date +%s)

# Assign the arguments to variables
image_file_wild_card=$1
echo "Image file wildcard: $image_file_wild_card"

per_image_duration=$2
echo "Per-image duration: $per_image_duration"

transition_duration=1 # 1 seconds

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

    # #DEBUGGING: stop if $counter == 5
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


#transition_duration=$3 # fading need slower time

#exit -1

# for Instagram post, ratio of 5:4 (portrait) or 1:1.25 is good !!!
video_width=3840 #1080
video_height=2160 # 1350
video_resolution="${video_width}x${video_height}"

# Check if the output file exists and modify the name if it does
video_output_filename="output.mp4"
found_file=1
base_video_output_file="${video_output_filename%.*}"

while [[ -f "$video_output_filename" ]]; do    
    echo "'$video_output_filename' is already exists, use new name '${base_video_output_file}-${found_file}.mp4'"
    video_output_filename="${base_video_output_file}-${found_file}.mp4"
    ((found_file++))
done

total_duration=$((total_image_files * per_image_duration))
fps=30  # Frames per second

# Build input arguments dynamically
# Prepare input arguments (including background image)
input_args=()

input_list=''
filter_complex=''

# Iterate over each image file
found=0

offset=0
previous_offset=0

# Array of transition effects supported by ffmpeg's xfade filter (https://trac.ffmpeg.org/wiki/Xfade)
transitions=("fade" "smoothleft" "smoothright" "vuwind" "vdwind" "slideleft" "slideright" "circleopen" "radial" "zoomin")

#input_args=(-loop 1 -t "$total_duration" -i background-cover.jpg)
for img in "${images_file_data[@]}"; do
    found=$((found + 1))

    # extract the file data to variables
    IFS=',' read filename original_image_width original_image_height <<< "$img"

    #input_args+=(-loop 1 -t "$per_image_duration" -i "$filename")

    # offset == the time to start the transition for 'transition duration'    
    # NOTES:
    # 1. Total transition is (total_image_to_resize - 1), eg: if total image = 10 then transition is 9
    # 2. Display duration per image SHOULD BE longer than transition time
    # 3. SOMEHOW FFMPEG failed if (per_image_duration - transtion_duration) < 2, so make sure (per_image_duration - transtion_duration) >= 2
    

    # example scenario: display duration per image = 4 seconds, transition duration = 1 second
    # =========== (tested working good in VLC plater) logic 3 => https://stackoverflow.com/questions/63553906/merging-multiple-video-files-with-ffmpeg-and-xfade-filter  =======================
    # example: image1 (3s) === transtion (1s) = image2 (3s) === transtion (1s) = image3 (3s) === transtion (1s) = image4 (3s)

    # image1 -> 3 seconds (per_image_duration - transtion_duration) 
    # transition1 -> offset = (per_image_duration: 4) + (previous offset: 0) - (transition_duration: 1) = 3
    # image2 -> 3 seconds
    # transition2 -> offset = (per_image_duration: 4) + (previous offset: 3) - (transition_duration: 1) = 6
    # image3 -> 3 seconds
    # transition3 -> offset = (per_image_duration: 4) + (previous offset: 6) - (transition_duration: 1) = 9
    # image4 -> 3 seconds
    # total video duration length = ((total image - 1) * (per_image_duration - transition_duration)) + (per_image_duration of last image [no transition]) = 12 seconds
    # == ((4 - 1) * (4 - 1)) + (3)
    # == (3 * 3) + 3
    # == 12

    # from 1st image to n-1 image, the actual display image duration == $per_image_duration
    # the last image, the actual display image duration == $per_image_duration - transition_duration

    offset=$(( ((per_image_duration + previous_offset) - transition_duration) ))    

    # update for next loop
    previous_offset=$offset 

    # TODO: find how 
    # 2024-10-31: NO WAY to make sure total video length is (total_image * image_duration), if must-have then need to add padding at the end !!!

    random_transition="${transitions[$RANDOM % ${#transitions[@]}]}"  # Randomly select a transition
    random_transition="fade" # for testing, use fade transition only
    
    if [ $found -eq 1 ]; then
        # first image        
        input_list+="-loop 1 -t $per_image_duration -i $filename "

        filter_complex+="[0][1]xfade=transition=$random_transition:duration=$transition_duration:offset=$offset[f$found]; "
    elif [ $found -lt $((total_image_files)) ]; then
        # middle images, using longer display duration
        input_list+="-loop 1 -t $per_image_duration -i $filename "
        
        filter_complex+="[f$((found-1))][$((found))]xfade=transition=$random_transition:duration=$transition_duration:offset=$offset[f$found]; "
    else
        # last image, using shorter display duration BECAUSE no filter!!
        last_image_display_duration=$(( per_image_duration - transition_duration ))
        input_list+="-loop 1 -t $last_image_display_duration -i $filename "

        # NOTE: last image does not have filter_complex
    fi

done

last_frame_code="[f$((found - 1))]"

watermark_text=$3
watermark_text_length=${#watermark_text}
if [ $watermark_text_length -gt 0 ]; then
  echo "Watermark text: $watermark_text"

  # Add watermark to each slide
  # the last filter 
  filter_complex+="${last_frame_code}drawtext=text='${watermark_text}':fontcolor=white:fontsize=48:x=w-text_w-20:y=h-text_h-20[watermarked];"
  last_frame_code="[watermarked]"
fi

# Remove the trailing semicolon and space from the filter_complex
filter_complex="${filter_complex%; }"


# Full FFmpeg command using an array --> safer
cli=(ffmpeg   
  $input_list
  -filter_complex "$filter_complex"
  -map "$last_frame_code" 
  -c:v libx264
  -preset slow # set encoding speed, faster encoding but bigger file size
  # this simple showing STILL photo with transition=fade is good candidate for better compression
  -crf 25 # set quality, lower value is better quality (bigger file size)
  -r "$fps" 
  -s "$video_resolution" 
  -pix_fmt yuv420p 
  "$video_output_filename"
)

# display (to review during debugging) command before execute
echo "**********CLI*********"
# using ${cli[@]} expands each item as separate words (safe for commands)
echo "${cli[@]}"
echo "**********************"

"${cli[@]}"
if [ $? -eq 0 ]; then
  echo "🎉 Succesful to create video: $video_output_filename"
fi

time_end=$(date +%s)
time_elapsed=$((time_end - time_start))
echo "Time elapsed: ${time_elapsed} seconds"