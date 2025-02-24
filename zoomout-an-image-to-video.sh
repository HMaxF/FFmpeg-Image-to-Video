#!/bin/bash
# zoomout-an-image-to-video.sh
# an upgrade from the old "zoomout-image-to-video.sh"

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
video_output_filename="[zoomout]-${input_file%.*}.mp4"

# Check if the output file exists and modify the name if it does
counter=1
base_output_file="${video_output_filename%.*}"

while [[ -f "$video_output_filename" ]]; do    
    echo "'$video_output_filename' is already exists, use new name '${base_output_file}-${counter}.mp4'"
    video_output_filename="${base_output_file}-${counter}.mp4"
    ((counter++))
done

# at this point, everything ready to run

# Define output video resolution 
max_width=1080 #1920
max_height=1350 # 1920 #1080

# create 'ratio' value that MUST BE equal or bigger than 1.0 
ratio=$(echo "scale=2; $max_height / $max_width" | bc) # use 2 decimal point 

video_resolution="${max_width}x${max_height}"
echo "Video resolution: $video_resolution, Ratio: $ratio"

# duration
DUR=5

# fps 
fps=30

# === trials ============
# zoom-in (tested working properly)
#ffmpeg -loop 1 -i "$input_file" -vf "zoompan=z='min(zoom+0.003,3.0)':d=2000:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'" -c:v libx264 -t $DUR -s $video_resolution -pix_fmt yuv420p "$output_file"

# zoom in and out (breathing) --> tested working
#ffmpeg -loop 1 -i "$input_file" -vf "scale=iw*4:ih*4,zoompan=z='if(lte(mod(on,60),30),zoom+0.002,zoom-0.002)':x='iw/2-(iw/zoom)/2':y='ih/2-(ih/zoom)/2':d=25*5" -c:v libx264 -t $DUR -s $video_resolution -pix_fmt yuv420p "$output_file"
# ==== end of trials =====

# Zooming out
# start with large zoom value and decrease it with each frame

# end_zoom ==> the destination of zoom out --> 1.0 == original image full size
end_zoom=1.0

# zoomout_speed=0.001 is good speed, 0.005 is too fast
zoomout_speed=0.001

# start_zoom ==> the starting zoom value (larger than 1.0) to slowly zooming out
# must use $fps and $DUR $zoomout_speed variables to make sure at the end time of zoomed-out the WHOLE image is viewed
start_zoom=$(echo "$end_zoom + $fps * $DUR * $zoomout_speed" | bc) # Perform floating-point arithmetic using bc

echo "start zoom: $start_zoom"

# Function to resize an image while maintaining aspect ratio
resize_image() {
    local input_image="$1"
    local output_image="$2"

    # create larger temp image to 
    # (a) create good quality video (not broken because zoomed-in)
    # (b) reduce shaky/jerky
    # NOTE: $start_zoom is decimal value, so use 'bc'

    #temp_max_width=$(echo "$max_width * $start_zoom" | bc | awk '{print int($1)}') # round-down using int()
    temp_max_width=$(echo "scale=0; $max_width * $start_zoom / 1" | bc) # use scale=0 to round-down
    #temp_max_width=$(echo "$temp_max_width / 1 + ( $temp_max_width > ( $temp_max_width / 1 ) )" | bc) # round-up

    #temp_max_height=$(echo "$max_height * $start_zoom" | bc | awk '{print int($1)}') # round down using int()
    temp_max_height=$(echo "scale=0; $max_height * $start_zoom / 1" | bc) # use scale=0 to round-down
    
    echo "temp image resize: $temp_max_width * $temp_max_height"

    # WARNING: -y to automatically answer prompt with 'yes', in this case: OVERRIDE file    
    # resize with keeping aspect ratio to exact required resolution, so must use padding !!!
    #ffmpeg -hide_banner -loglevel error -y -i "$input_image" -vf "scale=$max_width:$max_height:force_original_aspect_ratio=1,pad=$max_width:$max_height:(ow-iw)/2:(oh-ih)/2,setsar=1" "$output_image"

    ffmpeg -hide_banner -loglevel error -y -i "$input_image" -vf "scale=$temp_max_width:$temp_max_height:force_original_aspect_ratio=1,pad=$temp_max_width:$temp_max_height:(ow-iw)/2:(oh-ih)/2,setsar=1" "$output_image"
}

resized_png_filename="resized_${input_file}.png" # shorter name, to make sure not to exceed CLI limit

# call the function
resize_image "$input_file" "$resized_png_filename"

ffmpeg -loop 1 -i "$resized_png_filename" -vf "zoompan=z='if(lte(zoom,$end_zoom),$start_zoom,max($end_zoom,zoom-$zoomout_speed))':x=iw/2-(iw/zoom/2):y=ih/2-(ih/zoom/2):d=$DUR*$fps:s=$video_resolution" -c:v libx264 -t $DUR -r $fps -s $video_resolution -pix_fmt yuv420p "$video_output_filename"

# NOTES:
# 1. Without specifying ':s=$video_resolution' then the created video will have broken resolution.
# 2. Without specifying '-s $video_resolution' then the default value is 1280x720 or will be shaky and jerky.