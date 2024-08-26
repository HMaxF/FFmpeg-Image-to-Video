#!/bin/bash
# slideshow-images-to-video.sh


# Define variables
max_width=1080 #1920
max_height=1920 #1080
image_duration=4
transition_duration=1

# Function to resize an image while maintaining aspect ratio
resize_image() {
    local input_image="$1"
    local output_image="$2"

    # WARNING: -y to automatically answer prompt with 'yes', in this case: OVERRIDE file    
    # resize with keeping aspect ratio to exact required resolution, so must use padding !!!
    ffmpeg -hide_banner -loglevel error -y -i "$input_image" -vf "scale=$max_width:$max_height:force_original_aspect_ratio=1,pad=$max_width:$max_height:(ow-iw)/2:(oh-ih)/2,setsar=1" "$output_image"  
}

# Get all image files in the current directory
# use space as separator to loop, eg: (*.jpg *.png *.jpeg) --> first *.jpg, then *.png, then *.jpeg
# Get all image files with a .jpg extension that do not start with "resized_"
image_files=(*.jpg)
#image_files=(*.jpg !(*resized_*.jpg))

total_image_to_resize=0
for image_file in *.jpg; do
    # Check if the file does not start with "resized"
    if [[ ! $image_file =~ ^resized_ ]]; then
        total_image_to_resize=$((total_image_to_resize + 1))
    fi
done

echo "Total image to resize = ${total_image_to_resize}"

# sorting
#image_files=($(sort "${image_files[@]}"))

resized_total_file=0

input_list=''
filter_complex=''

# Iterate over each image file
count=0
found=0
for image_file in "${image_files[@]}"; do
    if [[ ! "$image_file" =~ ^resized_ ]]; then
        found=$((found + 1))

        # Replace ".jpg" with your desired output extension if needed
        
        #output_image="resized_${max_width}x${max_height}_${image_file%.jpg}.jpg" # embed original filename (for debugging)
        output_image="resized_${found}.jpg" # shorter name, to make sure not to exceed CLI limit

        resize_image "$image_file" "$output_image"
        echo "Resized $image_file to $output_image"
        
        input_list+="-loop 1 -t $image_duration -i $output_image "
        
        resized_total_file=$((resized_total_file + 1))
        
        # the video length result is = (total_image * (image_duration - transition_duration)) + transition_duration
        # example:
        # total_image = 7, image_duration = 9, transition_duration = 3
        # length = (7 * (9 - 3)) + 3 = 45 seconds

        # the last image will be displayed longer than others!

        # TODO: find how to make sure total video length is (total_image * image_duration)

        # seems like playing with 'offset' is the 'key'
        # if too low then video length is broken, but if too long will be strange
        
        offset=$(( (count + 1) * (image_duration - transition_duration) ))

        # RULE: total transition is (total_image_to_resize - 1),
        # eg: if total image = 10 then transition is 9

        # Build the filter chain
        
        if [ $count -eq 0 ]; then
            filter_complex+="[0][1]xfade=transition=slideleft:duration=$transition_duration:offset=$offset[f$count]; "

            count=$((count + 1))
        
        elif [ $count -lt $((total_image_to_resize - 1)) ]; then
            filter_complex+="[f$((count-1))][$((count+1))]xfade=transition=slideleft:duration=$transition_duration:offset=$offset[f$count]; "

            count=$((count + 1))
        fi
    fi
done

# Remove the trailing semicolon and space from the filter_complex
filter_complex="${filter_complex%; }"

last_count="[f$((count-1))]"

echo "Total resized file = ${resized_total_file}"
echo "Input list = ${input_list}"
echo "Filter complex = ${filter_complex}"
echo "Last count = ${last_count}"

total_duration=$(( count * image_duration ))
echo "Total duration = ${total_duration}"

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
cli="ffmpeg $input_list -filter_complex \"$filter_complex\" -c:v libx264 -s \"$video_resolution\" -pix_fmt yuv420p -map \"${last_count}\" -s 1920x1080 \"$output_file\""

# display (to review during debugging) command before execute
echo "**********CLI*********"
echo "$cli"
echo "**********************"

# execute
eval "$cli"