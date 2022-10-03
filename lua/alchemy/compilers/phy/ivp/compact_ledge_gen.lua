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

module("ivp", package.seeall)

local lshift = bit.lshift
local rshift = bit.rshift
local bor = bit.bor
local bnot = bit.bnot
local band = bit.band
local util = include("../../../common/utils.lua")

-- COMPACT EDGE
local meta = {}
meta.__index = meta

function meta:Init()
    self.start_point_index = 0 --16
    self.opposite_index = 0 --15
    self.is_virtual = 0 --1
    self.indices = 0
    return self
end

function meta:SetStartPointIndex(val) 
    assert(val >= 0 and val < 0x1p16, "INVALID INDEX: " .. val)
    self.indices = band(self.indices, 0xFFFF0000)
    self.indices = bor(self.indices, val) 
    self.start_point_index = val 
end

function meta:SetOppositeIndex(val) 
    assert(val >= -(0x1p14)+1 and val < 0x1p14-1)
    self.opposite_index = val
    val = band(val, 0x00007FFF)
    self.indices = band(self.indices, 0x8000FFFF)
    self.indices = bor(self.indices, lshift(val,16))
end

function meta:SetIsVirtual(val)
    self.indices = band(self.indices, 0x7FFFFFFF)
    if val then self.indices = bor(self.indices, 0x80000000) end
    self.is_virtual = val
end

function CompactEdge()
    return setmetatable({}, meta):Init()
end

-- COMPACT TRIANGLE
local meta = {}
meta.__index = meta

function meta:Init()
    self.tri_index = 0 --12
    self.pierce_index = 0 --12
    self.material_index = 0 --7
    self.is_virtual = 0 --1
    self.indices = 0
    self.edges = { CompactEdge(),CompactEdge(),CompactEdge() }
    return self
end

function meta:SetTriIndex(val) 
    assert(val >= 0 and val < 0x1p12) 
    self.indices = band(self.indices, 0xFFFFF000)
    self.indices = bor(self.indices, val) 
    self.tri_index = val
end

function meta:SetPierceIndex(val) 
    assert(val >= 0 and val < 0x1p12)
    self.indices = band(self.indices, 0xFF000FFF)
    self.indices = bor(self.indices, lshift(val, 12)) 
    self.pierce_index = val
end

function meta:SetMaterialIndex(val) 
    assert(val >= 0 and val < 0x1p7)
    self.indices = band(self.indices, 0x80FFFFFF)
    self.indices = bor(self.indices, lshift(val, 24))
    self.material_index = val
end

function meta:SetIsVirtual(val)
    self.indices = band(self.indices, 0x7FFFFFFF)
    if val then self.indices = bor(self.indices, 0x80000000) end
end

function CompactTriangle()
    return setmetatable({}, meta):Init()
end

-- COMPACT LEDGE
local meta = {}
meta.__index = meta

function meta:Init()
    self.c_point_offset = 0
    self.ledgetree_node_offset = 0
    self.size_div_16 = 0
    self.n_triangles = 0
    self.data = 0x04

    self.tmp_triangles = nil
    self.tmp_points = nil
    self.tmp_mins = Vector()
    self.tmp_maxs = Vector()
    return self
end

function meta:SetMaterialIndex( idx )
    for _, tri in ipairs(self.tmp_triangles) do
        tri:SetMaterialIndex( idx )
    end
end

function meta:GetBoundingBox()
    return self.tmp_mins, self.tmp_maxs
end

function meta:SetOffsetLedgePoints(offset)
    assert(band(offset, 0xF) == 0)
    self.c_point_offset = offset
end

function meta:SetSize(size)
    assert(size > 0 and band(size, 0xF) == 0)
    self.size_div_16 = rshift(size, 4)
    self.data = band(self.data, 0x000000FF)
    self.data = bor(self.data, lshift(self.size_div_16, 8))
end

function meta:GetSize()
    return self.size_div_16 * 16
end

function meta:TakePoints()

    local t = self.tmp_points
    self:SetSize( self:GetSize() - (#t * IVP_Size_PolyPoint) )
    self.tmp_points = {}
    return t

end

function meta:Write(stream)

    assert(bit.band(self.data, 0x0000000F) == 0x04)

    stream:WriteLong(self.c_point_offset)
    stream:WriteLong(self.ledgetree_node_offset)
    stream:WriteULong(self.data)
    stream:WriteShort(self.n_triangles)
    stream:WriteShort(0)

    for _,tri in ipairs(self.tmp_triangles) do
        stream:WriteULong(tri.indices)
        stream:WriteULong(tri.edges[1].indices)
        stream:WriteULong(tri.edges[2].indices)
        stream:WriteULong(tri.edges[3].indices)
    end

    for _,point in ipairs(self.tmp_points) do
        local v = point.v
        stream:WriteFloat(v.x)
        stream:WriteFloat(v.y)
        stream:WriteFloat(v.z)
        stream:WriteFloat(0)
        print(" WL: point " .. v.x .. " : " .. v.y .. " : " .. v.z)
    end

end

function CompactLedge()
    return setmetatable({}, meta):Init()
end


local meta = {}
meta.__index = meta

local temp = Vector()
local function point_compare_func(p, point)
    temp:Set(p.v)
    temp:Sub(point.v)
    if temp:LengthSqr() < 0.0001 then return true end
    return false
end

function meta:Init()

    self.edge_hash = {}
    self.points = {}
    self.triangles = {}
    self.point_count = 0
    self.edge_count = 0
    self.n_triangles = 0
    self.tmp_mins = Vector()
    self.tmp_maxs = Vector()
    return self
end

function meta:Prepare( triangles )

    self.n_triangles = #triangles

    self.tmp_mins:SetUnpacked(math.huge, math.huge, math.huge)
    self.tmp_maxs:SetUnpacked(-math.huge, -math.huge, -math.huge)

    local edge_hash = self.edge_hash
    local point_hash = PointHash(point_compare_func)
    for k, tri in ipairs(triangles) do
        tri.index = k-1
        local e = tri.edges[1]
        for i=1, 3 do
            local p, idx = point_hash:FindPoint(e.start_point) 
            if p == nil then
                e.start_point.compact_index = self.point_count
                self.point_count = self.point_count + 1
                point_hash:AddPoint(e.start_point)
                self.points[#self.points+1] = e.start_point
                local v = e.start_point.v
                util.v_min(self.tmp_mins, v)
                util.v_max(self.tmp_maxs, v)
            else
                e.start_point.compact_index = idx-1
            end
            e = e.next
        end

    end

    -- edge.start_point_index
    -- edge.opposite_index
    -- edge.is_virtual
    for k, tri in ipairs(triangles) do
        local c_tri = CompactTriangle()
        
        c_tri:SetTriIndex( tri.index )
        if tri.pierced ~= nil then
            c_tri:SetPierceIndex( tri.pierced.index )
        else
            print("no valid pierce index")
        end

        -- edges
        local e = tri.edges[1]
        for i=1, 3 do
            local c_edge = c_tri.edges[i]
            c_edge:SetStartPointIndex(e.start_point.compact_index)
            c_edge.tmp_edge = e
            e.compact_edge = c_edge
            assert(edge_hash[e] == nil)
            edge_hash[e] = ((k-1) * 4) + i
            --print(edge_hash[e])
            self.edge_count = self.edge_count + 1
            e = e.next
        end

        self.triangles[#self.triangles+1] = c_tri
    end

    for k, tri in ipairs(triangles) do
        local c_tri = self.triangles[k]
        -- edges
        local e = tri.edges[1]
        for i=1, 3 do
            local c_edge = c_tri.edges[i]
            local opp = e.opposite
            local opp_index = edge_hash[opp]
            assert(opp_index ~= nil and opp_index > 0)
            local rel_index = opp_index - ((k-1) * 4 + i)
            c_edge:SetOppositeIndex(rel_index)
            c_edge.opposite = opp.compact_edge
            --print(c_edge.start_point_index .. " -> " .. c_edge.opposite_index .. " (" .. opp_index .. ")" .. " [" .. edge_hash[e])
            e = e.next
        end
    end

end

function meta:Generate()

    local size = IVP_Size_Compact_Ledge
    size = size + IVP_Size_Compact_Triangle * self.n_triangles
    size = size + IVP_Size_PolyPoint * self.point_count

    local ptr = 0
    ptr = ptr + IVP_Size_Compact_Ledge
    ptr = ptr + IVP_Size_Compact_Triangle * self.n_triangles

    local c_ledge = CompactLedge()
    c_ledge.n_triangles = self.n_triangles
    c_ledge.tmp_triangles = self.triangles
    c_ledge.tmp_points = self.points
    c_ledge.tmp_mins:Set(self.tmp_mins)
    c_ledge.tmp_maxs:Set(self.tmp_maxs)
    c_ledge:SetSize(size)
    c_ledge:SetOffsetLedgePoints(ptr)

    assert(c_ledge.n_triangles == #self.triangles, "Invalid triangle count")


    --print(#self.points .. " points")
    --print(self.n_triangles * 3 .. " edges")
    --print("SIZE: " .. size)

    return c_ledge

end

function Compact_Ledge_Generator()

    return setmetatable({}, meta):Init()

end