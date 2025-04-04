#!/bin/bash
# slideshow-fading-zooming-out-with-text-watermark.sh

# Check if exactly 1 argument are provided
if [ "$#" -lt 1 ]; then
    echo "--------------"
    # echo "Total parameters: $#"
    # echo "Not enough parameters."
    echo "Usage: $0 [filename wildcard]" # [per-image duration]"
    echo "example:"
    echo "$0 \"MyPhoto*.jpg\" 3 \"Hello there !!\""
    exit 1
fi

# Assign the arguments to variables
image_file_wild_card=$1

per_image_duration=5 # default duration

# watermark_text=$3
# watermark_text_length=${#watermark_text}
# if [ $watermark_text_length -gt 0 ]; then
#   echo "Watermark text: $watermark_text"
# fi

# for Instagram post, ratio of 5:4 (portrait) or 1:1.25 is good !!!
max_width=1080 
max_height=1350 
video_resolution="${max_width}x${max_height}"

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
found=0

#for filename in $(ls $image_file_wild_card 2>/dev/null); do
for filename in $image_file_wild_card; do
    found=$((found + 1))

    #echo "Matched filename: $filename"

    # Replace ".jpg" with your desired output extension if needed
    
    # output_image="resized_${max_width}x${max_height}_${image_file%.jpg}.jpg" # embed original filename (for debugging)
    # output always in PNG (better quality than jpg)
    output_image="resized_${found}.png" # shorter name, to make sure not to exceed CLI limit

    # execute the resize function
    resize_image "$filename" "$output_image"
    echo "Resized $filename to $output_image"
    
    resized_total_file=$((resized_total_file + 1))
done

echo "Total resized file = ${resized_total_file}"

# Check if the output file exists and modify the name if it does
video_output_filename="output.mp4"
found_file=1
base_video_output_file="${video_output_filename%.*}"

while [[ -f "$video_output_filename" ]]; do    
    echo "'$video_output_filename' is already exists, use new name '${base_video_output_file}-${found_file}.mp4'"
    video_output_filename="${base_video_output_file}-${found_file}.mp4"
    ((found_file++))
done


fps=30
DUR=5              # duration per image in seconds
fade_duration=1    # duration of fade-in and fade-out transition for each video (in seconds)
# $fade_duration will be inside $DUR !

# Settings
start_zoom=1.2      # initial zoom (20% zoomed in)
end_zoom=1.0        # final zoom level (original size)
zoomout_speed=0.001 # combination of zoomout_speed=0.001 with DUR=5 are good

# Process each resized PNG image individually

# Generate input arguments
inputs=""
filter_complex=""
counter=0
offset=0


for resized_image_filename in resized_*.png; do
    inputs+="-loop 1 -t $DUR -i $resized_image_filename "

    # zoompan with fade-in and fade-out per image
    # WARNING: using zoompan needs:
    # 'trim' to set exact limit time, and
    # 'setpts' to resets timestamps for correct concatenation

    if [[ $counter -eq 0 ]]; then
        # first image, no need to fade-in
        filter_complex+="[$counter:v]zoompan=z='if(lte(zoom,$end_zoom),$start_zoom,max($end_zoom,zoom-$zoomout_speed))'\
            :x=iw/2-(iw/zoom/2)\
            :y=ih/2-(ih/zoom/2)\
            :d=$((DUR*fps))\
            :s=$video_resolution\
            ,fps=$fps\
            ,fade=t=out:st=$(echo "$DUR-$fade_duration" | bc)\
            :d=$fade_duration\
            ,trim=duration=5\
            ,setpts=PTS-STARTPTS[v${counter}];"
    elif [[ $counter -eq $((resized_total_file - 1)) ]]; then
        # last image, no need to fade-out
        filter_complex+="[$counter:v]zoompan=z='if(lte(zoom,$end_zoom),$start_zoom,max($end_zoom,zoom-$zoomout_speed))'\
            :x=iw/2-(iw/zoom/2)\
            :y=ih/2-(ih/zoom/2)\
            :d=$((DUR*fps))\
            :s=$video_resolution\
            ,fps=$fps\
            ,fade=t=in:st=0:d=$fade_duration\
            :d=$fade_duration\
            ,trim=duration=5\
            ,setpts=PTS-STARTPTS[v${counter}];"
    else
        # d=$((DUR*fps)) # duration in frames 
        # fade=t=in:st=0:d=1       # fade-in starts at 0 sec, lasts 1 sec
        # fade=t=out:st=4:d=1      # fade-out starts at 4 sec, lasts 1 sec
        filter_complex+="[$counter:v]zoompan=z='if(lte(zoom,$end_zoom),$start_zoom,max($end_zoom,zoom-$zoomout_speed))'\
            :x=iw/2-(iw/zoom/2)\
            :y=ih/2-(ih/zoom/2)\
            :d=$((DUR*fps))\
            :s=$video_resolution\
            ,fps=$fps\
            ,fade=t=in:st=0:d=$fade_duration\
            ,fade=t=out:st=$(echo "$DUR-$fade_duration" | bc)\
            :d=$fade_duration\
            ,trim=duration=5\
            ,setpts=PTS-STARTPTS[v${counter}];"
    fi
        
    # increment the counter for the next image
    # counter=$((counter + 1))
    ((counter++))

done

# define watermark_image
#watermark_image="hariyantoandfriends-300x45.png" # watermark image
if [[ -n "$watermark_image" && ${#watermark_image} -gt 1 ]]; then
    filter_complex+="[$counter:v]fps=$fps,format=rgba,setpts=PTS-STARTPTS[wm];" # to make adding watermark without jittery
fi

# Concatenate using overlay for crossfade
for ((i=0; i<counter; i++)); do
    filter_complex+="[v${i}]"
done

final_tag="full_video"
filter_complex+="concat=n=${counter}:v=1:a=0[$final_tag];"

if [[ -n "$watermark_image" && ${#watermark_image} -gt 1 ]]; then
  echo "Watermark image value exists."

  # Generate the input for watermark as the last input file
  inputs+="-loop 1 -t $((counter * DUR)) -i $watermark_image"

  # Positioning watermark at bottom right with 10px padding
  #filter_complex+="[$final_tag][$counter:v]overlay=W-w-10:H-h-10[output_video];" # original jittery
  filter_complex+="[$final_tag][wm]overlay=W-w-10:H-h-10[output_video];"

  final_tag="output_video"
fi

# add text watermark to the video
watermark_text="@hariyantoandfriends"
if [[ -n "$watermark_text" && ${#watermark_text} -gt 1 ]]; then

  font_file="Signatura\ Monoline.ttf" # use ttf file
  font_file="MonsieurLaDoulaise-Regular.ttf"
  font="Times New Roman" #Segoe Script" 

  filter_complex+="[$final_tag]drawtext=text='$watermark_text'\
  :fontfile='$font_file'\
  :fontcolor=white\
  :fontsize=48\
  :x=20:y=h-text_h-20[text_watermarked];"

  # bottom center  
  #:x=(w-text_w)/2:y=h-text_h-20[text_watermarked];"

  final_tag="text_watermarked"
fi

# Remove only the trailing semicolon
filter_complex="${filter_complex%;}"

# Full FFmpeg command using an array
cli="ffmpeg -hide_banner \
  "$inputs" \
  -filter_complex \"$filter_complex\" \
  -map \"[$final_tag]\" \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -preset ultrafast \
  -r \"$fps\" \
  -s \"$video_resolution\" \
  
  \"$video_output_filename\"
  "

echo "*** cli: $cli"

eval $cli
ret=$?
if [ $ret -eq 0 ]; then
    echo "************************"
    echo "🎉 Succesful to create video: $video_output_filename"
fi