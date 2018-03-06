#!/usr/bin/env python

import argparse
import itertools

import pandas as pd

def getCmdArgs():
    p = argparse.ArgumentParser(description="Add scenes in neighboring rows of scenes in a given scene ID list.")

    p.add_argument("-l", "--list", dest="scn_list", required=True, default=None, metavar="CSV_OF_SCENE_LIST", help="A CSV file of scene list. It must have at least the first column as the list of scene IDs (e.g. LC80010042015211LGN01)")

    p.add_argument("--lead", dest="nlead", required=False, default=1, metavar="NUM_OF_LEADING_ROWS_TO_BUFFER", help="Number of leading rows to buffer from a scene, e.g. 2 leading rows of path=18,row=30 will add two path/row pairs, (1) path=18,row=31, (2) path=18,row=32.")
    p.add_argument("--trail", dest="ntrail", required=False, default=1, metavar="NUM_OF_TRAILING_ROWS_TO_BUFFER", help="Number of trailing rows to buffer from a scene, e.g. 2 leading rows of path=18,row=30 will add two path/row pairs, (1) path=18,row=29, (2) path=18,row=28.")

    p.add_argument("-o", "--output", dest="output", required=True, default=None, metavar="OUTPUT_PRD_LIST", help="Name of output CSV file of the list of path,row,start_date,end_date, of the scenes after row buffering.")

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
    nlead = cmdargs.nlead
    ntrail = cmdargs.ntrail
    prd_csv = cmdargs.output

    out_header = ["path", "row", "start_date", "end_date"]
    prd_header = ["path", "row", "year", "doy"]
    with open(prd_csv, "w") as out_fobj:
        out_fobj.write(",".join(out_header))
        out_fobj.write("\n")
        scn_df = pd.read_csv(scn_csv, usecols=[0])
        scn_list = scn_df.iloc[:, 0].tolist()
        prd_list = zip(*[scnIdToPathRowDay(scn) for scn in scn_list])
        prd_dict = {nm:prd for nm, prd in zip(prd_header, prd_list)}
        prd_df = pd.DataFrame(prd_dict)
        # Add buffer rows
        buf_row_add = range(-1*ntrail, nlead+1)
        buf_row_add.remove(0)
        buf_df_list = [prd_df.copy() for bra in buf_row_add]
        for bra, bd in itertools.izip(buf_row_add, buf_df_list):
            bd["row"] = bd["row"] + bra

        all_prd_df = pd.concat([prd_df]+buf_df_list, axis=0)
        all_prd_df = all_prd_df.drop_duplicates(prd_header, keep=False)
        all_prd_df = all_prd_df.sort_values(["year", "doy", "path", "row"])
        datestr = ["{0:04d}{1:03d}".format(getattr(row, "year"), getattr(row, "doy")) 
                   for row in all_prd_df.itertuples()]
        all_prd_df[out_header[2]] = pd.to_datetime(datestr, format="%Y%j")
        all_prd_df[out_header[3]] = pd.to_datetime(datestr, format="%Y%j")

        all_prd_df.to_csv(out_fobj, header=False, index=False, columns=out_header, 
                          mode="a", date_format="%Y-%m-%d")

if __name__ == "__main__":
    cmdargs = getCmdArgs()
    main(cmdargs)
