--[[
This file is a part of the Loaders repository:
https://github.com/ZakBlystone/loaders

BSP3: source-engine map parser:
loads a .bsp file and converts it into readable data.

Usage:
bsp3.LoadBSP( filename, requested_lumps, path )
returns an object containing raw data for the requested lumps and some accessor utility functions

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
        alchemy.utils,
    }
})

alchemy.InstallDataReader(false, __lib)

local compressed_arrays = {}

local function type_array(t)

    return function()
        local length = uint32()
        local encoding = uint32()
        local compressed = uint32()

        if encoding == 0 then
            return array_of(t, length)
        else
            print("COMPRESSED LENGTH: " .. compressed .. " -> " .. length)
            local chunk = {}
            chunk.cdata = charstr(compressed)
            chunk.type = t
            chunk.length = length
            assert(chunk.cdata)
            compressed_arrays[#compressed_arrays+1] = chunk
            return chunk
        end
    end

end

local typecodes = {
    ['Y'] = int16,
    ['C'] = uint8,
    ['I'] = int32,
    ['F'] = float32,
    ['D'] = float64,
    ['L'] = function() charstr(8) return 696969 end,
    ['S'] = function() return vcharstr(int32()) end,
    ['R'] = function() return charstr(int32()) end,
    ['f'] = type_array(float32),
    ['d'] = type_array(float64),
    ['l'] = type_array( function() charstr(8) return 696969 end ),
    ['i'] = type_array(int32),
    ['b'] = type_array(uint8),
}

local function property_record()

    local tc = char()
    local typecode = typecodes[tc]
    print("TC: " .. tc)
    assert(typecode, "No typecode for : " .. tostring(tc))

    return typecode()

end

local function node_record(depth)

    local offset = tell_data()
    local end_offset = uint32()
    local num_properties = uint32()
    local property_list_length = uint32()
    local name_length = uint8()
    local node = {
        props = {},
    }

    node.name = vcharstr(name_length)
    print("'" .. node.name .. "' @ " .. depth)

    for i=1, num_properties do
        node.props[#node.props+1] = property_record()
    end

    local remain = end_offset - tell_data()

    local kmax = 100
    while remain > 0 and kmax > 0 do
        node.children = node.children or {}
        node.children[#node.children+1] = node_record(depth + 1)
        remain = end_offset - tell_data()
        print(" -- " .. remain)
        kmax = kmax - 1
    end

    if remain == 0 then
        --print("NULL TERM")
        --vcharstr(13)
    end

    return node

end

function Load( filename, path )

    open_data(filename, path)

    local header = {
        magic = vcharstr(21),
        extra = vcharstr(2),
        version = uint32(),
    }

    print_table(header)

    local root = node_record(0)
    print_table(root)

    print_table(node_record(0))
    print_table(node_record(0))
    print_table(node_record(0))
    print_table(node_record(0))
    print_table(node_record(0))
    print_table(node_record(0))
    print_table(node_record(0))

    --local objects = node_record(0)

    --print_table(node_record(0))

    end_data()

    for k,v in ipairs(compressed_arrays) do
        --print("-- Inflate array [" .. k .. "] -- " .. #v.cdata)
        local data = alchemy.LibDeflate:DecompressZlib(v.cdata)
        begin_data(data)
        local parsed = array_of(v.type, v.length)
        end_data()

        v.cdata = nil
        v.type = nil
        v.length = nil
        for i=1, #parsed do v[i] = parsed[i] end

        if k == 5 then
            --print_table(parsed)
        end
    end

    --print_table(objects, "objects", {}, 10, 10)

end

--if SERVER then Load("test.fbx", "DATA") end

return __lib