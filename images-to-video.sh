#!/bin/bash
# image-to-video.sh
# slideshow images, each image displayed in $duration

if [ $# -eq 0 ] 
    # no arguments supplied
    then
        echo "No arguments supplied"
        exit 0
fi


# Get the first argument, WARNING only as 1 single filename
# so "DSC*.JPG" will get "DSC03161.JPG" (just a single filename)

# this is to get all parameters !!
input_file=( "$@" )
echo "input file (a single file): $input_file"
echo "input file (all separated by a space): ${input_file[@]}"

# create a configuration file that specify the filename and duration 
#reference: http://trac.ffmpeg.org/wiki/Slideshow
config_filename="image_list.txt"

# delete file before create
rm $config_filename

duration=3.0

total_images=0
for image in "${input_file[@]}"; do

    echo "file '$image'" >> "$config_filename"
    echo "duration $duration" >> "$config_filename"
    
    total_images=$((total_images+1))
done


# Replace the extension with .mp4
output_file="video.mp4"

# Check if the output file exists and modify the name if it does
counter=1
base_output_file="${output_file%.*}"

while [[ -f "$output_file" ]]; do    
    echo "'$output_file' is already exists, use new name '${base_output_file}-${counter}.mp4'"
    output_file="${base_output_file}-${counter}.mp4"
    ((counter++))
done

# at this point, everything ready to run

# make 4K (3840*2160) video
max_width=1920
max_height=1080

#video_resolution="${new_width}x${new_height}"
video_resolution="${max_width}x${max_height}"
echo "Video resolution: $video_resolution"

# === scale will maintain aspect ratio !! ===
ffmpeg -f concat -safe 0  -i image_list.txt -vf "scale=$max_width:$max_height:force_original_aspect_ratio=decrease:eval=frame,pad=$max_width:$max_height:-1:-1:color=black" -c:v libx264 -s $video_resolution -pix_fmt yuv420p "$output_file"
