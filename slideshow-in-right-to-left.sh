#!/bin/bash
# slideshow-in-right-to-left.sh

# Check if exactly 3 arguments are provided
if [ "$#" -ne 2 ]; then
    echo "--------------"
    # echo "Total parameters: $#"
    # echo "Not enough parameters."
    echo "Usage: $0 [filename wildcard] [per-image duration]"
    echo "example:"
    echo "$0 \"MyPhoto*.jpg\" 3"
    exit 1
fi

# Assign the arguments to variables
image_file_wild_card=$1
per_image_duration=$2
#transition_duration=$3 # fading need slower time

# Print the input parameters (optional, for debugging purposes)
echo "Filename wildcard: $image_file_wild_card"
echo "Per-image duration: $per_image_duration"

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
found=0

for filename in $(ls $image_file_wild_card 2>/dev/null); do
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

video_resolution="${max_width}x${max_height}"

# Check if the output file exists and modify the name if it does
output_file="output.mp4"
found_file=1
base_output_file="${output_file%.*}"

while [[ -f "$output_file" ]]; do    
    echo "'$output_file' is already exists, use new name '${base_output_file}-${found_file}.mp4'"
    output_file="${base_output_file}-${found_file}.mp4"
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
images=( resized_*.png )
num_images=${#images[@]}
#slide_duration=3  # Duration per slide in seconds
total_duration=$((num_images * per_image_duration))
fps=30  # Frames per second

# Build input arguments dynamically
input_args=()
for img in "${images[@]}"; do
  input_args+=(-loop 1 -t "$per_image_duration" -i "$img")
done

# Initialize filter_complex
filter=""
# Build scaling filters dynamically
for ((i=0; i<num_images; i++)); do
  filter+="[$i:v]format=rgba,scale=${max_width}:${max_height},setsar=1[v$i];"
done

# Create base background canvas
filter+="color=size=${max_width}x${max_height}:duration=${total_duration}:rate=$fps:color=black[base];"

# Build sliding overlay dynamically
current_time=0
last_slide="[base]"

# working good for simple sliding effect
for ((i=0; i<num_images; i++)); do
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

# Remove the trailing semicolon and bracket references
filter="${filter%\[slide$((num_images-1))\];}"

# Full FFmpeg command using an array
cli=(ffmpeg \
  "${input_args[@]}" \
  -filter_complex "$filter" \
  -c:v libx264 \
  -r "$fps" \
  -s "$video_resolution" \
  -pix_fmt yuv420p \
  "$output_file"
)

# # display (to review during debugging) command before execute
echo "**********CLI*********"
echo "${cli[@]}"
echo "**********************"

# # execute
# eval "$cli"
# without eval
"${cli[@]}"
