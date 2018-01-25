#!/usr/bin/env python
#
# Create or update (if exists) a database of index to Landsat images
# for search and query download links.
#
# Zhan Li, zhan.li@umb.edu
# Created: Thu Jul 27 14:44:27 EDT 2017

import argparse
import os
import sys
import tempfile
import subprocess
import shutil
import logging, logging.config

import requests
from homura import download
import sqlalchemy as sa
import pandas as pd

from common import (GOOGLE_LANDSAT_INDEX, GOOGLE_LANDSAT_DTYPE,
                    S3_LANDSAT_INDEX, S3_LANDSAT_DTYPE)

LOGGING = {
    "version" : 1, 
    "formatters" : {
        "default" : {
            "format" : "%(asctime)s %(levelname)s %(message)s", 
        }, 
    }, 
    "handlers" : {
        "console" : {
            "class" : "logging.StreamHandler", 
            "level" : "DEBUG", 
            "formatter" : "default", 
            "stream" : "ext://sys.stdout", 
        }, 
    }, 
    "root" : {
        "handlers" : ["console"], 
        "level" : "DEBUG", 
    }, 
}

logging.config.dictConfig(LOGGING)
logger = logging.getLogger('landsat-downloader')

def getCmdArgs():
    p = argparse.ArgumentParser(description="Create or update (if exists) a database of index to Landsat images on public available servers including Google Cloud Storage and Amazon AWS S3.")

    p.add_argument("-d", "--dir", dest="index_dir", default=None,
                   required=True, help="Local directory to save CSV file of index from the server and the generated SQLite database file.")
    p.add_argument("-c", "--channel", dest="channel", choices=("google", "aws"), default=None, required=True, help="Server channel to download index files.")

    cmdargs = p.parse_args()

    return cmdargs

def main(cmdargs):
    index_dir = os.path.abspath(cmdargs.index_dir)
    if not os.path.exists(index_dir):
        os.mkdir(index_dir)

    dl_index_fname = "index.csv"
    index_db_fname = "index.db"
    index_db_tname = "landsat"
    temp_index_fname = "tmpindex"
    temp_index_db_fname = "tmpindex.db"

    tmpdir = tempfile.mkdtemp()
    zip_file = os.path.join(tmpdir, "{0:s}.gz".format(temp_index_fname))

    if cmdargs.channel == "google":
        index_url = GOOGLE_LANDSAT_INDEX
        index_dtype = GOOGLE_LANDSAT_DTYPE
        index_parse_dates = ["DATE_ACQUIRED", "SENSING_TIME"]
        unzip_cmd = ["gzip", "-d", zip_file]
    elif cmdargs.channel == "aws":
        index_url = S3_LANDSAT_INDEX
        index_dtype = S3_LANDSAT_DTYPE
        index_parse_dates = ["acquisitionDate"]
        unzip_cmd = ["gzip", "-d", zip_file]
    else:
        raise RuntimeError("Channel is not implemented yet!")


    logger.info("Downloading zipped index file started.")
    download(index_url, path=zip_file)
    logger.info("Downloading zipped index file finished.")

    logger.info("Unzipping index file started.")
    if ( 0 != subprocess.call(unzip_cmd) ):
        raise RuntimeError("Unzip the file of Google Landsat index failed!")
    logger.info("Unzipping index file finished.")

    csv_file = os.path.join(index_dir, dl_index_fname)
    shutil.move(os.path.join(tmpdir, temp_index_fname), os.path.join(index_dir, temp_index_fname))
    os.rename(os.path.join(index_dir, temp_index_fname), csv_file)

    tmp_db_file = os.path.join(tmpdir, temp_index_db_fname)
    csv_db = sa.create_engine("sqlite:///{0:s}".format(tmp_db_file))
    chunksize = int(1e5)
    j = 1
    logger.info("Updating SQLite database started.")
    for df in pd.read_csv(csv_file, chunksize=chunksize, iterator=True, 
                          dtype=index_dtype, parse_dates=index_parse_dates):
        df = df.rename(columns={c: c.replace(' ', '_') for c in df.columns}) 
        df.index += j
        df.to_sql(index_db_tname, csv_db, if_exists='append')
        j = df.index[-1] + 1
    csv_db_file = os.path.join(index_dir, index_db_fname)
    shutil.move(tmp_db_file, csv_db_file)
    logger.info("Updating SQLit database finished.")

if __name__ == "__main__":
    cmdargs = getCmdArgs()
    main(cmdargs)
