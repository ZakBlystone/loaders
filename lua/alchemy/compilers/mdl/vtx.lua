--[[
This file is a part of the Loaders repository:
https://github.com/ZakBlystone/loaders

MDL3: source-engine studiomdl parser:
loads a studiomdl model

Usage:
mdl3.LoadModel( filename, <path> )
loads mdl, vtx, vvd

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
        include("alchemy/common/datawriter.lua"),
    },
})

local lshift, rshift, band, bor, bnot = bit.lshift, bit.rshift, bit.band, bit.bor, bit.bnot
local default_weight = { {0, 1}, {0, 0}, {0, 0} }

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

MAX_NUM_BONES_PER_VERT = 3
MAX_NUM_LODS = 8

local function vtx_bonestatechange(v)

    return {
        hardwareID = int32(v.hardwareID),
        newBoneID = int32(v.newBoneID),
    }

end

local function vtx_vertex(v)

    return {
        boneWeightIndex = array_of(uint8, v.boneWeightIndex),
        numBones = uint8(v.numBones),
        origMeshVertID = uint16(v.origMeshVertID),
        boneID = array_of(int8, v.boneID),
    }

end

local function vtx_strip(v)

    local base = tell_data()
    local strip = {
        numIndices = int32(v.numIndices),
        indexOffset = int32(v.indexOffset),
        numVerts = int32(v.numVerts),
        vertOffset = int32(v.vertOffset),
        numBones = int16(v.numBones),
        flags = uint8(STRIP_IS_TRILIST),
        boneStateChanges = indirect_array(vtx_bonestatechange, v.boneStateChanges), -- figure out
    }

    return strip

end

-- actually mesh
local function vtx_stripgroup( v )

    local base = tell_data()
    --print("BASE AT: " .. base)
    local group = {
        vertices = indirect_array(vtx_vertex, v.vertices), 
        indices = indirect_array(uint16, v.indices),
        strips = indirect_array(vtx_strip, v.strips),
        flags = uint8(v:GetFlags()), -- todo: compute these flags
    }

    --PrintTable(group)

    defer_indirect_array(group, base, "vertices")
    defer_indirect_array(group, base, "indices")
    defer_indirect_array(group, base, "strips")

    return group

end

local function vtx_mesh(v)

    local base = tell_data()
    local mesh = {
        stripgroups = indirect_array(vtx_stripgroup, v.stripgroups),
        flags = uint8(0), -- teeth / eyes
    }

    defer_indirect_array(mesh, base, "stripgroups")
    return mesh

end

-- actually model
local function vtx_modellod(v)

    local base = tell_data()
    local lod = {
        meshes = indirect_array(vtx_mesh, v.meshes),
        switchPoint = float32(0),
    }

    defer_indirect_array(lod, base, "meshes")
    return lod

end

local function vtx_model(v)

    local base = tell_data()
    local model = {
        lods = indirect_array(vtx_modellod, { v }),
    }

    defer_indirect_array(model, base, "lods")
    return model

end

local function vtx_bodypart(v)

    local base = tell_data()
    local part = {
        models = indirect_array(vtx_model, v.models),
    }

    defer_indirect_array(part, base, "models")
    return part

end

local function vtx_materialreplacement(v)

    local base = tell_data()
    local replace = {
        materialID = int16(v.materialID),
        nameidx = indirect_name(v.name),
    }

    return replace

end

local function vtx_materialreplacementlist(v)

    local base = tell_data()
    local replacelist = {
        replacements = indirect_array(vtx_materialreplacement, v.replacements)
    }

    defer_indirect_array(replacelist, base, "replacements")
    return replacelist

end

local function vtx_header(v)

    local base = tell_data()
    local header = {
        version = int32(VTX_VERSION),
        vertCacheSize = int32(24), -- figure out
        maxBonesPerStrip = uint16(53), -- figure out
        maxBonesPerTri = uint16(MAX_NUM_BONES_PER_VERT*3),
        maxBonesPerVert = int32(MAX_NUM_BONES_PER_VERT),
        checksum = int32(v:GetChecksum()),
        numLODs = int32(1),
        materialReplacementListOffset = int32(0),
        bodyParts = indirect_array( vtx_bodypart, v.bodyparts ),
    }

    --PrintTable(header)

    defer_indirect_array(header, 0, "bodyParts")

    local list_offset = tell_data() - base
    push_data(header.materialReplacementListOffset)
    int32(list_offset)
    pop_data()

    vtx_materialreplacementlist( {
        replacements = {},
    } )

    write_deferred_arrays()

    return header

end

function WriteStudioVTX( studio )

    open_data("studio/vtx.dat")
    vtx_header( studio )
    end_data()

end

return __lib