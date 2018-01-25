#!/usr/bin/env python

import argparse

import json
import requests

def getCmdArgs():
    p = argparse.ArgumentParser(description="Search USGS Landsat inventory from EarthExplorer.")

    p.add_argument("-u", "--user", dest="user", required=True, default=None, help="Username of your USGS EarthExplorer.")
    p.add_argument("-p", "--password", dest="password", required=True, default=None, help="Password of your USGS EarthExplorer")

    p.add_argument("-s", "--spacecraft", dest="spacecraft_id", required=True, metavar="SPACECRAFT_ID", choices=["5", "7", "8"], default=None, help=textwrap.fill("Landsat spacecraft ID; choices: 5, 7, 8."))

    p.add_argument("--geojson", dest="geojson", required=False, default=None, metavar="GEOJSON_FILE_FOR_GEOSPATIAL_SEARCH", help="A geojson file giving the geospatial extent of your search. An easy way to get geojson strings from an interactive map is to go to the website: geojson.io, or go to the website geojson-maps.ash.ms to download geojson files of preset countries or regions.")

    p.add_argument("--path", dest="wrs_path", required=False, default=None, metavar="WRS2_PATH_List", help="A list of WRS-2 paths to constrain your search, and must be one-to-one correspondent to the list of rows given to the option --row")
    p.add_argument("--row", dest="wrs_row", required=False, default=None, metavar="WRS2_ROW_List", help="A list of WRS-2 rows to constrain your search, and must be one-to-one correspondent to the list of paths given to the option --path")
    p.add_argument("--start_date", dest="start_date", required=True, default=None, help="Start date of the image sensing time of Landsat data in your search, including this day.")
    p.add_argument("--end_date", dest="end_date", required=True, default=None, help="End date of the image sensing time of Landsat data in your search, including this day.")

    p.add_argument("-o", "--output", dest="outfile", required=False, default=None, help="A CSV file to write the found Landsat scene list to. If not given, write the found scene list to the console.")

    cmdargs = p.parse_argument()

    return cmdargs

def main(cmdargs):
    print "TO BE IMPLEMENTED!"

if __name__ == "__main__":
    cmdargs = getCmdargs()
    main(cmdargs)
