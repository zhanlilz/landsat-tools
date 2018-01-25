import re
import datetime
import os
import sys

import numpy as np

import requests
from wordpad import pad

# AWS S3 now only hosts Landsat-8
S3_LANDSAT = 'http://landsat-pds.s3.amazonaws.com/'
S3_LANDSAT_INDEX = 'https://landsat-pds.s3.amazonaws.com/c1/L8/scene_list.gz'
S3_LANDSAT_DTYPE = dict(productId = str, 
                        entityId = str,
                        acquisitionDate = str,
                        cloudCover = np.float_,
                        processingLevel = str,
                        path = np.int_,
                        row = np.int_,
                        min_lat = np.float_,
                        min_lon = np.float_,
                        max_lat = np.float_,
                        max_lon = np.float_,
                        download_url = str)

# Google Storage hosts all the Landsat archives
GS_PUBURL_PREFIX = 'http://storage.googleapis.com/'
GOOGLE_LANDSAT = 'http://storage.googleapis.com/gcp-public-data-landsat/'
GOOGLE_LANDSAT_INDEX = 'https://storage.googleapis.com/gcp-public-data-landsat/index.csv.gz'
GOOGLE_LANDSAT_DTYPE = dict(SCENE_ID = str,
                            PRODUCT_ID = str,
                            SPACECRAFT_ID = str,
                            SENSOR_ID = str,
                            DATE_ACQUIRED = str,
                            COLLECTION_NUMBER = str,
                            COLLECTION_CATEGORY = str,
                            SENSING_TIME = str,
                            DATA_TYPE = str,
                            WRS_PATH = np.int_,
                            WRS_ROW = np.int_,
                            CLOUD_COVER = np.float_,
                            NORTH_LAT = np.float_,
                            SOUTH_LAT = np.float_,
                            WEST_LON = np.float_,
                            EAST_LON = np.float_,
                            TOTAL_SIZE = np.uint64,
                            BASE_URL = str)

def check_create_folder(folder_path):
    """ Check whether a folder exists, if not the folder is created.
    :param folder_path:
        Path to the folder
    :type folder_path:
        String
    :returns:
        (String) the path to the folder
    """
    if not os.path.exists(folder_path):
        os.makedirs(folder_path)

    return folder_path


def get_remote_file_size(url):
    """ Gets the filesize of a remote file.
    :param url:
        The url that has to be checked.
    :type url:
        String
    :returns:
        int
    """
    headers = requests.head(url).headers
    return int(headers['content-length'])


def remote_file_exists(url):
        """ Checks whether the remote file exists.
        :param url:
            The url that has to be checked.
        :type url:
            String
        :returns:
            **True** if remote file exists and **False** if it doesn't exist.
        """
        status = requests.head(url).status_code

        if status == 200:
            return True
        else:
            raise RemoteFileDoesntExist


def remove_slash(value):
    """ Removes slash from beginning and end of a string """
    assert isinstance(value, str)
    return re.sub('(^\/|\/$)', '', value)
