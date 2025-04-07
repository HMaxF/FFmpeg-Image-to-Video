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

# Settings
start_zoom=1.2       # initial zoom (20% zoomed in)
end_zoom=1.0         # final zoom level (original size)
zoomout_speed=0.002 # constant speed, change from 0.001 to 0.002 for faster and smoother (less jittery)

fps=60 #30 --> use 60 for smoother (less jittery) video
DUR=5              # duration per image in seconds
total_frames=$((DUR * fps)) # instead of constant speed ($zoomout_speed), use $fps and $DUR to calculate dynamic speed (but maybe value is too small ==> jittery)
fade_duration=1    # duration of fade-in and fade-out transition for each video (in seconds)
# $fade_duration will be inside $DUR !


# for Instagram post, ratio of 5:4 (portrait) or 1:1.25 is good !!!
video_width=1080
video_height=1350
image_width=$(echo "$video_width * $start_zoom" | bc) # make larger size than video to help improve quality
image_height=$(echo "$video_height * $start_zoom" | bc)
video_resolution="${video_width}x${video_height}"

# Function to resize an image while maintaining aspect ratio
resize_image() {
    local input_image="$1"
    local output_image="$2"

    # WARNING: -y to automatically answer prompt with 'yes', in this case: OVERRIDE file    
    # resize with keeping aspect ratio to exact required resolution, so must use padding !!!
    ffmpeg -hide_banner -loglevel error -y -i "$input_image" -vf "scale=$image_width:$image_height:force_original_aspect_ratio=1,pad=$image_width:$image_height:(ow-iw)/2:(oh-ih)/2,setsar=1" "$output_image"
}

# Get all image files in the current directory
total_image_to_resize=$(ls $image_file_wild_card 2>/dev/null | wc -l)
echo "Total image to resize = ${total_image_to_resize}"

resized_total_file=0
found=0
resized_filenames=() # init array

for filename in $(ls -v $image_file_wild_card); do

    found=$((found + 1))

    #echo "Matched filename: $filename"

    # Replace ".jpg" with your desired output extension if needed
    
    # output_image="resized_${max_width}x${max_height}_${image_file%.jpg}.jpg" # embed original filename (for debugging)
    # output always in PNG (better quality than jpg)
    output_image="resized_${found}.png" # shorter name, to make sure not to exceed CLI limit

    # execute the resize function
    resize_image "$filename" "$output_image"
    echo "Resized $filename to $output_image"

    resized_filenames+=("$output_image") # append into array
    
    resized_total_file=$((resized_total_file + 1))
done

echo "Total resized file = ${resized_total_file}"

if [[ $resized_total_file -lt 1 ]]; then
  echo "no image to resize, exit"
  exit 1
fi

# Check if the output file exists and modify the name if it does
video_output_filename="output.mp4"
found_file=1
base_video_output_file="${video_output_filename%.*}"

while [[ -f "$video_output_filename" ]]; do    
    echo "'$video_output_filename' is already exists, use new name '${base_video_output_file}-${found_file}.mp4'"
    video_output_filename="${base_video_output_file}-${found_file}.mp4"
    ((found_file++))
done

# Process each resized PNG image individually

# Generate input arguments
inputs=""
filter_complex=""
counter=0
offset=0

for resized_image_filename in "${resized_filenames[@]}"; do
    inputs+="-loop 1 -t $DUR -i $resized_image_filename "

    # zoompan with fade-in and fade-out per image
    # WARNING: using zoompan needs:
    # 'trim' to set exact limit time, and
    # 'setpts' to resets timestamps for correct concatenation

    # add 'vignette' for security (authenticity) of hariyantoandfriends
    # just using 'vignette' (without parameter is default 'PI/5', it is a little weak == small shadow)
    # vignette=PI/4 ==> 45 degree ==> stronger shadow

    if [[ $counter -eq 0 ]]; then
        # first image, no need to fade-in
        # zooming-in (enlarge) the first image

        # use dynamic zoom speed (without $zoomout_speed)
        # eq(on,1) ==> if frame count equal 1 (first frame)
        #filter_complex+="[$counter:v]zoompan=z='if(eq(on,1),$start_zoom,$start_zoom+(($end_zoom-$start_zoom)*(on/$total_frames)))'\

        

        filter_complex+="[$counter:v]zoompan=z='max($end_zoom,$start_zoom-on*$zoomout_speed)'\
            :x=iw/2-(iw/zoom/2)\
            :y=ih/2-(ih/zoom/2)\
            :d=1\
            :s=$video_resolution\
            ,fps=$fps\
            ,vignette=PI/4\
            ,fade=t=out:st=$(echo "$DUR-$fade_duration" | bc)\
            :d=$fade_duration\
            ,trim=duration=$DUR\
            ,setpts=PTS-STARTPTS[v${counter}];"
    elif [[ $counter -eq $((resized_total_file - 1)) ]]; then
        # last image, no need to fade-out
        # zooming-in (enlarge) the last image
        filter_complex+="[$counter:v]zoompan=z='max($end_zoom,$start_zoom-on*$zoomout_speed)'\
            :x=iw/2-(iw/zoom/2)\
            :y=ih/2-(ih/zoom/2)\
            :d=1\
            :s=$video_resolution\
            ,fps=$fps\
            ,vignette=PI/4\
            ,fade=t=in:st=0:d=$fade_duration\
            :d=$fade_duration\
            ,trim=duration=$DUR\
            ,setpts=PTS-STARTPTS[v${counter}];"
    else
        # d=$((DUR*fps)) # duration in frames 
        # fade=t=in:st=0:d=1       # fade-in starts at 0 sec, lasts 1 sec
        # fade=t=out:st=4:d=1      # fade-out starts at 4 sec, lasts 1 sec
        #filter_complex+="[$counter:v]zoompan=z='if(lte(zoom,$end_zoom),$start_zoom,max($end_zoom,zoom-$zoomout_speed))'\
        filter_complex+="[$counter:v]zoompan=z='min($start_zoom,$end_zoom+on*$zoomout_speed)'\
            :x=iw/2-(iw/zoom/2)\
            :y=ih/2-(ih/zoom/2)\
            :d=1\
            :s=$video_resolution\
            ,fps=$fps\
            ,vignette=PI/4\
            ,fade=t=in:st=0:d=$fade_duration\
            ,fade=t=out:st=$(echo "$DUR-$fade_duration" | bc)\
            :d=$fade_duration\
            ,trim=duration=$DUR\
            ,setpts=PTS-STARTPTS[v${counter}];"
    fi
        
    # increment the counter for the next image
    # counter=$((counter + 1))
    ((counter++))

done

# define watermark_image
#watermark_image="hariyantoandfriends-300x45.png" # watermark image
if [[ -n "$watermark_image" && ${#watermark_image} -gt 1 ]]; then    
    #filter_complex+="[$counter:v]fps=$fps,format=rgba,setpts=PTS-STARTPTS[wm];" # to make adding watermark without jittery
    filter_complex+="[$counter:v]fps=$fps,format=rgba,loop=1,trim=duration=$((DUR*resized_total_file)),tpad=stop_mode=clone,setpts=PTS-STARTPTS[wm];" # to make adding watermark without jittery

    #2025-04-07: no solution to remove jittery
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
  filter_complex+="[$final_tag][wm]overlay=W-w-20:H-h-20[output_video];"

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
  -r $fps \
  -s \"$video_resolution\" \
  
  \"$video_output_filename\"
  "

echo "*** cli: ******************"
echo $cli
echo "***************************"

eval $cli
ret=$?
if [ $ret -eq 0 ]; then
    echo "************************"
    echo "🎉 Succesful to create video: $video_output_filename"
fi