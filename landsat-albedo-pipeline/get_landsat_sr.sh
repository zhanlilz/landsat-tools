#!/bin/bash

read -d '' USAGE <<EOF

EOF


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

if [[ ! -r ${MTL} ]]; then
    echo "Cannot access ${MTL}"
    exit 1
fi

echo "Getting surface reflectance from ${MTL}"

MTLDIR=$(dirname ${MTL})
TMP=$(basename ${MTL})
PRD_ID=${TMP%"_MTL.txt"}

for f in ${MTLDIR}/*.TIF; do
    mv $f $f.old
    gdal_translate $f.old $f
    if [[ $? == 0 ]]; then
        rm -f $f.old
    fi
done

cd ${MTLDIR}

convert_lpgs_to_espa --mtl=${MTL} --del_src_files

XML_FNAME=${MTLDIR}/${PRD_ID}.xml

do_lasrc.py --xml=${XML_FNAME}

generate_pixel_qa --xml=${XML_FNAME}

dilate_pixel_qa --bit=5 --distance=3 --xml=${XML_FNAME}

convert_espa_to_gtif --xml=${XML_FNAME} --gtif=${PRD_ID} --del_src_files

cd ${RUN_DIR}
echo "Got surface reflectance from ${MTL}"
