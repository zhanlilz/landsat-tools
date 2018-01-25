import os
import sys

import sqlalchemy as sa
import pandas as pd

from homura import download

from scene import Scene, Scenes
from common import GS_PUBURL_PREFIX, check_create_folder

class Landsat(Scenes):
    def __init__(self, spacecraft_id, bucket_id, index_db=None, index_tb="landsat"):
        super(Landsat, self).__init__()
        self._saved_scenes = dict()
        # spacecraft_id: Landsat_5, Landsat_7, Landsat_8
        # bucket_id: Google, AWS
        spacecraft_id = spacecraft_id.upper()
        bucket_id = bucket_id.upper()
        self.spacecraft_id = spacecraft_id
        self.bucket_id = bucket_id

        self.index_db_defined = False
        if index_db is not None and index_tb is not None:
            self.defIndexDatabase(index_db, index_tb)
            self.index_db_defined = True
            
        if (bucket_id == "GOOGLE"):
            self._colnames = dict(target_id = "PRODUCT_ID", c_number = "COLLECTION_NUMBER", 
                                  sc_id = "SPACECRAFT_ID", 
                                  wrs_path = "WRS_PATH", wrs_row = "WRS_ROW", 
                                  acq_date = "SENSING_TIME", url = "BASE_URL")
        elif (bucket_id == "AWS"):
            self._colnames = dict(target_id = "productId", c_number = None, 
                                  sc_id = None, 
                                  wrs_path = "path", wrs_row = "row", 
                                  acq_date = "acquisitionDate", url = "download_url")
        else:
            raise RuntimeError("Accessing the data bucket {0:s} not implemented!".format(bucket_id))

        if (spacecraft_id == "LANDSAT_8"):
            self._target_suffix = ["_ANG.txt", 
                                   "_B1.TIF", 
                                   "_B10.TIF",
                                   "_B11.TIF",
                                   "_B2.TIF",
                                   "_B3.TIF",
                                   "_B4.TIF",
                                   "_B5.TIF",
                                   "_B6.TIF",
                                   "_B7.TIF",
                                   "_B8.TIF",
                                   "_B9.TIF",
                                   "_BQA.TIF",
                                   "_MTL.txt"]
        elif (spacecraft_id == "LANDSAT_7"):
            self._target_suffix = ["_ANG.txt", 
                                   "_B1.TIF", 
                                   "_B2.TIF",
                                   "_B3.TIF",
                                   "_B4.TIF",
                                   "_B5.TIF",
                                   "_B6_VCID_1.TIF",
                                   "_B6_VCID_2.TIF",
                                   "_B7.TIF",
                                   "_B8.TIF",
                                   "_BQA.TIF",
                                   "_MTL.txt"]
        elif (spacecraft_id == "LANDSAT_5"):
            self._target_suffix = ["_ANG.txt", 
                                   "_B1.TIF", 
                                   "_B2.TIF",
                                   "_B3.TIF",
                                   "_B4.TIF",
                                   "_B5.TIF",
                                   "_B6.TIF",
                                   "_B7.TIF",
                                   "_BQA.TIF",
                                   "_MTL.txt"]
        else:
            raise RuntimeError("Unrecognized Landsat spacecraft {0:s}".format(spacecraft_id))


    def defIndexDatabase(self, index_db, index_tb="landsat"):
        self.index_db_name = index_db
        self.index_db_engine = sa.create_engine("sqlite:///{0:s}".format(index_db))
        self.index_tb_name = index_tb
        self.index_db_defined = True


    def _indexUrlToFileUrls(self, index_url):
        if (self.bucket_id == "GOOGLE"):
            base_url = index_url.replace('gs://', GS_PUBURL_PREFIX)
        elif (self.bucket_id == "AWS"):
            base_url = index_url.rstrip("/index.html")

        target_id = base_url.rstrip('/').split('/')[-1]
        return ["{0:s}/{1:s}{2:s}".format(base_url, target_id, ss) 
                for ss in self._target_suffix]

        
    def addPathRow(self, path, row, start_date=None, end_date=None):
        # start_date (str), YYYY-MM-DD
        # end_date (str): YYYY-MM-DD
        if not self.index_db_defined:
            return 0

        sql_query_str = """
        SELECT 
         {0:s}, 
         {1:s} """.format(self._colnames["target_id"], 
                          self._colnames["url"])

        sql_query_str = sql_query_str + """
        FROM
         "{0:s}" """.format(self.index_tb_name)

        sql_query_str = sql_query_str + """
        WHERE
         {0:s} == {1:d}
         AND {2:s} == {3:d} """.format(self._colnames["wrs_path"], path, 
                                       self._colnames["wrs_row"], row)

        if start_date is not None:
            sql_query_str = sql_query_str + """
             AND {0:s} >= datetime("{1:s}")"""
            sql_query_str = sql_query_str.format(self._colnames["acq_date"], 
                                                 start_date)
        if end_date is not None:
            sql_query_str = sql_query_str + """
             AND {0:s} <= datetime("{1:s}")"""
            sql_query_str = sql_query_str.format(self._colnames["acq_date"], 
                                                 "{0:s} 23:59:59".format(end_date))

        if (self.bucket_id == "GOOGLE"):
            sql_query_str = sql_query_str + """
             AND {0:s} != "PRE" 
             AND {1:s} == "{2:s}" """.format(self._colnames["c_number"], 
                                             self._colnames["sc_id"], 
                                             self.spacecraft_id)
        sql_query_str = sql_query_str + ";"

        search_result = pd.read_sql_query(sql_query_str, self.index_db_engine)
        if len(search_result) > 0:
            for idx, row in search_result.iterrows():
                one_scn = Scene(row[self._colnames["target_id"]])
                file_urls = self._indexUrlToFileUrls(row[self._colnames["url"]])
                for f in file_urls:
                    one_scn.add(f)
                self.add(one_scn)
                self._saved_scenes[one_scn.name] = False

        return len(search_result)


    def searchPathRow(self, path, row, start_date=None, end_date=None):
        if not self.index_db_defined:
            return None

        # start_date (str), YYYY-MM-DD
        # end_date (str): YYYY-MM-DD
        sql_query_str = """
        SELECT 
         * """

        sql_query_str = sql_query_str + """
        FROM
         "{0:s}" """.format(self.index_tb_name)

        sql_query_str = sql_query_str + """
        WHERE
         {0:s} == {1:d}
         AND {2:s} == {3:d} """.format(self._colnames["wrs_path"], path, 
                                       self._colnames["wrs_row"], row)

        if start_date is not None:
            sql_query_str = sql_query_str + """
             AND {0:s} >= datetime("{1:s}")"""
            sql_query_str = sql_query_str.format(self._colnames["acq_date"], 
                                                 start_date)
        if end_date is not None:
            sql_query_str = sql_query_str + """
             AND {0:s} <= datetime("{1:s}")"""
            sql_query_str = sql_query_str.format(self._colnames["acq_date"], 
                                                 "{0:s} 23:59:59".format(end_date))

        if (self.bucket_id == "GOOGLE"):
            sql_query_str = sql_query_str + """
             AND {0:s} != "PRE" 
             AND {1:s} == "{2:s}" """.format(self._colnames["c_number"], 
                                             self._colnames["sc_id"], 
                                             self.spacecraft_id)
        sql_query_str = sql_query_str + ";"

        return pd.read_sql_query(sql_query_str, self.index_db_engine)


    def _scnIdToSpacecraftId(self, scn_id):
        sc_code = int(scn_id[2])
        if sc_code != 5 and sc_code != 7 and sc_code != 8:
            return None
        return "LANDSAT_{0:d}".format(sc_code)
        

    def _indexUrlToBucketId(self, index_url):
        if index_url[0:2] == "gs" or index_url.find("googleapi.com") > -1:
            return "GOOGLE"
        elif index_url.find("amazonaws.com"):
            return "AWS"
        else:
            return None


    def addScene(self, scn_name, scn_index_url):
        if scn_name not in self.scenes:
            _sc_id = self._scnIdToSpacecraftId(scn_name)
            _bkt_id = self._indexUrlToBucketId(scn_index_url)
            if _sc_id is None or _bkt_id is None:
                return None
            if _sc_id != self.spacecraft_id:
                return None
            if _bkt_id != self.bucket_id:
                return None

            one_scn = Scene(scn_name)
            file_urls = self._indexUrlToFileUrls(scn_index_url)
            for f in file_urls:
                one_scn.add(f)
            self.add(one_scn)
            self._saved_scenes[one_scn.name] = False
        return scn_name

    
    def delScene(self, scn_name):
        if scn_name in self.scenes:
            del self[scn_name]
            del self._saved_scenes[scn_name]
        else:
            return None
        return scn_name


    def clearScenes(self):
        self.clear()
        self._saved_scenes = {}


    def saveToDir(self, path, show_progress=True):
        for scn in self.scenes_list:
            if (not self._saved_scenes[scn.name]):
                scn_dir = check_create_folder(os.path.join(path, scn.name))
                for f in scn.files:
                    if show_progress:
                        print("{0:s} : {1:s} ".format(scn.name, f.split('/')[-1]))
                    download(f, scn_dir, show_progress=show_progress)
