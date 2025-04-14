#!/bin/bash
# slideshow-sliding-from-right-to-left-with-watermark.sh

# Check if exactly 3 arguments are provided
if [ "$#" -lt 2 ]; then
    echo "--------------"
    # echo "Total parameters: $#"
    # echo "Not enough parameters."
    echo "Usage: $0 [filename wildcard] [per-image duration]"
    echo "example:"
    echo "$0 \"MyPhoto*.jpg\" 3 \"Hello there !!\""
    exit 1
fi

# Assign the arguments to variables
image_file_wild_card=$1
per_image_duration=$2
#transition_duration=$3 # fading need slower time
watermark_text=$3
watermark_text_length=${#watermark_text}
if [ $watermark_text_length -gt 0 ]; then
  echo "Watermark text: $watermark_text"
fi

# Print the input parameters (optional, for debugging purposes)
echo "Filename wildcard: $image_file_wild_card"
echo "Per-image duration: $per_image_duration"

echo "============"
#exit -1

# for Instagram post, ratio of 5:4 (portrait) or 1:1.25 is good !!!
video_width=1080
video_height=1350
video_resolution="${video_width}x${video_height}"

# Function to resize an image while maintaining aspect ratio
resize_image() {
    local input_image="$1"
    local output_image="$2"

    # WARNING: -y to automatically answer prompt with 'yes', in this case: OVERRIDE file    
    # resize with keeping aspect ratio to exact required resolution, so must use padding !!!
    ffmpeg -hide_banner -loglevel error -y -i "$input_image" -vf "scale=$video_width:$video_height:force_original_aspect_ratio=1,pad=$video_width:$video_height:(ow-iw)/2:(oh-ih)/2,setsar=1" "$output_image"
}

# Get all image files in the current directory
total_image_to_resize=$(ls $image_file_wild_card 2>/dev/null | wc -l)
echo "Total image to resize = ${total_image_to_resize}"

resized_total_file=0
found=0
resized_filenames=() # init array

#for filename in $(ls $image_file_wild_card 2>/dev/null); do
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
  echo "No image to resize, exit"
  exit 1
fi

# # Check if the output file exists and modify the name if it does
# output_file="output.mp4"
# found_file=1
# base_output_file="${output_file%.*}"

# while [[ -f "$output_file" ]]; do    
#     echo "'$output_file' is already exists, use new name '${base_output_file}-${found_file}.mp4'"
#     output_file="${base_output_file}-${found_file}.mp4"
#     ((found_file++))
# done

# Check if the output file exists and modify the name if it does
video_output_filename="output.mp4"
found_file=1
base_video_output_file="${video_output_filename%.*}"

while [[ -f "$video_output_filename" ]]; do    
    echo "'$video_output_filename' is already exists, use new name '${base_video_output_file}-${found_file}.mp4'"
    video_output_filename="${base_video_output_file}-${found_file}.mp4"
    ((found_file++))
done


# 1st == working good with proper aspect ratio BUT hardcoded to 3 images
# cli="ffmpeg \
# -loop 1 -t 3 -i resized_1.png \
# -loop 1 -t 3 -i resized_2.png \
# -loop 1 -t 3 -i resized_3.png \
# -filter_complex \" \
# [0:v]format=rgba,scale=$max_width:$max_height,setsar=1[v0]; \
# [1:v]format=rgba,scale=$max_width:$max_height,setsar=1[v1]; \
# [2:v]format=rgba,scale=$max_width:$max_height,setsar=1[v2]; \

# color=size=${max_width}x${max_height}:duration=9:rate=30:color=black[base]; \

# [base][v0]overlay=x='if(between(t,0,0.5),-w+(t/0.5)*w,if(between(t,0.5,2.5),0,(t-2.5)/0.5*w))':y=0:enable='between(t,0,3)'[slide1]; \
# [slide1][v1]overlay=x='if(between(t,3,3.5),-w+((t-3)/0.5)*w,if(between(t,3.5,5.5),0,((t-5.5)/0.5*w)))':y=0:enable='between(t,3,6)' [slide2]; \
# [slide2][v2]overlay=x='if(between(t,6,6.5),-w+((t-6)/0.5)*w,if(between(t,6.5,8.5),0,((t-8.5)/0.5*w)))':y=0:enable='between(t,6,9)' \
# \" \
# -c:v libx264 -s \"$video_resolution\" -pix_fmt yuv420p \"$output_file\""


# 2nd == working good with dynamic number of images
#images=( resized_*.png )
#images=( $(ls resized_*.png | sort -V) ) # sort -V to sort by version number
mapfile -t images < <(ls resized_*.png | sort -V)

#num_images=${#images[@]}

total_duration=$((resized_total_file * per_image_duration))
fps=30  # Frames per second

# Build input arguments dynamically
# Prepare input arguments (including background image)
input_args=()
#input_args=(-loop 1 -t "$total_duration" -i background-cover.jpg)
for img in "${images[@]}"; do
  input_args+=(-loop 1 -t "$per_image_duration" -i "$img")
done

# Initialize filter_complex
filter=""

# Background base from image (if exists)
#filter+="[0:v]format=rgba,scale=${max_width}:${max_height},setsar=1[base];"

# Build scaling filters dynamically
for ((i=0; i<resized_total_file; i++)); do
  #filter+="[$i:v]format=rgba,scale=${video_width}:${video_height},setsar=1[v$i];"
  # no need to set format=rgba, because there is no overlay (eg: text/image) on top of the image
  filter+="[$i:v]scale=${video_width}:${video_height},setsar=1[v$i];"

  #input_idx=$((i + 1)) # +1 because the first input is the background image
  #filter+="[$input_idx:v]format=rgba,scale=${max_width}:${max_height},setsar=1[v$i];"

  
done

# Create BLACK base background canvas
filter+="color=size=${video_width}x${video_height}:duration=${total_duration}:rate=$fps:color=black[base];"

# Build sliding overlay dynamically
current_time=0
last_slide="[base]"

# working good for simple sliding effect
for ((i=0; i<resized_total_file; i++)); do
  start_time=$current_time
  end_time=$((current_time + per_image_duration))
  t_in_end=$(echo "$start_time + 0.5" | bc)
  t_out_start=$(echo "$end_time - 0.5" | bc)

  # SLIDE IN from left to right
  #overlay_x="if(between(t,$start_time,$t_in_end),-w+(t-$start_time)/0.5*w,if(between(t,$t_in_end,$t_out_start),0,(t-$t_out_start)/0.5*w))"

  # SLIDE IN from right to left  
  overlay_x="if(between(t,$start_time,$t_in_end),w-(t-$start_time)/0.5*w,if(between(t,$t_in_end,$t_out_start),0,-(t-$t_out_start)/0.5*w))"

  filter+="$last_slide[v$i]overlay=x='$overlay_x':y=0:enable='between(t,$start_time,$end_time)'[slide$i];"

  last_slide="[slide$i]"
  current_time=$end_time
done


if [ $watermark_text_length -gt 0 ]; then
  # Add watermark to each slide
  # the last filter 
  filter+="${last_slide}drawtext=text='${watermark_text}':fontcolor=white:fontsize=48:x=w-text_w-20:y=h-text_h-20[watermarked];"
  last_slide="[watermarked]"
fi

# Remove only the trailing semicolon
filter="${filter%;}"

# Full FFmpeg command using an array --> safer
cli=(ffmpeg 
  "${input_args[@]}"
  -filter_complex "$filter"
  -map "$last_slide" 
  -c:v libx264 
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
