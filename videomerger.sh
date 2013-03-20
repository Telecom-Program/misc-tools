#!/bin/bash
first_inst=$1
last_inst=$2
inst_start_time=$3
inst_end_time=$4
fps="29.97"

echo
echo "Compressing First & Last Instructor Video and Extracting Audio"
echo "--------------------------------------------------------------"
echo "Running first pass on $first_inst..."
ffmpeg -v panic -y -i $first_inst -ss $inst_start_time -s 1280x720 -c:v libx264 -preset fast -b:v 5M -pass 1 -an -f h264 /dev/null
echo "Running second pass on $first_inst..."
ffmpeg -v panic -i $first_inst -ss $inst_start_time -s 1280x720 -c:v libx264 -preset fast -b:v 5M -pass 2 ${first_inst%\.*}"_final.mp4"
echo "Extracting audio from $first_inst..."
ffmpeg -v panic -i $first_inst -ss $inst_start_time ${first_inst%\.*}"_final.wav"

echo "Running first pass on $last_inst..."
ffmpeg -v panic -y -i $last_inst -s 1280x720 -c:v libx264 -preset fast -b:v 5M -pass 1 -an -f h264 -t $inst_end_time /dev/null
echo "Running second pass on $last_inst..."
ffmpeg -v panic -i $last_inst -s 1280x720 -c:v libx264 -preset fast -b:v 5M -pass 2 -t $inst_end_time ${last_inst%\.*}"_final.mp4"
echo "Extracting audio from $last_inst..."
ffmpeg -v panic -i $last_inst -t $inst_end_time ${last_inst%\.*}"_final.wav"

echo
echo "Compressing Remainder of Videos and Extracting Audio"
echo "-------------------------------------------------------------"
for file in *.MP4
do
	if [ $file != $first_inst ] && [ $file != $last_inst ]; then
		echo "Running first pass on $file..."
		ffmpeg -v panic -y -i $file -s 1280x720 -c:v libx264 -preset fast -b:v 5M -pass 1 -an -f h264 /dev/null
		echo "Running second pass on $file..."
		ffmpeg -v panic -i $file -s 1280x720 -c:v libx264 -preset fast -b:v 5M -pass 2 ${file%\.*}"_final.mp4"
		echo "Extracting audio from $file..."
		ffmpeg -v panic -i $file ${file%\.*}"_final.wav"
	fi
done

echo
echo "Concatenating, Enhancing, & Converting Audio"
echo "-------------------------------------------------------------"
sox *.wav --norm --guard -c 1 final.wav
read -p "Review final.wav (Press Enter to continue)" yn
echo "Encoding audio back to aac..."
ffmpeg -v panic -i final.wav final.aac

echo
echo "Concatenating Video"
echo "-------------------------------------------------------------"
echo "Creating final.mp4..."
MP4Box -fps $fps -add ${first_inst%\.*}_final.mp4 final.mp4
for file in *_final.mp4
do
    if [ $file != ${first_inst%\.*}_final.mp4 ]; then
        echo "Concatting $file..."
	    MP4Box -cat $file final.mp4
    fi
done
MP4Box -rem 2 final.mp4
MP4Box -add final.aac final.mp4
