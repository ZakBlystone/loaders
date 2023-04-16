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
    using = {},
})

alchemy.InstallDataWriter()

MAX_NUM_BONES_PER_VERT = 3
MAX_NUM_LODS = 8

VVD_VERSION = 4
VVD_IDENT = "IDSV"

vvd_boneweight_size = 5 * MAX_NUM_BONES_PER_VERT + 1
vvd_vertex_size = vvd_boneweight_size + 24 + 8
vvd_tangent_size = 16

local default_weight = { {0, 1}, {0, 0}, {0, 0}, num = 1 }

local function vvd_boneweight(v)

    local w = v
    if #w ~= 3 then w = default_weight end

    return {
        weight = array_of(float32, {w[1][2],w[2][2],w[3][2]}),
        bone = array_of(uint8, {w[1][1],w[2][1],w[3][1]}),
        numBones = uint8(w.num),
    }

end

local function vvd_vertex(v)

    return {
        weights = vvd_boneweight(v.weights),
        position = vector32(v.position),
        normal = vector32(v.normal),
        u = float32(v.u),
        v = float32(v.v),
    }

end

local function vvd_tangent(v)

    return {
        x = float32(v.x),
        y = float32(v.y),
        z = float32(v.z),
        w = float32(v.w),
    }

end

local function vvd_header(v)

    assert(#v.vertices == #v.tangents, "Vertex tangent count mismatch")
    print("WRITE: " .. #v.vertices .. " vertices")

    local num_vertices = #v.vertices
    local header = {
        id = charstr(VVD_IDENT,4),
        version = int32(VVD_VERSION),
        checksum = int32(v:GetChecksum()),
        numLODs = int32(1),
        numLODVertices = array_of(int32, {
            num_vertices, 
            num_vertices, 
            num_vertices, 
            num_vertices, 
            num_vertices, 
            num_vertices, 
            num_vertices, 
            num_vertices}),
        numFixups = int32(0),
        fixupTableStart = int32(0),
        vertexDataStart = int32(0),
        tangentDataStart = int32(0),
    }

    -- Vertices
    local vertexBase = tell_data()
    push_data(header.vertexDataStart)
    int32(vertexBase)
    pop_data()

    for i=1, #v.vertices do
        vvd_vertex(v.vertices[i])
    end

    -- Tangents
    local tangentBase = tell_data()
    push_data(header.tangentDataStart)
    int32(tangentBase)
    pop_data()

    for i=1, #v.tangents do
        vvd_tangent(v.tangents[i])
    end

end

function WriteStudioVVD( studio )

    open_data("studio/vvd.dat")
    vvd_header( studio )
    end_data()

end

return __lib