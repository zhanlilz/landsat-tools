#!/usr/bin/env python

import os
import argparse
import textwrap
import logging, logging.config

import pandas as pd

from landsat import Landsat

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
    p = argparse.ArgumentParser(description="Download Landsat TOA data from public repositories such as Google Storage or AWS S3.", formatter_class=argparse.RawTextHelpFormatter)

    p.add_argument("-l", "--list", dest="scn_list", required=True, default=None, metavar="CSV_OF_SCENE_LIST", help=textwrap.fill("A CSV file of the list of scene IDs and index URLs (must be in first and second columns) in the public data repositories on commerical cloud servers, to download available scenes. Sample format: ") + textwrap.dedent('''
    scene_id,index_url,your_additional_col1,your_additional_col2
    LC80010042015211LGN01,gs://gcp-public-data-landsat/LC08/01/001/004/LC08_L1GT_001004_20150730_20170406_01_T2,your_col1_value,your_col2_value
    LC80010042015243LGN01,gs://gcp-public-data-landsat/LC08/01/001/004/LC08_L1GT_001004_20150831_20170404_01_T2,your_col1_value,your_col2_value'''))

    p.add_argument("-d", "--directory", dest="outdir", required=True, metavar="OUTPUT_DIRECTORY", default=None, help=textwrap.fill("Output directory to save the Landsat data."))

    cmdargs = p.parse_args()
    
    return cmdargs


def scnIdToSpacecraftId(scn_id):
    sc_code = int(scn_id[2])
    if sc_code != 5 and sc_code != 7 and sc_code != 8:
        return None
    return "LANDSAT_{0:d}".format(sc_code)


def indexUrlToBucketId(index_url):
    if index_url[0:2] == "gs" or index_url.find("googleapi.com") > -1:
        return "GOOGLE"
    elif index_url.find("amazonaws.com"):
        return "AWS"
    else:
        return None


def main(cmdargs):
    scn_csv = cmdargs.scn_list
    outdir = cmdargs.outdir

    repo_ch_list = ["GOOGLE", "AWS"]
    landsat_obj_dict = {}
    for repo in repo_ch_list:
        if repo == "GOOGLE":
            scft_id_list = ["LANDSAT_5", "LANDSAT_7", "LANDSAT_8"]
        elif repo == "AWS":
            scft_id_list = ["LANDSAT_8"]
        else:
            scft_id_list = []
        for scft in scft_id_list:
            landsat_obj_dict[(repo, scft)] = Landsat(scft, repo)

    n_good = 0
    n_bad = 0

    chunksize = int(1e3)
    for scn_df in pd.read_csv(scn_csv, usecols=[0, 1], chunksize=chunksize):
        for idx, row in enumerate(scn_df.itertuples()):
            scft_id = scnIdToSpacecraftId(row[1])
            if scft_id is None:
                logger.error(("Scene ID {0:s} cannot be parsed to " + 
                              "Landsat spacecraft ID, and will be skipped.").format(row[1]))
                n_bad += 1
                continue
            repo_ch = indexUrlToBucketId(row[2])
            if repo_ch is None:
                logger.error(("Scene index url {0:s} cannot be parsed " 
                              + "to public data repository channel name, " 
                              + "and will be skipped.").format(row[2]))
                n_bad += 1
                continue

            landsat_obj = landsat_obj_dict[(repo_ch, scft_id)]
            if landsat_obj.addScene(row[1], row[2]) is None:
                logger.error("Adding scene {0:s} to the download queue failed, and will be skipped.".format(row[1]))
                n_bad += 1
                continue
            logger.info("Saving scene {0:s} started.".format(row[1]))
            landsat_obj.saveToDir(outdir)
            landsat_obj.clearScenes()
            n_good += 1
            
    logger.info("{0:d} scenes saved to {1:s}".format(n_good, outdir))
    if n_bad > 0:
        logger.warning("{0:d} scenes failed to download.".format(n_bad))

if __name__ == "__main__":
    cmdargs = getCmdArgs()
    main(cmdargs)
