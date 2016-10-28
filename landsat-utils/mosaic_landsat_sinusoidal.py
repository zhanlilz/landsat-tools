#!/bin/env python

import sys
import argparse

from osgeo import gdal

def main(cmdargs):
    print "TODO"

def getCmdArgs():
    p = argparse.ArgumentParser(description="Mosaic multiple Landsat scenes into Sinusoidal projection")

    p.add_argument("-L", "--landsat-list", dest="landsat_list", \
                       required=True, nargs="*", default=None, \
                       metavar="LANDSAT_LIST", help="List of Landsat albedo scenes")
    p.add_argument("-o", "--output", dest="output", \
                       required=True, nargs=1, default=None, \
                       metavar="OUTPUT_IMAGE", help="Path to the output mosaiced image")
    p.add_argument("-r", "--resolution", dest="resolution", \
                       required=False, nargs=1, default=None, \
                       metavar="RESOLUTION", help="Resolution of the output mosaiced image")

    cmdargs = p.parse_args()

    return cmdargs

if __name__=="__main__":
    cmdargs = getCmdArgs()
    main(cmdargs)
