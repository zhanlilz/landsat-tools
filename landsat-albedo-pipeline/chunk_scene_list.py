#!/usr/bin/env python

import argparse
import os

import pandas as pd

def getCmdArgs():
    p = argparse.ArgumentParser(description="Sort the scenes in a long list according to their year, DOY, path, and row, and then divide this scene list into chunks, i.e. multiple shorter lists of scene paths/rows and dates according to a given size.")

    p.add_argument("-l", "--list", dest="scn_list", required=True, default=None, metavar="CSV_OF_SCENE_LIST", help="A CSV file of scene list. It must have at least the first column as the list of scene IDs (e.g. LC80010042015211LGN01)")
    
    p.add_argument("--chunk", dest="chunk_size", type=int, required=True, default=None, metavar="CHUNK_SIZE", help="Chunk size, maximum number of scenes in an output smaller scene list.")

    p.add_argument("--od", dest="outdir", required=True, default=None, metavar="OUTPUT_DIR", help="Output directory to save all the divided CSV lists of scenes.")

    cmdargs = p.parse_args()
    
    return cmdargs


def scnIdToPathRowDay(scn_id):
    path = int(scn_id[3:6])
    row = int(scn_id[6:9])
    year = int(scn_id[9:13])
    doy = int(scn_id[13:16])
    return path, row, year, doy


def main(cmdargs):
    scn_csv = cmdargs.scn_list
    chunksize = cmdargs.chunk_size
    outdir = cmdargs.outdir

    scn_df = pd.read_csv(scn_csv, usecols=[0])
    line_df = pd.read_table(scn_csv, delimiter='\n', memory_map=True)

    scn_list = scn_df.iloc[:, 0].tolist()

    prd_header = ["path", "row", "year", "doy"]
    prd_list = zip(*[scnIdToPathRowDay(scn) for scn in scn_list])
    prd_dict = {nm:prd for nm, prd in zip(prd_header, prd_list)}
    prd_dict["line"] = line_df.iloc[:, 0].tolist()

    prd_df = pd.DataFrame(prd_dict)
    prd_df = prd_df.sort_values(["year", "doy", "path", "row"])

    outdf_bidx = range(0, len(prd_df), chunksize) # inclusive
    outdf_eidx = outdf_bidx[1:] + [len(prd_df)] # exclusive
    nchunks = len(outdf_bidx)
    ndigits = len(str(nchunks))

    outcsv_base, _ = os.path.splitext(os.path.basename(scn_csv))
    fmt_str = "{{0:s}}_{{1:0{0:d}d}}.csv".format(ndigits)
    outcsv_list = [os.path.join(outdir, fmt_str.format(outcsv_base, i+1)) for i in range(nchunks)]

    with open(scn_csv, "r") as scnfobj:
        headerstr = scnfobj.readline().rstrip()

    for obi, oei, ocsv in zip(outdf_bidx, outdf_eidx, outcsv_list):
        with open(ocsv, "w") as outfobj:
            outfobj.write(headerstr)
            outfobj.write("\n")
            for i in range(obi, oei):
                outfobj.write(prd_df["line"].iloc[i])
                outfobj.write("\n")    

if __name__ == "__main__":
    cmdargs = getCmdArgs()
    main(cmdargs)
