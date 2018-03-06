#!/bin/bash

read -d '' USAGE <<EOF
$(basename ${0}) --mtl full_path_to_mtl_file

EOF

function echoErrorStr () 
{
    echo -e $(date +"%Y-%m-%d %T")" [ERR] "'\033[31m'${1}'\033[0m'
}
function echoWarnStr () 
{
    echo -e $(date +"%Y-%m-%d %T")" [WRN] "'\033[33m'${1}'\033[0m'
}
function echoInfoStr () 
{
    echo -e $(date +"%Y-%m-%d %T")" [INF] "'\033[32m'${1}'\033[0m'
}
function echoStatStr () 
{
    echo -e $(date +"%Y-%m-%d %T")" [STA] "'\033[0m'${1}'\033[0m'
}

RUN_DIR=$(pwd)

OPTS=`getopt -o "" --long mtl: -n "$(basename ${0})" -- "$@"`
if [[ $? != 0 ]]; then echo "Failed to parse options" >&2 ; echo ${USAGE} ; exit 1 ; fi
eval set -- "${OPTS}"
while true
do
    case "${1}" in
        --mtl )
            case "${2}" in
                "") shift 2 ;;
                *) MTL=${2} ; shift 2 ;;
            esac ;;
        -- ) shift ; break ;;
        * ) break ;;
    esac
done

if [[ -z ${MTL} ]]; then
    echo "Missing MTL file"
    echo ${USAGE}
    exit 1
fi
if [[ ! -r ${MTL} ]]; then
    echo "Cannot access ${MTL}"
    echo ${USAGE}
    exit 1
fi

echoStatStr "Getting surface reflectance from ${MTL}"

# Check solar zenith angle, skip if > 76 deg. 
SEA=$(grep "SUN_ELEVATION" ${MTL} | cut -d'=' -f2 | tr -d " ")
SZA=$(echo "90-${SEA}" | bc -l)
if [[ $(echo "${SZA}>76" | bc -l) -eq 1 ]]; then
    echoWarnStr "Solar zenith angle ${SZA} > 76 deg, skip surface reflectance generation!"
    exit 0
fi

MTLDIR=$(dirname ${MTL})
TMP=$(basename ${MTL})
PRD_ID=${TMP%"_MTL.txt"}

for f in ${MTLDIR}/*.TIF; do
    echoStatStr "Converting tiled TIF to non-tiled ${f}"
    mv $f $f.old
    gdal_translate $f.old $f
    if [[ $? == 0 ]]; then
        rm -f $f.old
    else
        echoErrorStr "Failed to convert to non-tiled TIF for ${f}"
        exit 2
    fi
done

cd ${MTLDIR}

# Must use basename of MTL, otherwise product_id in the xml file will
# contain path names.
echoStatStr "Starting convert_lpgs_to_espa for $(basename ${MTL})"
convert_lpgs_to_espa --mtl=$(basename ${MTL}) --del_src_files

XML_FNAME=${PRD_ID}.xml

echoStatStr "Starting do_lasrc.py for ${XML_FNAME}"
do_lasrc.py --xml=${XML_FNAME}

echoStatStr "Starting generate_pixel_qa for ${XML_FNAME}"
generate_pixel_qa --xml=${XML_FNAME}

echoStatStr "Starting dilate_pixel_qa for ${XML_FNAME}"
dilate_pixel_qa --bit=5 --distance=3 --xml=${XML_FNAME}

echoStatStr "Starting convert_espa_to_gtif for ${XML_FNAME}"
convert_espa_to_gtif --xml=${XML_FNAME} --gtif=${PRD_ID} --del_src_files

cd ${RUN_DIR}
echoStatStr "Got surface reflectance from ${MTL}"
