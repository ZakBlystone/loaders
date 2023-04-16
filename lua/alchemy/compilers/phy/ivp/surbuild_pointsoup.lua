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

module("ivp", package.seeall)

local lshift = bit.lshift
local bor = bit.bor

-- POINTSOUP_PLANE
local meta = {}
meta.__index = meta

function meta:Init( normal, points )
    self.normal = normal
    self.points = points
    return self
end

function meta:Validate()

    local hash = PointHash()
    for _, p in ipairs(self.points) do
        assert(hash:FindPoint(p) == nil, "Duplicate point in PS_Plane: " .. tostring(p))
        hash:AddPoint(p)
    end

end

function PS_Plane( normal, points )

    return setmetatable({}, meta):Init( normal, points )

end

local function GetOffsetFromPointlist( points, point )

    for k, v in ipairs(points) do
        if v == point then return k end
    end
    return 0

end

local function GetOffsetFromLinelist( lines, point1, point2 )

    for k, v in ipairs(lines) do
        if point1 == v[1] and point2 == v[2] then 
            return k, 0
        end
        if point1 == v[2] and point2 == v[1] then 
            return k, 1
        end
    end
    return 0, 0

end

-- Triangle generation really wants these to be counter-clockwise
function GeneratePointSoupPlanes( points, planes )

    local out = {}
    local rm_planes = k
    for _, plane in ipairs(planes) do

        local plane_points = {}
        local center = Vector(0,0,0)
        for _, point in ipairs(points) do

            local d = plane.normal:Dot( point ) + plane.dist
            if math.abs(d) < 0.0001 then
                plane_points[#plane_points+1] = point
                center:Add(point)
            end

        end

        -- plane doesn't define a surface
        if #plane_points < 3 then continue end

        center:Div(#plane_points)

        local farthest = 0
        local fpoint = nil
        for _, p in ipairs(points) do
            local d = p:DistToSqr(center)
            if d > farthest then
                farthest = d
                fpoint = p
            end
        end

        local x = (fpoint - center)
        x:Normalize()
        local y = x:Cross(plane.normal)
        y:Normalize()

        local function pa(point)
            local dx = x:Dot( point - center )
            local dy = y:Dot( point - center )
            return math.atan2(dy, dx) --* 57.3
        end

        table.sort(plane_points, function(a,b)
            return pa(a) > pa(b)
        end)

        --[[for _,v in ipairs(plane_points) do
            debugoverlay.Box(vphys.Pos2HL(v), Vector(-5,-5,-5), Vector(5,5,5), 5.0, Color(255,255,100))
        end]]

        out[#out+1] = PS_Plane( plane.normal, plane_points )

    end

    return out

end

-- Plane contains list of points that lie on plane
function PlanesToTemplate( points, planes )

    local template = Template_Polygon()
    
    for _, point in ipairs( points ) do

        if GetOffsetFromPointlist( template.points, point ) == 0 then
            template.points[#template.points+1] = point
        end

    end

    assert(#template.points < 0x10000) -- for hash to work

    local line_hash = {}
    local lines = {}
    local function hash_key(a, b) return bor(lshift(a, 16),b) end

    --PrintTable(planes)

    for k, plane in ipairs( planes ) do

        local face_vertex_count = #plane.points
        local surf = Template_Surface( face_vertex_count )

        template.surfaces[k] = surf

        for i=1, face_vertex_count do

            local point = plane.points[i]
            local offset_point_1 = GetOffsetFromPointlist(template.points, point)

            if i == face_vertex_count then
                point = plane.points[1]
            else
                point = plane.points[i+1]
            end

            local offset_point_2 = GetOffsetFromPointlist(template.points, point)

            local hash = nil
            if offset_point_2 < offset_point_1 then
                hash = hash_key(offset_point_1, offset_point_2)
            else
                hash = hash_key(offset_point_2, offset_point_1)
            end

            if not line_hash[hash] then
                line_hash[hash] = 1
                lines[#lines+1] = { offset_point_1, offset_point_2 }
            end

        end


    end

    template.lines = lines

    for k, plane in ipairs( planes ) do

        local surf = template.surfaces[k]
        surf.templ_poly = template
        surf.normal:Set( plane.normal )

        local count = #surf.lines
        local offset_points = {}
        for i=1, count do
            offset_points[i] = GetOffsetFromPointlist(template.points, plane.points[i])
        end
        offset_points[count+1] = offset_points[1]

        for i=1, count do
            local k, reverse = GetOffsetFromLinelist(template.lines, offset_points[i], offset_points[i+1])
            surf.lines[i] = k
            surf.reverse_line[i] = ((reverse*-1) + 1) -- confusing, I think this just inverts
        end

    end

    return template

end