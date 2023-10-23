# Duplicate Media Finder 


Duplicate Media Finder is a non-hash-based media comparison tool. Instead of using hashes like nearly every other duplicate file finder out there, this script compares files by examining key pixel attributes from location in both time & space. It supports most video & image files as it utilizes & requires FFmpeg to extract key frames from media. Unlike hash-based tools where even a single pixel will change the entire hash output, this script will deep dive into media and find duplicate files and provide an answer on what it thinks is the better of the two (or more) files. In my tests, it has provided a high degree of accuracy against thousands of files. I’ve scanned it against 21 TB of data, it has a ~99% chance of identifying a video or image that is either smaller in scale or slightly altered via gradient and/or lighting. However, in my attempts to tweak it to capture the remaining 1% it will either produce too many false positives or too many false negatives. The initial scan of a directory can be quite time consuming as it builds finger prints (keys) for each file, however subsequent runs will be much faster once keys are mostly established. This is a script that I have been tweaking for several months and I’m providing it to you for free ;). I hope you enjoy. 

<br/><br/><br/><br/>

## Example Output
In this example, the script had detected 5 videos that are duplicates in the "First 48" folder. 
![alt text](https://github.com/Jukari2003/Duplicate-Media-Finder/blob/main/Documentation/Example%20Output.png?raw=true)


<br/><br/>

## Example of Duplicate Videos Found
The videos were incorrectly named but are actually different variations of the same video.
![alt text](https://github.com/Jukari2003/Duplicate-Media-Finder/blob/main/Documentation/Duplicate%20Videos%20Example.png)

<br/><br/>

## How the System Works
![alt text](https://github.com/Jukari2003/Duplicate-Media-Finder/blob/main/Documentation/How%20it%20works.png)

<br/><br/>





  # Install Instructions:
        - Download Duplicate-Media-Finder.zip from GitHub
            - Top Right Hand Corner Click "Code"
            - Select "Download Zip"
        - Extract Files to a desired location
        - Right Click on "DMF.ps1"
        - Click "Edit"     (This should open up Bullet Blender in Powershell ISE)
        - Once PowerShell ISE is opened. Click the Green Play Arrow.
        - Download FFmpeg: https://www.ffmpeg.org/download.html 
        - Install/Extract FFmpeg to desired location 
  [FFmpeg](https://www.ffmpeg.org/download.html)  
  
            - (FFprobe is required to be in the same directory as FFmpeg)
        - Select the FFmpeg.exe via interface
        - Success
        

  # Possible Errors:
        - Execution-Policy 
            - Some systems may prevent you from executing the script even in PowerShell ISE.
                -   On a Home Computer: Run PowerShell ISE or PowerShell as an administrator
                    - Type the command:
                         -  Set-ExecutionPolicy Unrestricted
                    - Type 
                        -  Y
  
        - You're on a MAC
            - You will need to install PowerShell for MAC
                - https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-7.1
