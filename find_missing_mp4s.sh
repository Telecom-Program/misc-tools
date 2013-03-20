#!/bin/bash
dir=$1
results=`find $dir -name screen0.asf`
for file in $results
do
    echo $file
done
