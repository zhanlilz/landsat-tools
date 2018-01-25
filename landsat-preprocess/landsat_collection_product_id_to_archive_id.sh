#!/bin/bash
#
# ${0} product_id_list_file archive_id_list_file

PROD_ID_FILE=${1}
ARCH_ID_FILE=${2}

# read lines to an array
readarray -t PROD_ID < ${PROD_ID_FILE}

N_ID=${#PROD_ID[@]}

> ${ARCH_ID_FILE}
oIFS=${IFS}
for ((i=0; i<${N_ID}; i++))
do
    PID=$(echo ${PROD_ID[${i}]} | tr -d '\n\r')
    IFS="_" read -ra TMPARR <<< "${PID}"
    AID=${TMPARR[0]}${TMPARR[2]}${TMPARR[3]}${TMPARR[5]}${TMPARR[6]}
    echo $AID >> ${ARCH_ID_FILE}
done
IFS=${oIFS}
