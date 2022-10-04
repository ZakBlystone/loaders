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

local utils = include("../../../common/utils.lua")
local ll_insert = utils.ll_insert
local ll_remove = utils.ll_remove

local lshift = bit.lshift
local bor = bit.bor

-- HESSE
local meta = {}
meta.__index = meta

function meta:Init()
    self.normal = Vector(0,0,0)
    self.hesse_val = 0
    return self
end

function meta:Length() return self.normal:Length() end
function meta:CalcHesse(p0, p1, p2)

    local a = p1 - p0
    local b = p2 - p0
    local c = b:Cross(a)
    self.normal = c
    self.hesse_val = -c:Dot(p0)

    assert( self.normal:Length() ~= 0, "zero-length hesse" )

end

function meta:Dot(other)
    if other.normal then
        return self.normal:Dot(other.normal)
    end
end

function meta:Normalize()

    local len = self.normal:Length()
    if len == 0 then error("Tried to normalize zero-length hesse") end

    local ilen = 1 / self.normal:Length()
    self.normal:Mul(ilen)
    self.hesse_val = self.hesse_val * ilen

end

function Hesse()

    return setmetatable({}, meta):Init()

end


-- POLYGON_TETRA
local meta = {}
meta.__index = meta

function meta:Init( template )
    self.template = template
    self.points = {}
    
    for k, point in ipairs( template.points ) do
        self.points[k] = Poly_Point( point )
        self.points[k].l_tetras = self
        self.points[k].index = k
    end

    assert(#self.points < 0x10000) -- for hash to work

    self.surfaces = {}

    for k, point in ipairs( template.surfaces ) do
        self.surfaces[k] = {
            tetra = self,
        }
    end
    
    self.first_triangle = nil
    return self
end

function meta:InsertPierceInfo()

    local max_scal_val = -0.000001

    -- might not need to do this clear pass
    local tri = self.first_triangle
    while tri ~= nil do
        tri.pierced = nil
        tri = tri.next
    end

    tri = self.first_triangle
    while tri ~= nil do
        if tri.is_hidden then tri = tri.next continue end
        if tri.pierced ~= nil then tri = tri.next continue end

        local min_scal_val = max_scal_val
        local found_tri = nil
        local tri2 = self.first_triangle
        while tri2 ~= nil do
            if tri2.is_hidden then tri2 = tri2.next continue end
            local scal_val = tri.hesse:Dot( tri2.hesse )
            if scal_val < min_scal_val then
                min_scal_val = scal_val
                found_tri = tri2
            end

            tri2 = tri2.next
        end

        assert(found_tri ~= nil)
        tri.pierced = found_tri
        found_tri.pierced = tri

        tri = tri.next
    end

end

function meta:MakeTriangles()

    local edge_hash = {}

    local function hash_key(a, b) return bor(lshift(a, 16),b) end

    local function check_for_opposite(p0, p1, edge)
        local key = nil
        if p0.index < p1.index then
            key = hash_key(p0.index, p1.index)
        else
            key = hash_key(p1.index, p0.index)
        end
        local edge2 = edge_hash[key]
        if not edge2 then
            edge_hash[key] = edge
        else
            edge.opposite = edge2
            edge2.opposite = edge
        end
    end

    for k, surf in ipairs( self.template.surfaces ) do
        
        local td_sur = P_Sur_2D( self, surf )
        td_sur:CalcLineRepresentation()
        td_sur:CalcTriangleRepresentation()

        local n = 0
        local td_tri = td_sur.first_triangle
        while td_tri ~= nil do

            assert(td_tri.point_nums[1] ~= td_tri.point_nums[2], "1 and 2 on P_Sur_2D[" .. n .. "] index the same point!")
            assert(td_tri.point_nums[1] ~= td_tri.point_nums[3], "1 and 3 on P_Sur_2D[" .. n .. "] index the same point!")
            assert(td_tri.point_nums[2] ~= td_tri.point_nums[3], "2 and 3 on P_Sur_2D[" .. n .. "] index the same point!")

            local p0 = self.points[ td_tri.point_nums[3] ]
            local p1 = self.points[ td_tri.point_nums[2] ]
            local p2 = self.points[ td_tri.point_nums[1] ]

            assert(p0 ~= p1, "p0 and p1 on Object_Polygon_Tetra are the same point!")
            assert(p0 ~= p2, "p0 and p2 on Object_Polygon_Tetra are the same point!")
            assert(p1 ~= p2, "p1 and p2 on Object_Polygon_Tetra are the same point!")

            -- swap for clockwise
            local v0 = p1.v - p0.v
            local v1 = p2.v - p0.v
            local cross = v1:Cross(v0) -- double check

            local scale = cross:Dot( surf.normal )
            if scale < 0 then
                p1,p2 = p2,p1
            end

            local tri = Triangle()
            self.first_triangle = ll_insert(self.first_triangle, tri)
            tri.is_terminal = true
            tri.is_hidden = false
            tri.surface = self.surfaces[k]

            local edges = tri.edges
            edges[1].start_point = p0
            edges[1].triangle = tri
            edges[1].next = edges[2]
            edges[1].prev = edges[3]
            check_for_opposite(p0, p1, edges[1])

            edges[2].start_point = p1
            edges[2].triangle = tri
            edges[2].next = edges[3]
            edges[2].prev = edges[1]
            check_for_opposite(p1, p2, edges[2])

            edges[3].start_point = p2
            edges[3].triangle = tri
            edges[3].next = edges[1]
            edges[3].prev = edges[2]
            check_for_opposite(p2, p0, edges[3])


            td_tri = td_tri.next
            n = n + 1
        end

    end

    -- don't bother with backside triangles, we don't use them

end

function meta:CheckTriangles()

    local n = 0
    tri = self.first_triangle
    while tri ~= nil do
        n = n + 1
        for _, edge in ipairs(tri.edges) do
            assert(edge.opposite ~= nil, "Edge does not have opposite")
            assert(edge.opposite.opposite == edge, "Edge opposite invalid")
            assert(edge.start_point == edge.opposite.next.start_point, "Edge startpoint invalid")
            assert(edge.prev.start_point ~= edge.opposite.prev.start_point, "Edge startpoint invalid: " .. n)
            assert(edge.triangle ~= edge.opposite.triangle, "Edge opposite on same triangle")
            assert(edge.triangle == tri, "Edge belongs to wrong triangle")
        end

        assert(tri:CalcAreaSize() >= 1e-6, "Degenerate area size")

        tri = tri.next
    end

end

function Object_Polygon_Tetra( template )

    return setmetatable({}, meta):Init( template )

end

-- POLY_POINT
local meta = {}
meta.__index = meta

function meta:Init( vector )
    self.v = vector
    self.l_tetras = nil
    self.tetra_point = nil
    self.compact_index = -1
    self.point_num = -1
    return self
end

function Poly_Point( vector )

    return setmetatable({}, meta):Init( vector )

end

-- TRIANGLE_EDGE
local meta = {}
meta.__index = meta

function meta:Init()
    self.start_point = nil -- Poly_Point
    self.triangle = nil -- Triangle
    self.next = nil -- Triangle_Edge
    self.prev = nil -- Triangle_Edge
    self.behind = nil -- Triangle_Edge
    self.opposite = nil -- Triangle_Edge
    self.checked_in = false
    self.hash_class = 0
    self.concav_flag = 0
    self.tetra_point = nil -- Tetra_Point
    return self
end

function meta:OtherSide()
    if self.triangle.other_side == nil then return nil end
    local edge = self.triangle.other_side.edges[1]
    for i=2,3 do
        if edge.next.start_point == self.start_point then return edge end
        edge = self.triangle.other_side.three_edges[i]
    end
end

function Triangle_Edge()

    return setmetatable({}, meta):Init()

end

-- TRIANGLE
local meta = {}
meta.__index = meta

function meta:Init()
    self.edges = { Triangle_Edge(), Triangle_Edge(), Triangle_Edge() }
    self.next = nil -- Triangle
    self.prev = nil -- Triangle
    self.other_side = nil -- Triangle
    self.pierced = nil -- Triangle
    self.is_terminal = false
    self.is_hidden = false
    self.ledge_group = 0
    self.hesse = Hesse()
    self.surface = nil
    return self
end

function meta:CalcHesse()

    local p0 = self.edges[1].start_point.v
    local p1 = self.edges[1].next.start_point.v
    local p2 = self.edges[1].prev.start_point.v

    assert(p0 ~= p1, "tried to calculate hesse but p0 and p1 are the same")
    assert(p0 ~= p2, "tried to calculate hesse but p0 and p2 are the same")
    assert(p1 ~= p2, "tried to calculate hesse but p1 and p2 are the same")

    print(p0)
    print(p1)
    print(p2)

    self.hesse:CalcHesse(p0, p2, p1)
    self.hesse:Normalize()

end

function meta:CalcAreaSize()

    local norm = Hesse()
    local p0 = self.edges[1].start_point.v
    local p1 = self.edges[1].next.start_point.v
    local p2 = self.edges[1].prev.start_point.v

    norm:CalcHesse(p0, p2, p1)
    return norm:Length() * 0.5

end

function meta:LinkSelf()

    for i=1, 3 do
        self.edges[i].triangle = self;
        self.edges[i].behind = self.edges[i];
        self.edges[i].opposite = self.edges[i]:OtherSide();
    end

end

function meta:__tostring()

    local p0 = self.edges[1].start_point
    local p1 = self.edges[1].next.start_point
    local p2 = self.edges[1].prev.start_point
    return "T:" .. p0.point_num .. ", " .. p1.point_num .. ", " .. p2.point_num

end

function Triangle()

    return setmetatable({}, meta):Init()

end