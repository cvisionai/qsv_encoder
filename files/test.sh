#!/bin/bash

apt-get update && apt-get install -y wget
mkdir /scratch
cd /scratch
wget http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4
ffmpeg -i ForBiggerBlazes.mp4 -c:v hevc_qsv hevc.mp4
ffmpeg -i ForBiggerBlazes.mp4 -c:v h264_qsv h264.mp4

echo "Video files are in '/scratch'"
du -hs /scratch/*.mp4
