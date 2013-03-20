#!/bin/bash
first_inst=$1
last_inst=$2
desktop_video=$3
final_output=$4
fps="29.97"


echo
echo "Extracting Audio from Desktop, First, & Last Instructor Video"
echo "-------------------------------------------------------------"
echo "Generating desktop.wav..."
ffmpeg -v panic -i $desktop_video desktop.wav
echo "Generating instructor-start.wav..."
ffmpeg -v panic -i $first_inst instructor-start.wav
echo "Generating instructor-end.wav..."
ffmpeg -v panic -i $last_inst instructor-end.wav



echo
echo "Review the Audio files and enter start & end times"
echo "-------------------------------------------------------------"
read -p "Enter the instructor video start time: " inst_start_time
read -p "Enter the desktop video start time: " desk_start_time
read -p "Where should the video end in ($last_inst): " inst_end_time

rm instructor-start.wav
rm desktop.wav
rm instructor-end.wav



echo
echo "Converting Desktop Video to 29.97 FPS (and cropping if needed)"
echo "--------------------------------------------------------------"
desk_res=`ffprobe -v quiet -print_format csv -show_streams -select_streams v:0 $desktop_video | awk -F "," '{print $10 "x" $11}'`
case $desk_res in
	"1024x768") echo "Current resolution is acceptable, converting to 29.97 fps..."
                ffmpeg -v panic -i $desktop_video -ss $desk_start_time -r 29.97 -c:v libx264 -preset ultrafast -an desktop-final.mp4
                ;;
	"1440x900") echo "Cropping from 1440x900 and converting to 29.97fps..."
                ffmpeg -v panic -i $desktop_video -ss $desk_start_time -r 29.97 -vf "crop=1201:899:120:0,scale=1024:768" \
				-c:v libx264 -preset ultrafast -an desktop-final.mp4
                ;;
	*) echo "Unsupported desktop video resolution ($desk_res)!"; exit;;
esac



echo
echo "Compressing First & Last Instructor Video and Extracting Audio"
echo "--------------------------------------------------------------"
# 2: CONVERT FIRST & LAST INSTRUCTOR VIDEO & EXTRACT AUDIO
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
read -p "Review final.wav and make adjustments if needed (Type Y to continue)" yn
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


echo
echo "Packaging Final Product"
echo "-------------------------------------------------------------"
echo "Building final output as $final_output... "
case $final_output in
    "720p") ffmpeg -v panic -i final.mp4 -i desktop-final.mp4 -i ceo720p.png -filter_complex \
            '[0]scale=320:180,pad=iw+960:ih+540[inst];[1]scale=960:720,[inst]overlay=320:0[final];[final]overlay=0:180' \
            -c:v libx264 -preset fast -crf 18 -profile:v high -s 1280x720 outputFinal720p.mp4
            ;;
    "1080p") ffmpeg -v panic -i final.mp4 -i desktop-final.mp4 -i ceo.png -filter_complex \ 
             '[0]scale=480:270,pad=iw+1440:ih+810[inst];[1]scale=1440:1080,[inst]overlay=480:0[final];[final]overlay=0:270' \
             -c:v libx264 -preset ultrafast -crf 18 -profile:v high -s 1920x1080 -t 60 outputFinal1080p.mp4
            ;;
esac
