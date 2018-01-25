* Input: a file of the list of scene ID (e.g.: LC80010022016230LGN01)

* Processing for a scene:

    1. Sort the list of scene IDs in ascending order of acquisition date, WRS-path, WRS-row.
    2. Download three scenes (with the middle one as the target) of Landsaat TOA data from public repository Google Storage or AWS S3.
    3. Generate the three scenes of SR using atmospheric corretion from ESPA.
    4. Generate the Landsat albedo of the target scene. 
    5. Move the Landsat albedo data to the designated location. 
    6. Remove the input TOA and SR data to save space. 