#!/usr/bin/env python

"""
landsat_xml2localtime.py

take in a Landsat/Sentinel-2 xml file and output the local time of
acquisition.

Zhan Li, zhan.li@umb.edu
Created: Wed Apr 27 11:30:37 EDT 2016
"""

import sys
import os
import argparse
import math
import xml.etree.cElementTree as ET

def parse_landsat_xml(xml):

def xml2local(xml, sat="Landsat"):
    xmlns={"landsat":"http://espa.cr.usgs.gov/v1", 
           "sentinel2":"https://psd-12.sentinel2.eo.esa.int/PSD/S2_PDI_Level-1C_Tile_Metadata.xsd"}
    tree = ET.parse(xml)
    root = tree.getroot()
    if (sat.upper() == "LANDSAT"):
        el_gm = root.find("landsat:global_metadata", xmlns)
        acq_date = el_gm.find("landsat:acquisition_date", xmlns).text
        acq_time_utc = el_gm.find("landsat:scene_center_time", xmlns).text
        corner_ls = el_gm.findall("landsat:corner", xmlns)
        lats = [ float(cn.get("latitude")) for cn in corner_ls]
        lons = [ float(cn.get("longitude")) for cn in corner_ls]
        ctr_lat = math.fsum(lats)/float(len(lats))
        ctr_lon = math.fsum(lons)/float(len(lons))

        
    elif (sat.upper() == "SENTINEL2"):
        print
    else:
        return None

def main(cmdargs):
    xml2local(cmdargs.xml, sat=cmdargs.sat)

def getCmdArgs():
    p = argparse.ArgumentParser(description="Take in a Landsat xml file and return the local time of acquisition")

    p.add_argument("-x", "--xml", dest="xml", required=True, nargs=1, default=None, metavar="XML", help="the path to the XML file of a Landsat scene or a Sentinel-2 granule (NOT scene), %(metavar)s")
    sats=["Landsat", "Sentinel2"]
    p.add_argument("-s", "--satellite", dest="sat", required=True, nargs=1, default=None, metavar="SATELLITE", help="input XML is from the satellite %(meta)s; available satellite names: "+','.join(sats))

    cmdargs = p.parse_args()

#    if (cmdargs.sat.upper() in )

    return cmdargs

if __name__=="__main__":
    cmdargs = getCmdArgs()
    main(cmdargs)
