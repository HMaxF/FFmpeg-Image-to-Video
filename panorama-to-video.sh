#!/bin/bash
# panorama-to-video.sh

# use a wide panorama image to create a video

if [ $# -eq 0 ] 
    # no arguments supplied
    then
        echo "No arguments supplied"
        exit 0
fi


# Get the first argument
input_file="$1"

# Replace the extension with .mp4
output_file="${input_file%.*}.mp4"

# Check if the output file exists and modify the name if it does
counter=1
base_output_file="${output_file%.*}"

while [[ -f "$output_file" ]]; do    
    echo "'$output_file' is already exists, use new name '${base_output_file}-${counter}.mp4'"
    output_file="${base_output_file}-${counter}.mp4"
    ((counter++))
done

# at this point, everything ready to run

# Use ffprobe to get the width and height of the image
resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$input_file")

# Split the resolution into width and height
width=$(echo "$resolution" | cut -d, -f1)
height=$(echo "$resolution" | cut -d, -f2)

echo "Image resolution: $width x $height"

# NOTE: In the if statement, there must be spaces between the brackets and the condition
if [ "$width" -lt "$height" ]; then
    # portrait
    echo "It is a portrait (not a panorama)"
    exit 0
fi

# duration
DUR=60

# fps 
fps=25

# create a video from a panorama image, panning from left to right
# use ffmpeg crop (https://ffmpeg.org//ffmpeg-filters.html#crop)

# r 60 ==> frame rate per seconds (default 25)
# if panning too fast then either increase the time OR increase the width
# (t-1) ==> to give 1 second pause at the start of video
#ffmpeg -loop 1 -t $DUR -i DSC00808.JPG -vf "crop=w=ih*1.5:h=ih:x='(iw-(ih*1.5))*(t-1)/$DUR':y=0" -r $fps -pix_fmt yuv420p pan7.mp4
# *1.7 == maintain 16:9 ratio
#ffmpeg -loop 1 -t $DUR -i DSC00808.JPG -vf "crop=w=ih*1.7:h=ih:x='((iw-(ih*1.7))*t)/$DUR':y=0" -r $fps -pix_fmt yuv420p pan8.mp4
# NOTES
# 1. Instagram is "mobile first" so the video resolution is either vertical (portrait 1080x1920) or SQUARE with max 1080 pixel
# 2. if image height 4000px then error such as "Invalid too big or non positive size for width '6800' or height '4000'"
# 3. To create 16:9 video, may multiple *1.7 to keep the ratio 16:9 of WIDTH (HEIGHT * 1.7) x HEIGHT !!

#ffmpeg -loop 1 -t $DUR -i "${1}" -vf "crop=w=ih*1.0:h=ih:x='((iw-(ih*1.0))*t)/$DUR':y=0" -r $fps -pix_fmt yuv420p $output_file

# for Instagram, max height 1080
if [ $height -gt 1080 ]; then
    echo "Image height is > 1080, set limit"
    height=1080
fi 

video_resolution="${height}x${height}"
echo "Video resolution: $video_resolution"

# from left to right
#ffmpeg -loop 1 -t $DUR -i "$input_file" -vf "crop=w=ih*1.0:h=ih:x='((iw-(ih*1.0))*t)/$DUR':y=0" -r $fps -s $video_resolution -pix_fmt yuv420p "$output_file"
#ffmpeg -loop 1 -t $DUR -i "$input_file" -vf "crop=w=ih:h=ih:x='((iw-ih)*t)/$DUR':y=0" -r $fps -s $video_resolution -pix_fmt yuv420p "$output_file"

# pan from left to right then go back to left
# logic: if t (time) under $DUR/2 then z=t else z=($DUR-t), x=z*2 ==> speed 2 times (half way to go right then half way to go left)
ffmpeg -loop 1 -t $DUR -i "$input_file" -vf "crop=w=ih:h=ih:x='((iw-ih)*(if(gte(t,$DUR/2),$DUR-t,t) * 2) )/$DUR':y=0" -r $fps -s $video_resolution -pix_fmt yuv420p "$output_file"
