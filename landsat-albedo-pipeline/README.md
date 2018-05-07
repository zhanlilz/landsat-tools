* bsub_landsat_albedo.sh: Processing for each scene in a list of scene ID (e.g.: LC80010022016230LGN01) and its downloading URL. The list should be sorted in ascending order of acquisition date, WRS-path, WRS-row.

    1. Download three scenes (with the middle one as the target) of Landsaat TOA data from public repository Google Storage or AWS S3.
    2. Generate the three scenes of SR using atmospheric corretion from ESPA.
    3. Download MCD43 BRDF data files that are needed for a scene. 
    4. Generate the Landsat albedo of the target scene. 
    5. Move the Landsat albedo data to the designated location. 
    6. Remove the input TOA and SR data to save space. 

