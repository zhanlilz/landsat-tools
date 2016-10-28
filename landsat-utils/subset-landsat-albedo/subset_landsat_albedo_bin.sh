#!/bin/bash

# subset_landsat_albedo_bin.sh
# 
# Subset Landsat albedo in binary/ENVI format using a sub executable
# developed by Qingsong. This shell script is also adapted from an old
# script by Qingsong and Angela. 
# 
# Zhan Li, zhan.li@umb.edu
# Created: Mon Apr 18 18:03:20 EDT 2016

read -d '' USAGE <<EOF
subset_landsat_albedo_bin.sh

  Subset Landsat albedo in binary/ENVI format of all files in a folder
  given geolocation and footprint size (diameter) and output the stats
  of all pixels in the footprint to a text file.

Usage: 

  subset_landsat_albedo_bin.sh [options]

Options:

  --lat, required, latitude in decimal degree, e.g., --lat=40.125998

  --lon, required, longitude in decimal degree, e.g., --lat=-105.237961

  -w, --window, required, size of subset window/footprint, in meter,
   e.g., -w127, or, --window=127

  -d, --directory, required, input directory to all the Landsat albedo
   files.

  -o, --output, required, file name of output stats.

  -p, --pattern, optional, pattern of Landsat albedo file names for the search of specific Landsat files you want to subset. Default: -p"lndAlbedo*.bin".

EOF

# some default setting
exe="/home/zhan.li/Workspace/src-programs/landsat-tools/landsat-utils/subset-landsat-albedo/sub"
pattern="lndAlbedo*.bin"

OPTS=`getopt -o w:d:o:p:: --long lat:,lon:,window:,directory:,output:,pattern:: -n 'subset_landsat_albedo' -- "$@"`
if [[ $? != 0 ]]; then echo "Failed parsing options"; exit 1; fi
eval set -- "${OPTS}"
while true; 
do
    case "${1}" in
        --lat )
            case "${2}" in
                "") shift 2 ;;
                *) lat=${2} ; shift 2 ;;
            esac ;;
        --lon )
            case "${2}" in
                "") shift 2 ;;
                *) lon=${2} ; shift 2 ;;
            esac ;;
        -w | --window )
            case "${2}" in
                "") shift 2 ;;
                *) window=${2} ; shift 2 ;;
            esac ;;
        -d | --directory )
            case "${2}" in
                "") shift 2 ;;
                *) dir=${2} ; shift 2 ;;
            esac ;;
        -o | --output )
            case "${2}" in
                "") shift 2 ;;
                *) out=${2} ; shift 2 ;;
            esac ;;
        -p | --pattern )
            case "${2}" in
                "") shift 2 ;;
                *) pattern=${2} ; shift 2 ;;
            esac ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done
# check arguments
if [ -z ${lat} ] || [ -z ${lon} ] || [ -z ${window} ] || [ -z ${dir} ] || [ -z ${out} ]; then
    echo "Missing required arguments!"
    echo "${USAGE}"
    echo
    exit 1
fi

echo "Lat = ${lat}, Lon = ${lon}"
echo "Footprint = ${window}"
echo "Input directory = ${dir}"
echo "Output file = ${out}"
echo "Albedo file name pattern = ${pattern}"

# lat=40.125998   #TBL
# lon=-105.237961 #TBL
# #window in meter
# window=90       #SF, TBL, 
# dir=/neponset/nbdata07/albedo/Tower_albedo_Landsat/NiwotRidge_albedo
# out=./output/TableMtn2_snowlib4_${lat}_${lon}_30.txt

lnds=($(find $dir/ -name "${pattern}"))

echo "Number of files found = ${#lnds[@]}"

echo "Path_Row,Year,DOY,Lat,Lon,Sensor,Scene_ID,BSA_mean,BSA_sd,BSA_count,WSA_mean,WSA_sd,WSA_count,Blue_mean,Blue_sd,Blue_count" > ${out}
for envi in ${lnds[@]}; do
        base=${envi#*lndAlbedo_}
        echo $base
        year=${base:9:4}
        doy=${base:13:3}
        path=${base:3:3}
        row=${base:6:3}
        sensor=${base:0:3}
        tile="PATH${path}_ROW${row}"
        echo ${year} ${doy} ${sensor} ${tile}

        tmpout=$($exe $envi $lat $lon $window $year $doy $tile $sensor $base)
        if [ $? -ne 0 ]; then
                echo "ERROR, subsetting ${base}"
                continue
        else
            echo ${tmpout} >> ${out}
        fi
done
