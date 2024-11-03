#!/bin/bash
# slideshow-of-images-to-video_with_random_transitions.sh

# Check if exactly 3 arguments are provided
if [ "$#" -ne 3 ]; then
    echo "--------------"
    echo "Total parameters: $#"
    echo "Not enough parameters."
    echo "Usage: $0 [filename wildcard] [per-image duration in seconds] [transition duration in seconds]"
    echo "example:"
    echo "$0 \"MyPhoto*.jpg\" 3 1"
    exit 1
fi

# Assign the arguments to variables
image_file_wild_card=$1
#transition_effect=$2 #eg: 'fade' or 'circleopen'
per_image_duration=$2
transition_duration=$3 # fading need slower time

# Array of transition effects supported by ffmpeg's xfade filter (https://trac.ffmpeg.org/wiki/Xfade)
transitions=("fade" "smoothleft" "smoothright" "vuwind" "vdwind" "slideleft" "slideright" "circleopen" "radial" "zoomin")

# Print the input parameters (optional, for debugging purposes)
echo "Filename wildcard: $image_file_wild_card"
#echo "Transition effect: $transition_effect"
echo "Per-image duration: $per_image_duration"
echo "Transition duration: $transition_duration"

echo "============"
#exit -1

# Define resolution variables (MAKE SURE there is NO BLACK BAR on any side)
max_width=1080 #1920
max_height=1350 # 1920 #1080

# Function to resize an image while maintaining aspect ratio
resize_image() {
    local input_image="$1"
    local output_image="$2"

    # WARNING: -y to automatically answer prompt with 'yes', in this case: OVERRIDE file    
    # resize with keeping aspect ratio to exact required resolution, so must use padding !!!
    ffmpeg -hide_banner -loglevel error -y -i "$input_image" -vf "scale=$max_width:$max_height:force_original_aspect_ratio=1,pad=$max_width:$max_height:(ow-iw)/2:(oh-ih)/2,setsar=1" "$output_image"  
}

# Get all image files in the current directory
total_image_to_resize=$(ls $image_file_wild_card 2>/dev/null | wc -l)

echo "Total image to resize = ${total_image_to_resize}"

resized_total_file=0

input_list=''
filter_complex=''

# Iterate over each image file
found=0

offset=0
previous_offset=0

for filename in $(ls $image_file_wild_card 2>/dev/null); do
    found=$((found + 1))

    #echo "Matched filename: $filename"

    # Replace ".jpg" with your desired output extension if needed
    
    # output_image="resized_${max_width}x${max_height}_${image_file%.jpg}.jpg" # embed original filename (for debugging)
    # output always in PNG (better quality than jpg)
    output_image="resized_${found}.png" # shorter name, to make sure not to exceed CLI limit

    resize_image "$filename" "$output_image"
    echo "Resized $filename to $output_image"
    
    input_list+="-loop 1 -t $per_image_duration -i $output_image "

    resized_total_file=$((resized_total_file + 1))
    
    # offset == the time to start the transition for 'transition duration'    
    # NOTES:
    # 1. Total transition is (total_image_to_resize - 1), eg: if total image = 10 then transition is 9
    # 2. The last image will be displayed longer than others (== per_image_duration, because no transition to cut) !
    
    # example scenario: display duration per image = 3 seconds, transition duration = 2 seconds
    # === this is FAILED (created video only 1 image and finished) ============
    # image1 -> 3 seconds (per_image_duration) 
    # transition1 -> offset = (total image: 1 * 3) + (total previsous transition: 0 * 2) 3 seconds
    # image2 -> 3 seconds
    # transition2 -> offset = (total image: 2 * 3) + (total previsous transition: 1 * 2) 8 seconds
    # image3 -> 3 seconds
    # transition3 -> offset = (total image: 3 * 3) + (total previsous transition: 2 * 2) 13 seconds
    # image4 -> 3 seconds
    # total video duration length = (total image * per_image_duration) + ((total image - 1) * transition_duration) = 18 seconds
    # Calculate the offset for each transition
    offset=$(( (found * per_image_duration) + ((found - 1) * transition_duration) ))
    # =========== logic 2 => also failed but reached 2nd image  =======================
    # image1 -> 1 second (per_image_duration - transition_duration) 
    # transition1 -> offset = (total image: 1 * 1) + (total previsous transition: 0 * 2) 1 seconds
    # image2 -> 1 second
    # transition2 -> offset = (total image: 2 * 1) + (total previsous transition: 1 * 2) 4 seconds
    # image3 -> 1 second
    # transition3 -> offset = (total image: 3 * 1) + (total previsous transition: 2 * 2) 7 seconds
    # image4 -> 1 second
    # total video duration length = (total image * (per_image_duration - transition_duration)) + ((total image - 1) * transition_duration) = 10 seconds
    # Calculate the offset for each transition
    offset=$(( (found * (per_image_duration - transition_duration)) + ((found - 1) * transition_duration) ))
    # =========== (tested working good in VLC plater) logic 3 => https://stackoverflow.com/questions/63553906/merging-multiple-video-files-with-ffmpeg-and-xfade-filter  =======================
    # image1 -> 3 seconds (per_image_duration) 
    # transition1 -> offset = (per_image_duration: 3) + (previous offset: 0) - (transition_duration: 2) = 1
    # image2 -> 3 seconds
    # transition2 -> offset = (per_image_duration: 3) + (previous offset: 1) - (transition_duration: 2) = 2
    # image3 -> 3 seconds
    # transition3 -> offset = (per_image_duration: 3) + (previous offset: 2) - (transition_duration: 2) = 3
    # image4 -> 3 seconds
    # total video duration length = ((total image - 1) * (per_image_duration - transition_duration)) + (per_image_duration of last image [no transition]) = 6 seconds     
    offset=$(( ((per_image_duration + previous_offset) - transition_duration) ))
    #echo "image $found offset: $offset"

    # update for next loop
    previous_offset=$offset 

    # TODO: find how 
    # 2024-10-31: NO WAY to make sure total video length is (total_image * image_duration), if must-have then need to add padding at the end !!!

    random_transition="${transitions[$RANDOM % ${#transitions[@]}]}"  # Randomly select a transition
    
    if [ $found -eq 1 ]; then
        # first image        
        filter_complex+="[0][1]xfade=transition=$random_transition:duration=$transition_duration:offset=$offset[f$found]; "
    elif [ $found -lt $((total_image_to_resize)) ]; then
        filter_complex+="[f$((found-1))][$((found))]xfade=transition=$random_transition:duration=$transition_duration:offset=$offset[f$found]; "
    fi
done

# Remove the trailing semicolon and space from the filter_complex
filter_complex="${filter_complex%; }"

last_frame_code="[f$((found - 1))]"

echo "Total resized file = ${resized_total_file}"
echo "Input list = ${input_list}"
echo "Filter complex = ${filter_complex}"
echo "Last frame code = ${last_frame_code}"

video_resolution="${max_width}x${max_height}"

# Replace the extension with .mp4
output_file="output.mp4"

# Check if the output file exists and modify the name if it does
found_file=1
base_output_file="${output_file%.*}"

while [[ -f "$output_file" ]]; do    
    echo "'$output_file' is already exists, use new name '${base_output_file}-${found_file}.mp4'"
    output_file="${base_output_file}-${found_file}.mp4"
    ((found_file++))
done

#exit 0 # exit successfully

# 
cli="ffmpeg $input_list -filter_complex \"$filter_complex\" -c:v libx264 -s \"$video_resolution\" -pix_fmt yuv420p -map \"${last_frame_code}\" \"$output_file\""

# display (to review during debugging) command before execute
echo "**********CLI*********"
echo "$cli"
echo "**********************"

# execute
eval "$cli"