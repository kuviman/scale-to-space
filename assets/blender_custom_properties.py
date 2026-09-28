import bpy

unwanted_properties = {
    "partivles", # typo example
}

required_properties = {
    "particles": 1,
    "particle_t": 1.000,
    "particle_spread": 1.000,
    "bounciness": 1.000,
    "friction": 1.000,
    "aniamted": False, 
    
    "collidable": True, 
    
    "particle_assetpath": "sprites/particle/fire.png", 
    "sfx_assetpath": "sfx/surfaces/lava.wav",
}

# loop all mats
for mat in bpy.data.materials:
    
    # skip system embedded mats
    if mat.is_embedded_data:
        continue
    
    for key in unwanted_properties:
        if key in mat:
            del mat[key]
            
    for key, default_value in required_properties.items():
        if key not in mat:
            mat[key] = default_value