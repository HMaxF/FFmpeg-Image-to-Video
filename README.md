# Collection of shell script to use FFMPEG to create video from images
Main documentation of FFMPEG parameters: https://www.ffmpeg.org/ffmpeg.html

# TIP: update OS drivers to use hardware acceleration
In Fedora, use:
```
# Install the VA-API drivers with proprietary codecs (HEVC/H.265, H.264/AVC)
# For AMD, this replaces the default Fedora 'mesa-va-drivers'
sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld

# Install VDPAU drivers with proprietary codecs
# This replaces the default Fedora 'mesa-vdpau-drivers'
sudo dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld

# Install the VA-API utilities to check supported codecs
sudo dnf install libva-utils

# Run the check
vainfo

# should see a line like: VAProfileHEVCMain : VAEntrypointVLD
```

## Verify hardware acceleration is working properly
1. Use ffmpeg
```
$ ffmpeg -hwaccels
ffmpeg version 6.1.2 Copyright (c) 2000-2024 the FFmpeg developers
  built with gcc 14 (GCC)
  configuration: --prefix=/usr --bindir=/usr/bin --datadir=/usr/share/ffmpeg --docdir=/usr/share/doc/ffmpeg --incdir=/usr/include/ffmpeg --libdir=/usr/lib64 --mandir=/usr/share/man --arch=x86_64 --optflags='-O2 -flto=auto -ffat-lto-objects -fexceptions -g -grecord-gcc-switches -pipe -Wall -Wno-complain-wrong-lang -Werror=format-security -Wp,-U_FORTIFY_SOURCE,-D_FORTIFY_SOURCE=3 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -m64 -march=x86-64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer' --extra-ldflags='-Wl,-z,relro -Wl,--as-needed -Wl,-z,pack-relative-relocs -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -Wl,--build-id=sha1 ' --extra-cflags=' -I/usr/include/rav1e' --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libvo-amrwbenc --enable-version3 --enable-bzlib --enable-chromaprint --disable-crystalhd --enable-fontconfig --enable-frei0r --enable-gcrypt --enable-gnutls --enable-ladspa --enable-lcms2 --enable-libaom --enable-libdav1d --enable-libass --enable-libbluray --enable-libbs2b --enable-libcodec2 --enable-libcdio --enable-libdrm --enable-libjack --enable-libjxl --enable-libfreetype --enable-libfribidi --enable-libgsm --enable-libharfbuzz --enable-libilbc --enable-libmp3lame --enable-libmysofa --enable-nvenc --enable-openal --enable-opencl --enable-opengl --enable-libopenh264 --enable-libopenjpeg --enable-libopenmpt --enable-libopus --enable-libpulse --enable-libplacebo --enable-librsvg --enable-librav1e --enable-librubberband --enable-libsmbclient --enable-version3 --enable-libsnappy --enable-libsoxr --enable-libspeex --enable-libsrt --enable-libssh --enable-libsvtav1 --enable-libtesseract --enable-libtheora --enable-libtwolame --enable-libvorbis --enable-libv4l2 --enable-libvidstab --enable-libvmaf --enable-version3 --enable-vapoursynth --enable-libvpx --enable-vulkan --enable-libshaderc --enable-libwebp --enable-libx264 --enable-libx265 --enable-libxvid --enable-libxml2 --enable-libzimg --enable-libzmq --enable-libzvbi --enable-lv2 --enable-avfilter --enable-libmodplug --enable-postproc --enable-pthreads --disable-static --enable-shared --enable-gpl --disable-debug --disable-stripping --shlibdir=/usr/lib64 --enable-lto --enable-libvpl --enable-runtime-cpudetect
  libavutil      58. 29.100 / 58. 29.100
  libavcodec     60. 31.102 / 60. 31.102
  libavformat    60. 16.100 / 60. 16.100
  libavdevice    60.  3.100 / 60.  3.100
  libavfilter     9. 12.100 /  9. 12.100
  libswscale      7.  5.100 /  7.  5.100
  libswresample   4. 12.100 /  4. 12.100
  libpostproc    57.  3.100 / 57.  3.100
Hardware acceleration methods:
vdpau
cuda
vaapi
qsv
drm
opencl
vulkan
```
3. Use vlc to open x265 video:
```
$ vlc --avcodec-hw=vaapi my_x265_video.mp4
VLC media player 3.0.21 Vetinari (revision 3.0.21-0-gdd8bfdbabe8)
[0000561c134d1520] main libvlc: Running vlc with the default interface. Use 'cvlc' to use vlc without interface.
libva info: VA-API version 1.21.0
libva info: Trying to open /usr/lib64/dri-nonfree/radeonsi_drv_video.so
libva info: Trying to open /usr/lib64/dri-freeworld/radeonsi_drv_video.so
libva info: Trying to open /usr/lib64/dri/radeonsi_drv_video.so
libva info: Found init function __vaDriverInit_1_21
libva info: va_openDriver() returns 0
[00007f6d64c0f0b0] avcodec decoder: Using Mesa Gallium driver 24.1.7 for AMD Radeon Graphics (radeonsi, renoir, LLVM 18.1.6, DRM 3.59, 6.11.5-200.fc40.x86_64) for hardware decoding
...
```

# FFMPEG filter documentation
FFMPEG filter_complex for zoompan parameters: https://ffmpeg.org/ffmpeg-filters.html#zoompan

## zoompan
```
zoompan=z='$zoom_expr':x='$x_expr':y='$y_expr':d=1:s=$video_resolution:fps=$fps
```
zoom, z ==> Set the zoom expression. Range is 1-10. Default is 1.0 (full image resolution).  
<b>Notes</b>: a value > 1.0 means zoom IN, a value of < 1.0 means zoom OUT.

x,y ==> Set the x and y expression. Default is 0,0 (top left)   
<b>Notes</b>: x,y will be the center point of zoom (in or out)

s ==> target video resolution, default: 'hd720'  
<b>Notes</b>: can use any resolution, eg: 789x345

d ==> Set the duration expression in number of frames. This sets for how many number of frames effect will last for single input image. Default is 90.

fps ==> Very important to make sure internal zoompan use the right framerate to avoid breaking animation.


# BONUS TIPS

## 1. To create high quality video
1. Use [**-crf 18**] to use higher bitrate (default 23 for x264, 28 for x265)
2. Use [**-color_range 2**] to use YUV 4:2:0 full range brightness 0–255 (instead of default limited 16-235)
3. Use [**-movflags +faststart**] to move the MP4 “moov atom” (metadata header) to the beginning of the file for faster decode, especially for streaming and video thumbnail viewer.
   
Example command:
```
ffmpeg -hide_banner -loop 1 -t $DUR -i "$temp_scaled_image" -filter_complex "\
zoompan=z='${zoom_expr}':\
x='(iw-(iw/zoom))/2':\
y='(ih-(ih/zoom))/2':\
d=1:\
s=${video_width}x${video_height}:\
fps=${fps}
" -c:v libx264 -color_range 2 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart "$output"
```

## 1. To combine a video and an audio using fade-in in the beginning and fade out at the end
```
ffmpeg -i "video.mp4" -ss 4:00 -i "audio.m4a" -filter_complex [1:a]afade=t=in:st=0:d=3,afade=t=out:st=58:d=4[aud] -map 0:v -map "[aud]" -c:v copy -c:a aac -shortest "video-with-audio.mp4"
```

## 2. Fasten operation by not using 'scale' and 'crop' in filter
1. Use pre-scale and the right aspect ratio of image for the video
   - Example: desired output video resolution 2160x3840 (9:16)
   - Scale the image to use the same ratio, use padding (black bar) is necessary.
     * Example to keep width but adjust height to make same aspect ratio and convert to webp 95% quality (smaller filesize but same quality as JPG)
       ```
       $ ffmpeg -hide_banner -y -i "$input_image" -vf "scale=iw:-1,pad=iw:(iw*${video_height}/${video_width}):0:(ow-ih)/2:black" -q:v 95 "$temp_scaled_image"
       ```

## 3. To get partial/shorter video from long video
```
ffmpeg -ss 1:20 -t 5 -i input_long_video.mp4 -vf "transpose=$TRANSPOSE" -r 30 -crf 18 -preset ultrafast -c:a copy output_short_video.mp4
```
NOTES:
1. '-ss' and '-t' parameters SHOULD BE DEFINED BEFORE '-i' parameter to skip forward faster!
2. 'transpose' parameter is optional, it is to rotate, values are:
   - transpose=0: Rotate by 90 degrees counter-clockwise and flip vertically. This is the default.
   - transpose=1: Rotate by 90 degrees clockwise.
   - transpose=2: Rotate by 90 degrees counter-clockwise.
   - transpose=3: Rotate by 90 degrees clockwise and flip vertically.
