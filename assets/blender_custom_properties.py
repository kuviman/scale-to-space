import bpy

# list of unwanted properties to remove
unwanted_properties = {
    "",
}

# list of properties to rename
renamed_properties = {
    "aniamted": "animated", # typo rename example
}

# list of required properties with default values
required_properties = {
    "particles": 1,
    "particle_t": 1.000,
    "particle_spread": 1.000,
    "bounciness": 1.000,
    "friction": 1.000,
    "animated": False,

    "collidable": True,

    # empty = no particle / sfx, set these per material
    "particle_assetpath": "",
    "sfx_assetpath": "",
}

# loop all mats
for mat in bpy.data.materials:

    # skip system embedded mats
    if mat.is_embedded_data:
        continue

    # remove unwanted properties
    for key in unwanted_properties:
        if key in mat:
            del mat[key]

    # rename properties
    for old_key, new_key in renamed_properties.items():
        if old_key in mat:
            if new_key not in mat:
                mat[new_key] = mat[old_key]
            del mat[old_key]

    # add required properties with default values
    for key, default_value in required_properties.items():
        if key not in mat:
            mat[key] = default_value