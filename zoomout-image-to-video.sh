#!/bin/bash
# zoomout-image-to-video.sh

# use an image to create a video by zooming-in from full size to center 

if [ $# -eq 0 ] 
    # no arguments supplied
    then
        echo "No arguments supplied"
        exit 0
fi


# Get the first argument
input_file="$1"

# Replace the extension with .mp4
output_file="[zoomout]-${input_file%.*}.mp4"

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

# For Instagram Reel, rules to set the maximum dimensions based on orientation
max_height_portrait=1920
max_width_portrait=1080
max_width_landscape=1080

# Calculate the new dimensions while keeping the aspect ratio
if [ "$width" -lt "$height" ]; then
    # Portrait
    new_height=$height
    new_width=$width

    if [ "$height" -gt "$max_height_portrait" ]; then
        new_height=$max_height_portrait
        new_width=$(echo "$width * $max_height_portrait / $height" | bc)
    fi

    if [ "$new_width" -gt "$max_width_portrait" ]; then
        new_width=$max_width_portrait
        new_height=$(echo "$height * $max_width_portrait / $width" | bc)
    fi
else
    # Landscape
    if [ "$width" -gt "$max_width_landscape" ]; then
        new_width=$max_width_landscape
        new_height=$(echo "$height * $max_width_landscape / $width" | bc)
    else
        new_width=$width
        new_height=$height
    fi
fi

# fix "[libx264 @ 0x561f21a12100] height not divisible by 2 (1080x1649)"
# Ensure the new height is divisible by 2
if [ $((new_height % 2)) -ne 0 ]; then
    new_height=$((new_height + 1))
fi


video_resolution="${new_width}x${new_height}"
echo "Video resolution: $video_resolution"

# duration
DUR=30

# fps 
fps=25


# ZOOM TO THE CENTER to the image 
# zoom == z ==> Set the zoom expression. Range is 1.0-10. Default is 1.0
# scale=8000:-1 ==> scale the image to 8000xwhatever height
# -1 ==> keep image ratio (http://trac.ffmpeg.org/wiki/Scaling)
# -2 ==> keep ratio
# scale=iw:ih ==> keep the ratio the same as INPUT WIDTH and INPUT HEIGHT
# zoompan=z='zoom+0.001' ==> smooth butter zoom in, if higher then the video is jittery
# x=iw/2-(iw/zoom/2):y=ih/2-(ih/zoom/2) ==> center the image to the screen
# x=0,y=0 ==> zoom in to top left
# d ==> Set the duration expression in number of frames. This sets for how many number of frames effect will last for single input image. Default is 90. 
# NOTE: if d is too small then the effect will be restarted, to avoid restart make it as large as possible.

# on ==> Output frame count.

# s ==> video resolution, default is 1280x720 (720p)
# WARNING: changing resolution may skewed ratio, so keep the ratio the same 

# zoom-in (tested working properly)
#ffmpeg -loop 1 -i "$input_file" -vf "zoompan=z='min(zoom+0.003,3.0)':d=2000:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'" -c:v libx264 -t $DUR -s $video_resolution -pix_fmt yuv420p "$output_file"

# zoom in and out (breathing) --> tested working
#ffmpeg -loop 1 -i "$input_file" -vf "scale=iw*4:ih*4,zoompan=z='if(lte(mod(on,60),30),zoom+0.002,zoom-0.002)':x='iw/2-(iw/zoom)/2':y='ih/2-(ih/zoom)/2':d=25*5" -c:v libx264 -t $DUR -s $video_resolution -pix_fmt yuv420p "$output_file"


#Zooming out

# start with large zoom value and decrease it with each frame

# zoom out from large zoom value to 1.0 (image full size)
end_zoom=1.0

zoomout_speed=0.005

# Perform floating-point arithmetic using bc
start_zoom=$(echo "$end_zoom + $fps * $DUR * $zoomout_speed" | bc)

echo "start zoom: $start_zoom"

ffmpeg -loop 1 -i "$input_file" -vf "zoompan=z='if(lte(zoom,$end_zoom),$start_zoom,max($end_zoom,zoom-$zoomout_speed))':x=iw/2-(iw/zoom/2):y=ih/2-(ih/zoom/2):d=$DUR*$fps" -c:v libx264 -t $DUR -s $video_resolution -pix_fmt yuv420p "$output_file"
