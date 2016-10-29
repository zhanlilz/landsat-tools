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

read -d '' USAGE <<EOF
unzip_landsat_tar.sh [options] DATA_DIR

  Unzip all the Landsat .tar.gz files DIRECTLY stored in the directory
  of DATA_DIR, but NOT in any subdirectories. 

Options:

  -C, --out_directory=DIR, change output directory to DIR. Default
   output directory is the same as the directory of the Landsat
   archive .tar.gz files.

  -m, --move_archive, move Landsat archive .tar.gz file into the
   folder of unzipped files.

EOF

MINPARAMS=1
if [[ ${#} < ${MINPARAMS} ]]; then
    echo "At least ${MINPARAMS} arguments are needed"
    echo "${USAGE}"
    exit 1
fi

# set some default parameters
MOVE=0 # do not move archive into the folder the unzipped
# use getopt to help parse the optional arguments including checking
# if requiring an argument after an option, etc.
OPTS=`getopt -o C:m --long out_directory:,move_archive -n 'unzip_landsat_tar.sh' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; echo "${USAGE}" ; exit 1 ; fi
# set shell's positional arguments to "$OPTS"
eval set -- "$OPTS"
# parse optional argument
while true; do
  case "${1}" in
    -C | --out_directory ) 
      case "$2" in
        "") shift 2 ;;
        *) 
          OUTDIR=$2;
          shift 2 ;;
      esac ;;
    -m | --move_archive ) MOVE=1 ; shift ;; 
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
TARDIR=${1}
if [[ -z ${OUTDIR} ]]; then
    OUTDIR=${TARDIR}
fi

# set up output directory
if [[ ! -d ${OUTDIR} ]]; then
    mkdir -p ${OUTDIR}
fi

n=$(find ${TARDIR} -maxdepth 1 -name '*tar.gz' | wc -l)
i=1

for archive in $(find ${TARDIR} -maxdepth 1 -name '*tar.gz'); do
    echo "<-- $i / $n: $(basename $archive)"
    
    # Create temporary folder for storage
    TEMPDIR=${OUTDIR}/temp
    # In case last operation was interrupted
    if [[ -d ${TEMPDIR} ]]; then
        rm -rf ${TEMPDIR}
    fi
    mkdir -p ${TEMPDIR}
    
    # Extract archive to temporary folder
    tar -xzvf $archive -C ${TEMPDIR}
    
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
    xml=$(find ${TEMPDIR} -name 'L*.xml')
    if [[ ! -f ${xml} ]]; then
        echo -e "\tCould not find xml file for ${archive}"
        continue
    fi
    # Use basename to get Landsat scene ID
    id=$(basename ${xml} '.xml')
    
    # In case last operation was interupted
    if [[ -d ${OUTDIR}/${id} ]]; then
        rm -rf ${OUTDIR}/${id}
    fi
    # Rename archive
    mv ${TEMPDIR} ${OUTDIR}/${id}

    # Move archive into folder of the unzipped
    if [[ ${MOVE} -eq 1 ]]; then
        mv $archive ${OUTDIR}/${id}
    fi    
    
    # Iterate count
    let i+=1
done

echo "Unzip Landsat archive done!"
