#!/bin/bash
# panorama-to-video.sh

# use an image to create a video by zooming-in to the image center

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

# duration
DUR=20

# fps 
fps=25

# 
# ffmpeg -loop 1 -i your_image.jpg -filter_complex "zoompan=z='if(lte(zoom,1.0),1.5,max(1.0015,zoom-0.0005))':d=125:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=3840x2160" -c:v libx264 -t 10 -pix_fmt yuv420p output.mp4

#ffmpeg -loop 1 -i your_image.jpg -filter_complex "zoompan=z='if(lte(zoom,1.0),1.5,max(1.0015,zoom-0.0005))':d=125:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=3840x2160" -c:v libx264 -pix_fmt yuv420p -t 10 output.mp4

# d=10*60 ==> time in seconds * FPS
#ffmpeg -loop 1 -framerate 60 -i DSC01000.JPG -vf "zoompan=z='min(zoom+0.0015,1.5)':d=10*60:fps=60, fade=in:0:30" -s 3840x2160 -t 10 -c:v libx264 -pix_fmt yuv420p output.mp4

#ffmpeg -loop 1 -framerate 60 -i image.jpg -vf "scale=8000:-1,zoompan=z='zoom+0.001':x=iw/2-(iw/zoom/2):y=ih/2-(ih/zoom/2):d=5*60:s=1920x1280:fps=60" -t 5 -c:v libx264 -pix_fmt yuv420p output.mp4

#ffmpeg -loop 1 -i your_image.jpg -filter_complex "zoompan=z='if(lte(zoom,1.0),1.5,max(1.0015,zoom-0.0005))':d=125:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=3840x2160" -c:v libx264 -pix_fmt yuv420p -t 10 output.mp4

# ZOOM TO THE CENTER to the image 
# scale=8000:-1 ==> scale the image to 8000xwhatever height
# -1 ==> keep image ratio (http://trac.ffmpeg.org/wiki/Scaling)
# -2 ==> keep ratio
# scale=iw:ih ==> keep the ratio the same as INPUT WIDTH and INPUT HEIGHT
# zoompan=z='zoom+0.001' ==> smooth butter zoom in, if higher then the video is jittery
# x=iw/2-(iw/zoom/2):y=ih/2-(ih/zoom/2) ==> center the image to the screen
# x=0,y=0 ==> zoom in to top left

# TODO: continue to make smoother zooming in

ffmpeg -loop 1 -framerate $fps -i "$input_file" -vf "scale=w=3840:h=-1:force_original_aspect_ratio=1,zoompan=z='zoom+0.001':x=iw/2-(iw/zoom/2):y=ih/2-(ih/zoom/2):d=10*60:s=3840x2160:fps=$fps" -t $DUR -c:v libx264 -pix_fmt yuv420p $output_file
