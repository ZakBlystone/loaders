--[[
This file is a part of the Loaders repository:
https://github.com/ZakBlystone/loaders

MIT License

Copyright (c) 2022 ZakBlystone

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

AddCSLuaFile()
local __lib = alchemy.MakeLib({
    using = {
        include("alchemy/common/datareader.lua"),
    },
})

local lshift, rshift, band, bor, bnot = bit.lshift, bit.rshift, bit.band, bit.bor, bit.bnot

-- Strip flags
STRIP_IS_TRILIST = 1
STRIP_IS_TRISTRIP = 2

-- Stripgroup flags
STRIPGROUP_IS_FLEXED = 0x01
STRIPGROUP_IS_HWSKINNED = 0x02
STRIPGROUP_IS_DELTA_FLEXED = 0x04
STRIPGROUP_SUPPRESS_HW_MORPH = 0x08

-- Mesh flags
MESH_IS_TEETH = 0x01
MESH_IS_EYES = 0x02

function vtx_get_coverage_vis() return get_coverage_vis() end

local function vtx_vertex()

    return {
        boneWeightIndex = array_of(uint8, 3),
        numBones = uint8(),
        origMeshVertID = uint16(),
        boneID = array_of(int8, 3),
    }

end

local function vtx_strip()

    local base = tell_data()
    local strip = {
        numIndices = int32(),
        indexOffset = int32(),
        numVerts = int32(),
        vertOffset = int32(),
        numBones = int16(),
        flags = uint8(),
        numBoneStateChanges = int32(),
        boneStateChangeOffset = int32(),
    }

    if band(strip.flags, STRIP_IS_TRILIST) ~= 0 then
        strip.isTriList = true
    elseif band(strip.flags, STRIP_IS_TRISTRIP) ~= 0 then
        strip.isTriStrip = true
        error("Tri Strip not supported!")
    end
    strip.flags = nil

    return strip

end

local function vtx_stripgroup()

    local base = tell_data()
    --print("BASE AT: " .. base)
    local group = {
        vertices = indirect_array(vtx_vertex),
        indices = indirect_array(uint16),
        strips = indirect_array(vtx_strip),
        flags = uint8(),
    }

    if band(group.flags, STRIPGROUP_IS_FLEXED) ~= 0 then group.isFlexed = true end
    if band(group.flags, STRIPGROUP_IS_HWSKINNED) ~= 0 then group.isHWSkinned = true end
    if band(group.flags, STRIPGROUP_IS_DELTA_FLEXED) ~= 0 then group.isDeltaFlexed = true end
    if band(group.flags, STRIPGROUP_SUPPRESS_HW_MORPH) ~= 0 then group.supressHWMorph = true end
    group.flags = nil

    --PrintTable(group)

    load_indirect_array(group, base, "vertices")
    load_indirect_array(group, base, "indices")
    load_indirect_array(group, base, "strips")

    local vertices = group.vertices
    local indices = group.indices

    --print("VERTS: " .. #vertices)
    for i=1, #indices do
        local idx = indices[i]
        local vidx = vertices[idx+1].origMeshVertID+1
        indices[i] = vidx
    end

    group.vertices = nil

    return group

end

local function vtx_mesh()

    local base = tell_data()
    local mesh = {
        stripgroups = indirect_array(vtx_stripgroup),
        flags = uint8(),
    }

    if band(mesh.flags, MESH_IS_TEETH) ~= 0 then mesh.isTeeth = true end
    if band(mesh.flags, MESH_IS_EYES) ~= 0 then mesh.isEyes = true end
    mesh.flags = nil

    load_indirect_array(mesh, base, "stripgroups")
    return mesh

end

local function vtx_modellod()

    local base = tell_data()
    local lod = {
        meshes = indirect_array(vtx_mesh),
        switchPoint = float32(),
    }

    load_indirect_array(lod, base, "meshes")
    return lod

end

local function vtx_model()

    local base = tell_data()
    local model = {
        lods = indirect_array(vtx_modellod),
    }

    load_indirect_array(model, base, "lods")
    return model

end

local function vtx_bodypart()

    local base = tell_data()
    local part = {
        models = indirect_array(vtx_model),
    }

    load_indirect_array(part, base, "models")
    return part

end

local function vtx_header()

    local header = {
        version = int32(),
        vertCacheSize = int32(),
        maxBonesPerStrip = uint16(),
        maxBonesPerTri = uint16(),
        maxBonesPerVert = int32(),
        checksum = int32(),
        numLODs = int32(),
        materialReplacementListOffset = int32(),
        bodyParts = indirect_array( vtx_bodypart ),
    }

    --PrintTable(header)

    load_indirect_array(header, 0, "bodyParts")
    return header

end

function LoadVTX( filename, path )

    open_data(filename, path)
    local header = vtx_header()
    end_data()
    return header

end

return __lib