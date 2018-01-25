#!/usr/bin/env python

import sys
import os
import argparse
import textwrap
import logging, logging.config

import pandas as pd

from landsat import Landsat

import resource
import psutil
import gc
from collections import defaultdict
before = defaultdict(int)
after = defaultdict(int)
proc = psutil.Process(os.getpid())
# gc.set_debug(gc.DEBUG_UNCOLLECTABLE)

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
logger = logging.getLogger('landsat-query')

def getCmdArgs():
    p = argparse.ArgumentParser(description="Search Landsat TOA data from public repositories such as Google Storage or AWS S3.", formatter_class=argparse.RawTextHelpFormatter)

    p.add_argument("-l", "--list", dest="prd_list", required=True, default=None, metavar="CSV_OF_PATH_ROW_DATE_LIST", help=textwrap.fill("A CSV file of the list of path, row, start date, end date, to search and download available scenes. Sample format: ") + textwrap.dedent('''
    path,row,start_date,end_date
    18,32,2017-08-19,2017-08-25
    92,86,2015-08-22,2015-08-22'''))
    p.add_argument("-s", "--spacecraft", dest="spacecraft_id", required=True, metavar="SPACECRAFT_ID", choices=["5", "7", "8"], default=None, help=textwrap.fill("Landsat spacecraft ID; choices: 5, 7, 8."))
    p.add_argument("-c", "--channel", dest="channel", required=False, metavar="CHANNEL_NAME", choices=["Google", "AWS"], default="Google", help=textwrap.fill("The channel of the data repository from which Landsat data to be searched and downloaded, Google Storage: 'Google'; AWS S3: 'AWS'. Default: 'Google'."))
    p.add_argument("-i", "--index", dest="index_db", required=True, metavar="SQLITE_DATABASE_FILE_OF_LANDSAT_INDEX", default=None, help=textwrap.fill("A SQLite database file of Landsat data index of the data repository. It can be generated using 'update_landsat_index.py'."))

    p.add_argument("-o", "--output", dest="outfile", required=True, default=None, help="A CSV file to write the found Landsat scene list to.")

    cmdargs = p.parse_args()
    
    return cmdargs

def main(cmdargs):
    prd_csv = cmdargs.prd_list
    spacecraft_id = "LANDSAT_{0:s}".format(cmdargs.spacecraft_id)
    repo_channel = cmdargs.channel.upper()
    outfile = cmdargs.outfile
    index_db_name = cmdargs.index_db

    if (repo_channel == "GOOGLE"):
        _colnames = dict(product_id = "PRODUCT_ID", scene_id = "SCENE_ID", 
                         c_number = "COLLECTION_NUMBER", 
                         sc_id = "SPACECRAFT_ID", 
                         wrs_path = "WRS_PATH", wrs_row = "WRS_ROW", 
                         acq_date = "SENSING_TIME", url = "BASE_URL")
    elif (repo_channel == "AWS"):
        _colnames = dict(product_id = "productId", scene_id = "entityId",
                         c_number = None, 
                         sc_id = None, 
                         wrs_path = "path", wrs_row = "row", 
                         acq_date = "acquisitionDate", url = "download_url")
    else:
        raise RuntimeError("Accessing the data in the channel {0:s} not implemented!".format(repo_channel))

    landsat_obj = Landsat(spacecraft_id, repo_channel, index_db_name)
    out_header = ["scene_id", "url", "product_id", "wrs_path", "wrs_row", "acq_date"]
    n_found = 0
    chunksize = int(1e3)

    with open(outfile, "w") as out_fobj:
        out_fobj.write(",".join(out_header))
        out_fobj.write("\n")
        for prd_df in pd.read_csv(prd_csv, parse_dates=[2, 3], chunksize=chunksize):
            for idx, row in enumerate(prd_df.itertuples()):
                # for i in gc.get_objects():
                #     before[type(i)] += 1

                logger.info("Searching scenes for path = {0:d}, row = {1:d} started.".format(row[1], row[2]))

                tmp = landsat_obj.searchPathRow(row[1], row[2], 
                                                start_date=row[3].strftime("%Y-%m-%d"), 
                                                end_date=row[4].strftime("%Y-%m-%d"))
                if len(tmp) == 0:
                    logger.warning(("No scenes found for " 
                                    + "path = {0:d}, row = {1:d}" 
                                    + " between {2:s} and {3:s}").format(row[1], row[2], 
                                                                         row[3].strftime("%Y-%m-%d"), 
                                                                         row[4].strftime("%Y-%m-%d")))
                else:
                    tmp = tmp.loc[:, [_colnames[k] for k in out_header]]
                    tmp.columns = out_header
                    tmp.to_csv(out_fobj, index=False, header=False, mode="a")

                n_found = n_found + len(tmp)

                # for i in gc.get_objects():
                #     after[type(i)] += 1
                # diff = [(k, after[k] - before[k]) for k in after if after[k] - before[k]]
                # print idx, diff
                logger.info("Memory = {0:d} at path = {1:d}, row = {2:d}".format(proc.memory_info().rss, row[1], row[2]))

    logger.info("{0:d} scenes found from {1:s}.".format(n_found, repo_channel))

if __name__ == "__main__":
    cmdargs = getCmdArgs()
    main(cmdargs)
