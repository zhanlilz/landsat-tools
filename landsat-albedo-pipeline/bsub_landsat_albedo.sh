#!/bin/bash

read -d '' USAGE <<EOF
$(basename ${0}) [options] --od output_dir base_scn_list mate_scn_list

Options:

  --od="OUTPUT_DIRECTORY", required
    Output directory to save albedo product files for this target_xml.

  -s, --snow, optional
    Turn on snow-included albedo generation.

  --prefix="BJOB_NAME_PREFIX", optional
    A string to label this pipeline and will be prefixed to all the
    job names to busb.

  --wait="WAIT_CONDITION_TO_BSUB_WAIT", optional
    A string in the syntax of bsub waiting condition,
    https://www.ibm.com/support/knowledgecenter/en/SSETD4_9.1.3/lsf_command_ref/bsub.w.1.html. This
    pipeline will not start until the condition givne by this string
    is met.

  --archive_server_ip="SERVER_IP_TO_ARCHIVE_ALBEDO", optional
    A string of URL or explicit IP address (for UMB local servers) to
    the server where to store the albedo data.

  --archive_server_dir="SERVER_DIR_TO_ARCHIVE_ALBEDO", optional
    A string of a directory on the archival server to store the albedo
    data.

  --archive_server_user="USER_NAME_TO_ACCESS_ARCHIVAL_SERVER", optional
    Your user name to access the archival server. 

  --archive_server_key="PRIVATE_SSH_KEY_TO_ACCESS_ARCHIVAL_SERVER", optional
    Your private ssh key on this computer (where you run this script)
    to access the archival server. The access to the archival server
    must be through ssh kyes to ensure the automatic data transfer to
    the archival server without entering your password to the archival
    server every time.

Arguments:

  base_scn_list, 
    A CSV list of scene ID, index URL to the cloud storage, each of
    which is to be processed to albedo.

  mate_scn_list, 
    A CSV list of scene ID, index URL to the cloud storage; these are
    additional scenes needed as mate scenes in genearting albedo for
    the scenes in the base_scn_list.

EOF

# ********************************************************************
# Set up some variables. We may move them into user-input
# options/arguments in future.
DL_TOA_CMD="python $(dirname $(readlink -f ${0}))/../landsat-data-access/download_landsat_cloud.py"
GEN_SR_CMD="$(dirname $(readlink -f ${0}))/gen_landsat_sr.sh"
GET_BRDF_CMD="$(dirname $(readlink -f ${0}))/get_source_brdf.sh"
GEN_ALBEDO_CMD="$(dirname $(readlink -f ${0}))/gen_landsat_albedo.sh"
# ********************************************************************

SNOW=0
PIPE_IDX="p1"
OPTS=`getopt -o s --long od:,snow,wait:,prefix:,archive_server_ip:,archive_server_dir:,archive_server_user:,archive_server_key: -n "${0}" -- "$@"`
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
        --prefix )
            case "${2}" in
                "") shift 2 ;;
                *) PIPE_IDX=${2} ; shift 2 ;;
            esac ;;
        --wait )
            case "${2}" in
                "") shift 2 ;;
                *) WAIT=${2} ; shift 2 ;;
            esac ;;
        -s | --snow )
            SNOW=1 ; shift ;;
        --archive_server_ip )
            case "${2}" in
                "") shift 2 ;;
                *) DATA_ARCH_SERVER=${2} ; shift 2 ;;
            esac ;;
        --archive_server_dir )
            case "${2}" in
                "") shift 2 ;;
                *) DATA_ARCH_DIR=${2} ; shift 2 ;;
            esac ;;
        --archive_server_user )
            case "${2}" in
                "") shift 2 ;;
                *) DATA_ARCH_SERVER_USER=${2} ; shift 2 ;;
            esac ;;
        --archive_server_key )
            case "${2}" in
                "") shift 2 ;;
                *) PRIV_KEY_FILE=${2} ; shift 2 ;;
            esac ;;
        -- ) shift ; break ;;
        * ) break ;;
    esac
done
MINPARAMS=2
if [[ ${#} < ${MINPARAMS} ]]; then
    echo "Missing positional arguments"
    echo "${USAGE}"
    exit 1
fi

if [[ ${SNOW} -eq 1 ]]; then
    GEN_ALBEDO_CMD="${GEN_ALBEDO_CMD} -s"
fi

DO_ARCH=0
if [[ ! -z ${DATA_ARCH_SERVER} ]] || [[ ! -z ${DATA_ARCH_DIR} ]] || [[ ! -z ${DATA_ARCH_SERVER_USER} ]] || [[ ! -z ${PRIV_KEY_FILE} ]]; then
    DO_ARCH=1
    if [[ -z ${DATA_ARCH_SERVER} ]] || [[ -z ${DATA_ARCH_DIR} ]] || [[ -z ${DATA_ARCH_SERVER_USER} ]] || [[ -z ${PRIV_KEY_FILE} ]]; then
        echo "To archive data on a designated server, the four options must be all given: --archive_server_ip, --archive_server_dir, --archive_server_user, --archive_server_key"
        echo "${USAGE}"
        exit 1
    fi
fi

bjob_s02_name="${PIPE_IDX}-dl-landsat-toa"
bjob_s03_name="${PIPE_IDX}-gen-landsat-sr"
bjob_s04_name="${PIPE_IDX}-get-source-brdf"
bjob_s05_name="${PIPE_IDX}-gen-landsat-albedo"
bjob_s06_name="${PIPE_IDX}-data-archive"

BASE_SCN_LIST=${1}
MATE_SCN_LIST=${2}
N_BASE_SCN=$(($(wc -l ${BASE_SCN_LIST} | cut -d' ' -f1) - 1))
N_MATE_SCN=$(($(wc -l ${MATE_SCN_LIST} | cut -d' ' -f1) - 1))
N_TOT_SCN=$((${N_BASE_SCN} + ${N_MATE_SCN}))

# Create a folder to save all the bsub scripts.
BSUB_DIR=${OUTDIR}/bsub-scripts
if [[ ! -d ${BSUB_DIR} ]]; then
    mkdir -p ${BSUB_DIR}
fi
# Create a folder to save all the log files.
LOG_DIR=${OUTDIR}/pipe-log
if [[ ! -d ${LOG_DIR} ]]; then
    mkdir -p ${LOG_DIR}
fi

# Download Landsat TOA
dl_toa_bsub=${BSUB_DIR}/$(echo ${bjob_s02_name} | tr '-' '_').sh
# Create a folder to save TOA and later SR
TOA_SR_DIR=${OUTDIR}/toa-sr
BASE_TOA_SR_DIR=${TOA_SR_DIR}/target-scenes
MATE_TOA_SR_DIR=${TOA_SR_DIR}/extra-scenes
if [[ ! -z ${WAIT} ]]; then
    WAITSTR="#BSUB -w ${WAIT}"
else
    WAITSTR=""
fi
# around 1 min per scene downloading at most?
EST_TIME=$((${N_TOT_SCN}*1/60 + 1))
cat <<EOF > ${dl_toa_bsub}
#BSUB -J ${bjob_s02_name}
#BSUB -e ${LOG_DIR}/${bjob_s02_name}.%J.e
#BSUB -o ${LOG_DIR}/${bjob_s02_name}.%J.o
#BSUB -n 1
#BSUB -W ${EST_TIME}:00
#BSUB -q long
#BSUB -R "rusage[mem=512]"
#BSUB -R "select[hname!=c24b08 && hname!=c23b04 && hname!=c16b07 && hname!=c31b02]"
${WAITSTR}

if [[ ! -d "${BASE_TOA_SR_DIR}" ]]; then
    mkdir -p "${BASE_TOA_SR_DIR}"
fi
if [[ ! -d "${MATE_TOA_SR_DIR}" ]]; then
    mkdir -p "${MATE_TOA_SR_DIR}"
fi

echo "Downloading TOA of target scenes"
${DL_TOA_CMD} -l ${BASE_SCN_LIST} -d ${BASE_TOA_SR_DIR}

echo "Downloading TOA of additional scenes"
${DL_TOA_CMD} -l ${MATE_SCN_LIST} -d ${MATE_TOA_SR_DIR}

EOF

# Get Landsat SR
gen_sr_bsub=${BSUB_DIR}/$(echo ${bjob_s03_name} | tr '-' '_').sh
EST_TIME=2
cat <<EOF > ${gen_sr_bsub}
#BSUB -J "${bjob_s03_name}[1-${N_TOT_SCN}]"
#BSUB -e ${LOG_DIR}/${bjob_s03_name}.%J.%I.e
#BSUB -o ${LOG_DIR}/${bjob_s03_name}.%J.%I.o
#BSUB -w "ended(${bjob_s02_name})"
#BSUB -n 4
#BSUB -R "rusage[mem=2560]"
#BSUB -R "span[hosts=1]"
#BSUB -R "select[hname!=c24b08 && hname!=c23b04 && hname!=c16b07 && hname!=c31b02]"
#BSUB -W ${EST_TIME}:00
#BSUB -q long
#BSUB -env "all,OMP_THREAD_LIMIT=2"

SCN_MTL_ARR=(\$(find ${TOA_SR_DIR} -name *_MTL.txt))

if [[ \${LSB_JOBINDEX} -le \${#SCN_MTL_ARR[@]} ]]; then
    ${GEN_SR_CMD} --mtl="\${SCN_MTL_ARR[\$((\${LSB_JOBINDEX}-1))]}"
fi

EOF

# Search needed BRDF tiles and download them.
get_brdf_bsub=${BSUB_DIR}/$(echo ${bjob_s04_name} | tr '-' '_').sh
# Create a folder to save BRDF
BRDF_DIR=${OUTDIR}/brdf
EST_TIME=$((${N_BASE_SCN}*4*3/60 + 1))
cat <<EOF > ${get_brdf_bsub}
#BSUB -J "${bjob_s04_name}"
#BSUB -e ${LOG_DIR}/${bjob_s04_name}.%J.e
#BSUB -o ${LOG_DIR}/${bjob_s04_name}.%J.o
#BSUB -w "ended(${bjob_s03_name})"
#BSUB -n 1
#BSUB -R "rusage[mem=512]"
#BSUB -R "span[hosts=1]"
#BSUB -R "select[hname!=c24b08 && hname!=c23b04 && hname!=c16b07 && hname!=c31b02]"
#BSUB -W ${EST_TIME}:00
#BSUB -q long

if [[ ! -d "${BRDF_DIR}" ]]; then
    mkdir -p "${BRDF_DIR}"
fi

SCN_XML_ARR=(\$(find ${BASE_TOA_SR_DIR} -name *.xml))

CMD="${GET_BRDF_CMD}"
INPUT_DIR="${TOA_SR_DIR}"
OUTPUT_DIR="${BRDF_DIR}"

EOF

cat <<"EOF" >> ${get_brdf_bsub}
for ((i=0; i < ${#SCN_XML_ARR[@]}; i++)); 
do
    xml=${SCN_XML_ARR[i]}
    pr_str=$(basename ${xml} | cut -d'_' -f3)
    date_str=$(basename ${xml} | cut -d'_' -f4)

    path=${pr_str:0:3}
    row=${pr_str:3:3}
    row=$(( $(echo ${row} | sed s/^[0]*//) ))
    toprow=`printf %03d $((row-1))`
    botrow=`printf %03d $((row+1))`

    topxml=$(find ${INPUT_DIR} -name *${path}${toprow}_${date_str}*.xml)
    botxml=$(find ${INPUT_DIR} -name *${path}${botrow}_${date_str}*.xml)

    ${CMD} --brdf="MODIS" --format="hdf" --od=${OUTPUT_DIR} ${xml} ${topxml} ${botxml}
done
EOF

# Get Landsat albedo
gen_albedo_bsub=${BSUB_DIR}/$(echo ${bjob_s05_name} | tr '-' '_').sh
# Create a folder to save albedo
ALBEDO_DIR=${OUTDIR}/albedo
EST_TIME=2
cat <<EOF > ${gen_albedo_bsub}
#BSUB -J "${bjob_s05_name}[1-${N_BASE_SCN}]"
#BSUB -e ${LOG_DIR}/${bjob_s05_name}.%J.%I.e
#BSUB -o ${LOG_DIR}/${bjob_s05_name}.%J.%I.o
#BSUB -w "ended(${bjob_s04_name})"
#BSUB -n 1
#BSUB -R "rusage[mem=9216]"
#BSUB -R "span[hosts=1]"
#BSUB -R "select[hname!=c24b08 && hname!=c23b04 && hname!=c16b07 && hname!=c31b02]"
#BSUB -W ${EST_TIME}:00
#BSUB -q long

if [[ ! -d "${ALBEDO_DIR}" ]]; then
    mkdir -p "${ALBEDO_DIR}"
fi

SCN_XML_ARR=(\$(find ${BASE_TOA_SR_DIR} -name *.xml))

CMD="${GEN_ALBEDO_CMD}"
INPUT_DIR="${TOA_SR_DIR}"
BRDF_DIR="${BRDF_DIR}"
OUTPUT_DIR="${ALBEDO_DIR}"

EOF

cat <<"EOF" >> ${gen_albedo_bsub}
if [[ ${LSB_JOBINDEX} -le ${#SCN_XML_ARR[@]} ]]; then
    i=$((${LSB_JOBINDEX} - 1))
    xml=${SCN_XML_ARR[i]}
    pr_str=$(basename ${xml} | cut -d'_' -f3)
    date_str=$(basename ${xml} | cut -d'_' -f4)

    path=${pr_str:0:3}
    row=${pr_str:3:3}
    row=$(( $(echo ${row} | sed s/^[0]*//) ))
    toprow=`printf %03d $((row-1))`
    botrow=`printf %03d $((row+1))`

    topxml=$(find ${INPUT_DIR} -name *${path}${toprow}_${date_str}*.xml)
    botxml=$(find ${INPUT_DIR} -name *${path}${botrow}_${date_str}*.xml)

    ${CMD} --brdf="MODIS" --bd=${BRDF_DIR} --of="hdf" --od=${OUTPUT_DIR} ${xml} ${topxml} ${botxml}
fi
EOF

if [[ ${DO_ARCH} -eq 1 ]]; then
    # Archive data to UMB local server for storage
    data_archive_bsub=${BSUB_DIR}/$(echo ${bjob_s06_name} | tr '-' '_').sh
    EST_TIME=$((${N_BASE_SCN}*1/60 + 1))
    cat <<EOF > ${data_archive_bsub}
#BSUB -J "${bjob_s06_name}"
#BSUB -e ${LOG_DIR}/${bjob_s06_name}.%J.e
#BSUB -o ${LOG_DIR}/${bjob_s06_name}.%J.o
#BSUB -w "done(${bjob_s05_name})"
#BSUB -n 1
#BSUB -R "rusage[mem=64]"
#BSUB -R "span[hosts=1]"
#BSUB -R "select[hname!=c24b08 && hname!=c23b04 && hname!=c16b07 && hname!=c31b02]"
#BSUB -W ${EST_TIME}:00
#BSUB -q long

scp -C -v -q -i ${PRIV_KEY_FILE} -r ${ALBEDO_DIR}/* ${DATA_ARCH_SERVER_USER}@${DATA_ARCH_SERVER}:${DATA_ARCH_DIR}

rm -rf ${TOA_SR_DIR}
rm -rf ${BRDF_DIR}
rm -rf ${ALBEDO_DIR}

EOF

fi

# Submit the jobs
bsub < ${dl_toa_bsub}
bsub < ${gen_sr_bsub}
bsub < ${get_brdf_bsub}
bsub < ${gen_albedo_bsub}
if [[ ${DO_ARCH} -eq 1 ]]; then
    bsub < ${data_archive_bsub}
fi
