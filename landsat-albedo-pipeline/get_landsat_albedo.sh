#!/bin/bash

read -d '' USAGE <<EOF
$(basename ${0}) [options] --od output_dir target_xml mate_xml1 mate_xml2 ... mate_xmln

Options:

  --od, required
    Output directory to save albedo product files for this target_xml.

  -s, --snow, optional
    Turn on snow-included albedo generation.

  --brdf, optional
    Source dataset of BRDF, 'MODIS' or 'VIIRS'. Default: 'MODIS'

  --of="OUTPUT_FORMAT", optional
    Designate output format in either "hdf" or "h5"; default:
    hdf. Notice: at this moment writing h5 is much slower than writing
    hdf for some reason.

  --keep_b, optional
    If set, keep the source BRDF subset files. Default: delete them
    after successful processing.

  --keep_t, optional
    If set, keep the temporary outputs from the albedo processing
    program. Default: delete them after successful processing.

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

$(basename ${0}) --od /full/path/to/my/folder/landsat-albedo/LC80180302015234LGN01 /full/path/to/my/target_xml/LC08_L1TP_018030_20150822_20170225_01_T1.xml /full/path/to/my/mate_xml1/LC08_L1TP_018029_20150822_20170225_01_T1.xml /full/path/to/my/mate_xml2/LC08_L1TP_018031_20150822_20170225_01_T1.xml

EOF

exe_dir=$(readlink -f ${0} | xargs dirname)

alb_dir="/home/zl69b/Workspace/src/landsat-albedo"
brdf_dl_cmd="/home/zl69b/Workspace/src/mvp-tools/common-utils/dl_test_mvp.sh"
brdf_dl_user="landtest"
brdf_dl_psw="STlads"

run_dir=$(pwd)

SNOW=0
BRDF="MODIS"
OUTFMT="hdf"
KEEP_T=0
KEEP_B=0
OPTS=`getopt -o s --long od:,snow,brdf:,of:,keep_t,keep_b -n "${0}" -- "$@"`
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
        -s | --snow )
            SNOW=1 ; shift ;;
        --of )
            case "${2}" in
                "") shift 2 ;;
                *) OUTFMT=${2} ; shift 2 ;;
            esac ;;
        --keep_t )
            kEEP_T=1 ; shift ;;
        --keep_b )
            kEEP_B=1 ; shift ;;
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

alb_exe=${alb_dir}/bin/landsat_albedo
if [[ ${SNOW} -eq 1 ]]; then
    alb_exe=${alb_dir}/bin/landsat_abedo_snow
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
angle_exe=${alb_dir}/bin/l8_angles
pcf_template=${alb_dir}/scripts/multilndalbedo_pcf_template.ini

# Print some processing metadata before running
if [[ -x ${brdf_dl_cmd} ]]; then
    echo "Checked, source BRDF downloading command = ${brdf_dl_cmd}"
else
    echo "Not found or executable, source BRDF downloading command = ${brdf_dl_cmd}"
    exit 2
fi
if [[ -x ${mos_exe} ]]; then
    echo "Checked, source BRDF subsetting command = ${mos_exe}"
else
    echo "Not found or executable, source BRDF subsetting command = ${mos_exe}"
    exit 2
fi
if [[ -x ${angle_exe} ]]; then
    echo "Checked, Landsat sun/view angle command = ${angle_exe}"
else
    echo "Not found or executable, Landsat sun/view angle command = ${angle_exe}"
    exit 2
fi
if [[ -r ${pcf_template} ]]; then
    echo "Checked, Landsat albedo PCF template = ${pcf_template}"
else
    echo "Not found, Landsat albedo PCF template = ${pcf_template}"
    exit 2
fi
if [[ -x ${alb_exe} ]]; then
    echo "Checked, Landsat albedo generation command = ${alb_exe}"
else
    echo "Not found or executable, Landsat albedo generation command = ${alb_exe}"
    exit 2
fi

echo "Target scene xml = ${XML_LIST[0]}"
echo "Mate scene xml = ${XML_LIST[1]}"
for ((i=2; i < ${#XML_LIST[@]}; i++)); 
do
    echo "                 ${XML_LIST[i]}"
done

# Get product_id
PRD_ID=$(grep product_id ${XML_LIST[0]} | cut -d'>' -f2 | cut -d'<' -f1 | xargs basename)
if [[ -z ${PRD_ID} ]]; then
    echo "Failed to extract product_id from the XML ${XML_LIST[0]}"
    exit 2
fi
# Get acquisition date and doy
TMP=$(echo ${PRD_ID} | cut -d'_' -f4)
DOY=$(date -d ${TMP} +%j)
YEAR=${TMP:0:4}
# Get spacecraft
SCFT_ID=$(grep satellite ${XML_LIST[0]} | cut -d'>' -f2 | cut -d'<' -f1 | xargs)

# Set up input and output directories
dir_o=${OUTDIR}
dir_i=$(dirname ${XML_LIST[0]})
dir_b=${OUTDIR}/brdf
if [ ! -r $dir_o ]; then
    mkdir -p $dir_o
else
    # check if this scene is already processed. If so, skip
    # it.
    TMP=($(find ${dir_o} -name ${PRD_ID}"_albedo_*"))
    if [[ ${#TMP[@]} -eq 6 ]]; then
        echo "Warning: ${scene} albedo outputs exists! Skip!"
        exit 2
    fi
fi
if [[ ! -r ${dir_b} ]]; then
    mkdir -p ${dir_b}
fi

# number of xml files
num_f=${#XML_LIST[@]}
mos_xml_param=${XML_LIST[@]}
# Find the needed MODIS tiles
mos_out=$($mos_exe NULL NULL NULL ${num_f} ${mos_xml_param} -p | grep -i "tiles")
tile_hstr=$(echo ${mos_out} | cut -d',' -f1 | cut -d'h' -f2)
tile_vstr=$(echo ${mos_out} | cut -d',' -f2 | cut -d'v' -f2 | cut -d'.' -f1)
tile_hmin=$(echo ${tile_hstr} | cut -d'-' -f1)
tile_hmax=$(echo ${tile_hstr} | cut -d'-' -f2)
tile_vmin=$(echo ${tile_vstr} | cut -d'-' -f1)
tile_vmax=$(echo ${tile_vstr} | cut -d'-' -f2)
if [[ -z ${tile_hmin} || -z ${tile_hmax} || -z ${tile_vmin} || -z ${tile_vmax} ]]; then
    echo "Failed to calculate the needed MODIS/VIIRS tiles."
    exit 2
fi

echo "Downloading ${BRDF} tiles h${tile_hmin}-${tile_hmax}, v${tile_vmin}-${tile_vmax}"

for ((i=0; i<${#brdf_prd[@]}; i++));
do
    for ((h=${tile_hmin}; h<=${tile_hmax}; h++));
    do
        for ((v=${tile_vmin}; v<=${tile_vmax}; v++)); do
            ${brdf_dl_cmd} --ftp ladssci.nascom.nasa.gov --user ${brdf_dl_user} --password ${brdf_dl_psw} -f ${brdf_fmt} -t h$(printf %02d ${h})v$(printf %02d ${v}) -y ${YEAR} -p "${brdf_prd[i]}" -n ${brdf_vnum} -o ${dir_b} -b ${DOY} -e ${DOY}
        done
    done
done

# Subset BRDF data
brdf_ss=()
for ((i=0; i < ${#brdf_prd[@]}; i++));
do
    brdf_ss[${i}]=${dir_b}/${brdf_prd[i]}_FOR_${PRD_ID}.${brdf_fmt}
    echo "Mosaic and subset ${brdf_prd[i]} for $PRD_ID ..."
    $mos_exe ${dir_b} ${brdf_prd[i]} ${brdf_ss[i]} ${num_f} ${mos_xml_param} -f
    if [ $? -ne 0 ]; then
        echo "mosaic ${brdf_prd[i]} failed for ${num_f} ${mos_xml_param}"
        rm -f ${brdf_ss[i]}
        exit 2
    fi
done

mod_a1=`readlink -m ${brdf_ss[0]}`
mod_a2=`readlink -m ${brdf_ss[1]}`

echo "Generating solar and view angle images..."
cd ${dir_i}
angle_file=${PRD_ID}"_ANG.txt"
if [[ ${SCFT_ID} == "LANDSAT_8"  ]]; then
    # OLI/TIIRS Combined
    $angle_exe ${angle_file} SATELLITE 1 -f -32768 -b 2,3,4,5,6,7
    $angle_exe ${angle_file} SOLAR 1 -f -32768 -b 4
elif [[ ${SCFT_ID} == "LANDSAT_7" || ${SCFT_ID} == "LANDSAT_5" ]]; then
    # TM/ETM+
    $angle_exe ${angle_file} SATELLITE 1 -f -32768 -b 1,2,3,4,5,7
    $angle_exe ${angle_file} SOLAR 1 -f -32768 -b 3
fi

cd ${run_dir}

echo "Processing $PRD_ID albedo..."

SR_TARGET_XML=${XML_LIST[0]}
SR_MATES_XMLS=(${XML_LIST[@]:1})

read -r -d '' SR_ANG_IMGS <<EOF
$(tmp=$(find ${dir_i} -name "*sensor_B02.img"); if [[ -z ${tmp} ]]; then echo NULL; else echo ${tmp}; fi)
\t$(tmp=$(find ${dir_i} -name "*sensor_B03.img"); if [[ -z ${tmp} ]]; then echo NULL; else echo ${tmp}; fi)
\t$(tmp=$(find ${dir_i} -name "*sensor_B04.img"); if [[ -z ${tmp} ]]; then echo NULL; else echo ${tmp}; fi)
\t$(tmp=$(find ${dir_i} -name "*sensor_B05.img"); if [[ -z ${tmp} ]]; then echo NULL; else echo ${tmp}; fi)
\t$(tmp=$(find ${dir_i} -name "*sensor_B06.img"); if [[ -z ${tmp} ]]; then echo NULL; else echo ${tmp}; fi)
\t$(tmp=$(find ${dir_i} -name "*sensor_B07.img"); if [[ -z ${tmp} ]]; then echo NULL; else echo ${tmp}; fi)
\t$(tmp=$(find ${dir_i} -name "*solar_B04.img"); if [[ -z ${tmp} ]]; then echo NULL; else echo ${tmp}; fi)
EOF
SR_ANG_IMGS=$(echo -e "${SR_ANG_IMGS}")

SRC_BRDF_PAR=${mod_a1}
SRC_BRDF_QA=${mod_a2}
out_prefix=${PRD_ID}
ALBEDO_BROAD=${dir_o}/${out_prefix}_albedo_broad.${OUTFMT}
ALBEDO_SPECTRAL=${dir_o}/${out_prefix}_albedo_spectral.${OUTFMT}
CLS_MAP=${dir_o}/${out_prefix}_clsmap.${OUTFMT}
TEMPDIR=$(mktemp -d --tmpdir=${dir_o})

# Generate a PCF for this processing.
this_pcf=${dir_o}/${out_prefix}_pcf.ini
eval "echo \"$(cat ${pcf_template})\"" > ${this_pcf}

${alb_exe} ${this_pcf}
if [[ $? -ne 0 ]]; then
    # Remove every output except PCF file for diagnosis.
    find ${dir_o} -maxdepth 1 -type f ! -name "*.ini" | xargs rm -f
    echo "Run albedo failed for $PRD_ID"
    echo "$PRD_ID ALBEDO_FAIL" >>    ${err}
    exit 1
fi

# if succeed, clean the inputs and the tempdir
if [[ ${KEEP_B} -eq 0 ]]; then
    rm -rf ${dir_b}
fi
if [[ ${KEEP_T} -eq 0 ]]; then
    rm -rf ${TEMPDIR}
fi

echo "Success ${PRD_ID}."
echo ""
