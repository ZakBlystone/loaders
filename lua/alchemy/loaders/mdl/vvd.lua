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

MAX_NUM_BONES_PER_VERT = 3
MAX_NUM_LODS = 8

vvd_boneweight_size = 5 * MAX_NUM_BONES_PER_VERT + 1
vvd_vertex_size = vvd_boneweight_size + 24 + 8

function vvd_get_coverage_vis() return get_coverage_vis() end

local function vvd_boneweight()

    return {
        weight = array_of(float32, MAX_NUM_BONES_PER_VERT),
        bone = array_of(uint8, MAX_NUM_BONES_PER_VERT),
        numBones = uint8(),
    }

end

local function vvd_vertex()

    return {
        weights = vvd_boneweight(),
        position = vector32(),
        normal = vector32(),
        u = float32(),
        v = float32(),
    }

end

local function vvd_tangent()

    return {
        x = float32(),
        y = float32(),
        z = float32(),
        w = float32(),
    }

end

local function vvd_header()

    return {
        id = int32(),
        version = int32(),
        checksum = int32(),
        numLODs = int32(),
        numLODVertices = array_of(int32, MAX_NUM_LODS),
        numFixups = int32(),
        fixupTableStart = int32(),
        vertexDataStart = int32(),
        tangentDataStart = int32(),
    }

end

local function vvd_fixup()

    return {
        lod = int32(),
        sourceID = int32(),
        numVertices = int32(),
    }

end

function LoadVVD( filename, path, lod, bLoadTangents )

    open_data(filename, path)

    local header = vvd_header()
    local fixups, vertices, tangents

    lod = math.Clamp(lod or 1, 1, header.numLODs)

    if header.numFixups > 0 then
        seek_data( header.fixupTableStart )
        fixups = array_of( vvd_fixup, header.numFixups )
    end
    
    seek_data( header.vertexDataStart )
    vertices = array_of( vvd_vertex, header.numLODVertices[lod] )

    if bLoadTangents then
        seek_data( header.tangentDataStart )
        tangents = array_of( vvd_tangent, header.numLODVertices[lod] )
    end

    if fixups then

        local corrected = table.Copy( vertices )
		local target = 0
		for _, fixup in ipairs( fixups ) do
			if fixup.lod < 0 then continue end

			for i=1, fixup.numVertices do
				corrected[ i + target ] = vertices[ i + fixup.sourceID ]
			end

			target = target + fixup.numVertices
		end
		vertices = corrected

    end

    end_data()

    if tangents then
        assert(#vertices == #tangents, "Tangent -> Vertex mismatch")
        for i=1, #vertices do
            vertices[i].tangent = tangents[i]
        end
    end

    header.vertices = vertices

	return header

end

return __lib