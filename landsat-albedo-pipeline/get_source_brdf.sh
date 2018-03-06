#!/bin/bash

read -d '' USAGE <<EOF
$(basename ${0}) [options] --od output_dir target_xml mate_xml1 mate_xml2 ... mate_xmln

Options:

  --od="OUTPUT_DIRECTORY", required
    Output directory where a subfolder named with product ID is
    created; In this subfolder, albedo product files for this
    target_xml are saved.

  --brdf="SOURCE_BRDF_TYPE", optional
    Source dataset of BRDF, 'MODIS' or 'VIIRS'. Default: 'MODIS'

  --format="BRDF_FILE_FORMAT", optional
    Designate output format in either "hdf" or "h5"; default:
    hdf. Notice: at this moment writing h5 is much slower than writing
    hdf for some reason.

Arguments:

  target_xml, 
    The xml file of the target Landsat scene for which albedo is
    generated. This MUST be in front of all the remaining helping xml
    files.

  mate_xml1, mate_xml2 ... mate_xmln
    The xml files of helping Landsat scenes to mosaic with the target
    scene for unsupervised classification in the BRDF association
    procedure.

e.g.

$(basename ${0}) --od /full/path/to/my/folder/landsat-albedo /full/path/to/my/target_xml/LC08_L1TP_018030_20150822_20170225_01_T1.xml /full/path/to/my/mate_xml1/LC08_L1TP_018029_20150822_20170225_01_T1.xml /full/path/to/my/mate_xml2/LC08_L1TP_018031_20150822_20170225_01_T1.xml

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

exe_dir=$(readlink -f ${0} | xargs dirname)

alb_dir="/home/zl69b/Workspace/src/landsat-albedo"
brdf_dl_cmd="/home/zl69b/Workspace/src/mvp-tools/common-utils/dl_lp_daac_mvp.sh"
brdf_dl_user="zhan.li"
brdf_dl_psw="LiZhan1986721615"

run_dir=$(pwd)

MAX_NTILES=9

BRDF="MODIS"
OUTFMT="hdf"
OPTS=`getopt -o "" --long od:,brdf:,format: -n "${0}" -- "$@"`
if [[ $? != 0 ]]; then echo "Failed parsing options" >&2 ; echo "${USAGE}" ; exit 1 ; fi
eval set -- "${OPTS}"
while true;
do
    case "${1}" in
        --od )
            case "${2}" in
                "") shift 2 ;;
                *) OUTDIR=${2} ; shift 2 ;;
            esac ;;
        --brdf )
            case "${2}" in
                "") shift 2 ;;
                *) BRDF=${2^^} ; shift 2 ;;
            esac ;;
        --format )
            case "${2}" in
                "") shift 2 ;;
                *) OUTFMT=${2} ; shift 2 ;;
            esac ;;
        -- ) shift ; break ;;
        * ) break ;;
    esac
done
MINPARAMS=1
if [[ ${#} < ${MINPARAMS} ]]; then
    echo "Missing positional arguments"
    echo "${USAGE}"
    exit 1
fi

XML_LIST=()
for ((i=1; i<=${#}; i++)); do
    eval TMP=\${${i}}
    XML_LIST[$((i-1))]=$(readlink -m ${TMP})
done

OUTFMT=${OUTFMT,,}
if [[ ${OUTFMT} != "hdf" && ${OUTFMT} != "h5" ]]; then
    echo "Output format ${OUTFMT} not recognized! Must be 'hdf' or 'h5'."
    echo
    echo "${USAGE}"
    exit 1
fi

if [[ ${BRDF} == "MODIS" ]]; then
    mos_exe=${alb_dir}/bin/modis_sub2
    brdf_fmt="hdf"
    brdf_vnum="6"
    brdf_prd=("MCD43A1" "MCD43A2")
elif [[ ${BRDF} == "VIIRS" ]]; then
    mos_exe=${alb_dir}/bin/viirs_sub2
    brdf_fmt="h5"
    brdf_vnum="5000"
    brdf_prd=("VNP43MA1" "VNP43MA2")
else
    echo "Unrecognized BRDF source ${BRDF}."
    echo
    echo "${USAGE}"
    exit 1
fi

echoStatStr "Getting ${BRDF} BRDF to cover ${XML_LIST[@]}"

# Print some processing metadata before running
if [[ -x ${brdf_dl_cmd} ]]; then
    echoStatStr "Checked, source BRDF downloading command = ${brdf_dl_cmd}"
else
    echoErrorStr "Not found or executable, source BRDF downloading command = ${brdf_dl_cmd}"
    exit 2
fi
if [[ -x ${mos_exe} ]]; then
    echoStatStr "Checked, source BRDF subsetting command = ${mos_exe}"
else
    echoErrorStr "Not found or executable, source BRDF subsetting command = ${mos_exe}"
    exit 2
fi

# Get product_id
PRD_ID=$(grep product_id ${XML_LIST[0]} | cut -d'>' -f2 | cut -d'<' -f1 | xargs basename)
if [[ -z ${PRD_ID} ]]; then
    echoErrorStr "Failed to extract product_id from the XML ${XML_LIST[0]}"
    exit 2
fi
# Get acquisition date and doy
TMP=$(echo ${PRD_ID} | cut -d'_' -f4)
DOY=$(date -d ${TMP} +%j)
YEAR=${TMP:0:4}

# number of xml files
num_f=${#XML_LIST[@]}
mos_xml_param=${XML_LIST[@]}
# Find the needed MODIS tiles
mos_out=$($mos_exe NULL NULL NULL ${num_f} ${mos_xml_param} -p | grep -i "tiles")

echoInfoStr "Output from $mos_exe NULL NULL NULL ${num_f} ${mos_xml_param} -p | grep -i \"tiles\""
echoInfoStr "${mos_out}"

tile_hstr=$(echo ${mos_out} | cut -d',' -f1 | cut -d'h' -f2)
tile_vstr=$(echo ${mos_out} | cut -d',' -f2 | cut -d'v' -f2 | cut -d'.' -f1)
tile_hmin=$(echo ${tile_hstr} | cut -d'-' -f1)
tile_hmax=$(echo ${tile_hstr} | cut -d'-' -f2)
tile_vmin=$(echo ${tile_vstr} | cut -d'-' -f1)
tile_vmax=$(echo ${tile_vstr} | cut -d'-' -f2)
if [[ -z ${tile_hmin} || -z ${tile_hmax} || -z ${tile_vmin} || -z ${tile_vmax} ]]; then
    echoErrorStr "Failed to calculate the needed ${BRDF} tiles."
    exit 2
fi

echoStatStr "Downloading ${BRDF} tiles h${tile_hmin}-${tile_hmax}, v${tile_vmin}-${tile_vmax}"

echoInfoStr "hmin = ${tile_hmin}, hmax = ${tile_hmax}, vmin = ${tile_vmin}, vmax = ${tile_vmax}"

tile_hmin=$(( $(echo ${tile_hmin} | sed 's/^0*//') ))
tile_hmax=$(( $(echo ${tile_hmax} | sed 's/^0*//') ))
tile_vmin=$(( $(echo ${tile_vmin} | sed 's/^0*//') ))
tile_vmax=$(( $(echo ${tile_vmax} | sed 's/^0*//') ))

echoInfoStr "hmin = ${tile_hmin}, hmax = ${tile_hmax}, vmin = ${tile_vmin}, vmax = ${tile_vmax}"

if [[ ${tile_hmin} -lt 0 || ${tile_hmax} -gt 35 || ${tile_vmin} -lt 0 || ${tile_vmax} -gt 17 ]]; then
   echoErrorStr "Illegal tile numbers"
   exit 2
fi
nh=$((${tile_hmax}-${tile_hmin}+1))
nv=$((${tile_vmax}-${tile_vmin}+1))
if [[ $(( ${nh} * ${nv} )) -gt ${MAX_NTILES} ]]; then
    echoWarnStr "Scenes on the edge of Sinusoidal? To be dealt with. Skip this case at the moment."
    echoWarnStr "Too many tiles to mosaic for the coverage of ${XML_LIST[@]}"
    exit 0
fi

if [[ ! -d ${OUTDIR} ]]; then
    mkdir -p ${OUTDIR}
fi

for ((i=0; i<${#brdf_prd[@]}; i++));
do
    for ((h=${tile_hmin}; h<=${tile_hmax}; h++));
    do
        for ((v=${tile_vmin}; v<=${tile_vmax}; v++)); 
        do
            ${brdf_dl_cmd} --user ${brdf_dl_user} --password ${brdf_dl_psw} -f ${brdf_fmt} -t h$(printf %02d ${h})v$(printf %02d ${v}) -y ${YEAR} -p "${brdf_prd[i]}" -n ${brdf_vnum} -o ${OUTDIR} -b ${DOY} -e ${DOY}
        done
    done
done

echoStatStr "Got ${BRDF} BRDF to cover ${XML_LIST[@]}."
echo ""
