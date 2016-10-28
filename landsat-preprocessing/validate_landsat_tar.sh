#!/bin/bash

# validate the checksum of downloaded Landsat .tar.gz files. 
# Usage:
# ./validate_landsat_tar.sh [options] directory_to_landsat_tar_gz_files

read -d '' USAGE <<EOF
validate_landsat_tar.sh [options] DATA_DIR

  Validate the checksum of downloaded Landsat .tar.gz files directly
  stored in the directory DATA_DIR. The checksum files from the data
  server, .md5 files must be in the same folder DATA_DIR too and have
  the same file names as the .tar.gz files.

Usage: 

  validate_landsat_tar.sh [options] directory_to_landsat_tar_gz_files

Options:

  -o, --output, a file to store the list of the corrupted files, if a
   file name is followed by the option, the list will be output to the
   file. Otherwise it will be output to the terminal.

   e.g.
   -o"file_of_list_of_corrupted_files"
   --output="file_of_list_of_corrupted_files"

  -c, --clean, remove the corrupted files if set.

  -q, --quiet, quiet all interaction with the users. preferably for
   batch calling the program.

EOF

MINPARAMS=1
if [[ ${#} < ${MINPARAMS} ]]; then
    echo "At least ${MINPARAMS} arguments are needed"
    echo "${USAGE}"
    exit 1
fi
# set default parameters
CLEAN=0 # do not clean corrupted files
QUIET=0 # not quiet, ask for confirmation.
# use getopt to help parse the optional arguments including checking if requiring an argument after an option, etc.
OPTS=`getopt -o o::cq --long output::,clean,quiet -n 'validate_landsat_tar.sh' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; echo "${USAGE}" ; exit 1 ; fi
# set shell's positional arguments to "$OPTS"
eval set -- "$OPTS"
# parse optional argument
while true; do
  case "${1}" in
    -o | --output ) 
      case "$2" in
        "") shift 2 ;;
        *) 
          OUTPUT=$2;
          shift 2 ;;
      esac ;;
    -c | --clean ) CLEAN=1 ; shift ;; 
    -q | --quiet ) QUIET=1 ; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done
# parse remaining required positional argument
MINPARAMS=1
if [[ ${#} < ${MINPARAMS} ]]; then
    echo "${MINPARAMS} arguments are needed"
    echo "${USAGE}"
    exit 1
fi
TARDIR=$1
MD5DIR=${TARDIR}

if [[ -n ${OUTPUT} ]]; then
    echo "Corrupted files will be listed in: "
    echo "  ${OUTPUT}"
    echo
else
    echo "Corrupted files will be listed to the terminal "
    echo

fi
echo "Directory to the Landsat compressed image files: "
echo "  ${TARDIR}"
echo

if [[ ${CLEAN} -eq 1 ]]; then
    if [[ ${QUIET} -eq 0 ]]; then
        echo "Are you sure to remove corrupted files? Y/n"
        read YN
        if [[ ${YN} != "Y" ]]; then
            exit 0
        fi
    fi
fi

TARFILES=($(find ${TARDIR} -maxdepth 1 -name "*.tar.gz"))
# MD5FILES=($(ls "${MD5DIR}/*.md5"))

echo "${#TARFILES[@]} files to validate"

if [[ -n ${OUTPUT} ]]; then
    > ${OUTPUT}
else
    echo "Corrupted files: "
fi

for (( i=0; i<${#TARFILES[@]}; ++i ))
do
    tarf=${TARFILES[i]}
    testmd5=$(md5sum ${tarf} | cut -d ' ' -f 1 | tr -d ' ')
    # get the correct MD5 from .md5 file
    md5fbase="$(basename ${tarf} .tar.gz)"
    md5f="${MD5DIR}/${md5fbase}.md5"
    if [[ -e ${md5f} ]]; then
        tmpstr=$(cat ${md5f})
        IFS=' '; read -r -a truemd5 <<< "${tmpstr}"
        if [[ ${truemd5[1]} != "${md5fbase}.tar.gz" ]]; then
            echo "MD5 file content does not match file name: ${md5fbase}.md5"
        else
            tmpmd5=${truemd5[0]}
            # echo ${tmpmd5^^}, ${testmd5^^}
            if [[ ${tmpmd5^^} != ${testmd5^^} ]]; then
                if [[ -z ${OUTPUT} ]]; then
                    echo $(echo ${md5fbase} | cut -d '-' -f 1)
                else
                    echo ${md5fbase} | cut -d '-' -f 1 >> ${OUTPUT}
                fi
                if [[ ${CLEAN} -eq 1 ]]; then
                    rm -rf ${tarf}
                    rm -rf ${md5f}
                fi
            fi
        fi
    else
        echo "MD5 file not found: ${md5fbase}.md5"
    fi
done

echo "Finished validation!"