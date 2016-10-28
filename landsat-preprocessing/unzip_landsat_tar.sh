#!/usr/bin/env bash

# unzip and organize downloaded Landsat data to folders.
# 
# written based on Chris Holden's Landsat preprocessing tutorial here:
# the Chapter 4 of https://github.com/ceholden/landsat_preprocess
# 
# Zhan Li, zhan.li@umb.edu
# Created: Sun Feb 28 11:02:26 EST 2016

# !!! currently only support running in the current folder.

# We want to find things ONLY in our current directory, not in any subfolders
#     So, we use -maxdepth 1 option
#     You could also just use "ls *tar.gz", 
#     but find is good to know because it gives you a lot of control

n=$(find ./ -maxdepth 1 -name '*tar.gz' | wc -l)
i=1

for archive in $(find ./ -maxdepth 1 -name '*tar.gz'); do
    echo "<----- $i / $n: $(basename $archive)"
    
    # Create temporary folder for storage
    mkdir temp
    
    # Extract archive to temporary folder
    tar -xzvf $archive -C temp/
    
    # # Find ID based on MTL file's filename
    # mtl=$(find $(pwd)/temp/ -name 'L*MTL.txt')
    
    # # Test to make sure we found it
    # if [ ! -f $mtl ]; then
    #     echo "Could not find MTL file for $archive"
    #     break
    # fi

    # # Use AWK to remove _MTL.txt
    # id=$(basename $mtl | awk -F '_' '{ print $1 }')


    # Find ID based on xml file's filename as sometimes we only
    # download SR data and no MTL file. But xml file will be always
    # there.
    xml=$(find ./temp/ -name 'L*.xml')
    if [[ ! -f ${xml} ]]; then
        echo "Could not find xml file for ${archive}"
        break
    fi
    # Use basename to get Landsat scene ID
    id=$(basename ${xml} '.xml')
    
    # Move archive into temporary folder
    mv $archive ./temp/
    
    # Rename archive
    mv ./temp ./$id
    
    # Iterate count
    let i+=1
done

echo "Done!"
