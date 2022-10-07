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
        include("../../common/datareader.lua"),
        include("../../common/utils.lua"),
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

VTX_VERSION = 7

__mdl_version = 0

function vtx_get_coverage_vis() return get_coverage_vis() end

local meta_vtx_vertx = {}
meta_vtx_vertx.__index = meta_vtx_vertx

function meta_vtx_vertx:__tostring()

    return string.format("v:%i, bn:%i, b:[%i,%i,%i], w:[%i,%i,%i]",
    self.origMeshVertID,
    self.numBones,
    self.boneID[1],
    self.boneID[2],
    self.boneID[3],
    self.boneWeightIndex[1],
    self.boneWeightIndex[2],
    self.boneWeightIndex[3])

end

local function vtx_bonestatechange()

    return {
        hardwareID = int32(),
        newBoneID = int32(),
    }

end

local function vtx_vertex()

    return setmetatable({
        boneWeightIndex = array_of(uint8, 3),
        numBones = uint8(),
        origMeshVertID = uint16(),
        boneID = array_of(int8, 3),
    }, meta_vtx_vertx)

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
        boneStateChanges = indirect_array(vtx_bonestatechange),
    }

    assert(strip.flags <= 3, "Invalid flags on strip")

    load_indirect_array(strip, base, "boneStateChanges")

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

    load_indirect_array(group, base, "vertices")
    load_indirect_array(group, base, "indices")
    load_indirect_array(group, base, "strips")

    local vertices = group.vertices
    local indices = group.indices

    --[[for i=1, #indices do
        local idx = indices[i]
        local vidx = vertices[idx+1].origMeshVertID+1
        indices[i] = vidx
    end]]

    if __mdl_version >= 49 then
        uint32()
        uint32()
    end

    --group.vertices = nil

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

local function vtx_materialreplacement()

    local base = tell_data()
    local replace = {
        materialID = int16(),
        nameidx = int32(),
    }

    indirect_name(replace, base)
    return replace

end

local function vtx_materialreplacementlist()

    local base = tell_data()
    local replacelist = {
        replacements = indirect_array(vtx_materialreplacement)
    }

    load_indirect_array(replacelist, base, "replacements")
    return replacelist

end

local function vtx_header()

    local base = tell_data()
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

    assert(header.version == VTX_VERSION, "Version mismatch: " .. (header.version) .. " != " .. VTX_VERSION)

    print("VERSION: " .. header.version)
    print("MATERIAL REPLACEMENT LIST: " .. header.materialReplacementListOffset)

    push_data(base + header.materialReplacementListOffset)
    header.materialReplacementListOffset = nil
    header.materialReplacementList = vtx_materialreplacementlist()
    pop_data()

    load_indirect_array(header, 0, "bodyParts")
    return header

end

function LoadVTX( filename, path, mdl_version )

    __mdl_version = mdl_version
    open_data(filename, path)
    local header = vtx_header()
    end_data()
    return header

end

return __lib