# Dpulicate-Media-Finder
Provides a non-hash based approach to finding duplicate videos &amp; images

Duplicate Media Finder is a non-hash-based media comparison tool. Instead of using hashes like nearly every other duplicate file finder out there, this script compares files by examining key pixel attributes from location in both time & space. It supports most video & image files as it utilizes & requires FFmpeg to extract key frames from media. Unlike hash-based tools where even a single pixel will change the entire hash output, this script will deep dive into media and find duplicate files and provide an answer on what it thinks is the better of the two (or more) files. In my tests, it has provided a high degree of accuracy against thousands of files. I’ve scanned it against 21 TB of data, it has a ~99% chance of identifying a video or image that is either smaller in scale or slightly altered via gradient and/or lighting. However, in my attempts to tweak it to capture the remaining 1% it will either produce too many false positives or too many false negatives. The initial scan of a directory can be quite time consuming as it builds finger prints (keys) for each file, however subsequent runs will be much faster once keys are mostly established. This is a script that I have been tweaking for several months and I’m providing it to you for free ;). I hope you enjoy. 

<br/><br/><br/><br/><br/><br/><br/><br/>

## Example Output
![alt text](https://github.com/Jukari2003/Duplicate-Media-Finder/blob/main/Documentation/Example%20Output.png?raw=true)


<br/><br/>

## Example of Duplicate Videos Found (Incorrectly Named) 
![alt text](https://github.com/Jukari2003/Duplicate-Media-Finder/blob/main/Documentation/Duplicate%20Videos%20Example.png)

<br/><br/>

## How the System Works
![alt text](https://github.com/Jukari2003/Duplicate-Media-Finder/blob/main/Documentation/How%20it%20works.png)

<br/><br/>
[FFmpeg](https://www.ffmpeg.org/download.html) 
