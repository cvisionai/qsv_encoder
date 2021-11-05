#!/bin/bash

apt-get update && apt-get install -y wget
mkdir /scratch
cd /scratch
wget http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4
ffmpeg -i ForBiggerBlazes.mp4 -c:v hevc_qsv hevc.mp4
ffmpeg -i ForBiggerBlazes.mp4 -c:v h264_qsv h264.mp4

# Test gstreamer method
gst-launch-1.0 -e videotestsrc num-buffers=500 ! videoconvert ! mfxvpp width=1280 height=720 ! mfxh264enc ! qtmux fragment-duration=1000 ! progressreport update-freq=1 ! filesink location=gstreamer.mp4

echo "Video files are in '/scratch'"
du -hs /scratch/*.mp4
