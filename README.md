# Collection of shell script to use FFMPEG to create video from images
Main documentation of FFMPEG parameters: https://www.ffmpeg.org/ffmpeg.html

# Brief parameter notes
FFMPEG filter_complex for zoompan parameters: https://ffmpeg.org/ffmpeg-filters.html#zoompan

## zoompan
```
zoompan=z='$zoom_expr':x='$x_expr':y='$y_expr':s=$video_resolution
```
zoom, z ==> Set the zoom expression. Range is 1-10. Default is 1.0 (full image resolution).  
<b>Notes</b>: a value > 1.0 means zoom IN, a value of < 1.0 means zoom OUT.

x,y ==> Set the x and y expression. Default is 0,0 (top left)   
<b>Notes</b>: x,y will be the center point of zoom (in or out)

s ==> target video resolution, default: 'hd720'  
<b>Notes</b>: can use any resolution, eg: 789x345

d ==> Set the duration expression in number of frames. This sets for how many number of frames effect will last for single input image. Default is 90.


