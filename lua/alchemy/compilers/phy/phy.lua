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
        include("alchemy/common/datawriter.lua"),
    }
})

local quickHull = include("../../common/quickhull/quickhull.lua")
local keytable = include("../../common/keytable.lua")
local utils = include("../../common/utils.lua")

local unit_scale_meters = 0.0254
local unit_scale_meters_inv = 1/unit_scale_meters

PHY_VERSION = 0x100

COLLIDE_POLY = 0
COLLIDE_MOPP = 1

function PHY2HL(x) return x * unit_scale_meters_inv end
function HL2PHY(x) return x * unit_scale_meters end
function Pos2HL(v) return Vector( PHY2HL(v.x), PHY2HL(v.z), -PHY2HL(v.y) ) end
function Pos2PHY(v) return Vector( HL2PHY(v.x), -HL2PHY(v.z), HL2PHY(v.y) ) end
function Dir2HL(v) return Vector( v.x, v.z, -v.y) end
function Dir2PHY(v) return Vector( v.x, -v.z, v.y) end

include("ivp/types.lua")
include("ivp/compact_ledge_gen.lua")
include("ivp/object_polygon_tetra.lua")
include("ivp/point_hash.lua")
include("ivp/surbuild_ledge_soup.lua")
include("ivp/surbuild_pointsoup.lua")
include("ivp/surbuild_polygon_convex.lua")
include("ivp/templates.lua")
include("ivp/triangle_gen.lua")

local function qhash(p)
    local x,y,z = p:Unpack()
    return string.format("%0.4f_%0.4f_%0.4f", x,y,z)
end

local function addToPoints(v, point_hash, newpoints)
    local h = qhash(v)
    if point_hash[h] then return end
    point_hash[h] = true
    newpoints[#newpoints+1] = v
end

function BuildLedgeFromPoints( points )

    local cpoints = {}
    for i, p in ipairs(points) do
        cpoints[i] = Pos2PHY(p)
    end

    local qh = quickHull.new(cpoints) qh:build()
    local tris = qh:collectFaces( false )
    local verts = qh.vertices
    local newpoints = {}
    local point_hash = {}

    local ps_planes = {}
    for i=1, #qh.faces do

        local ppoints = {}
        local face = qh.faces[i]
        local indices = face:collectIndices()
        for j=#indices, 1, -1 do
            local p = verts[ indices[j] ].point
            addToPoints( p, point_hash, newpoints )
            ppoints[#ppoints+1] = p
        end
        ps_planes[#ps_planes+1] = ivp.PS_Plane( face.normal * -1, ppoints )

    end

    --utils.print_table(newpoints, "new points")

    local template = ivp.PlanesToTemplate( newpoints, ps_planes )

    --utils.print_table(template, "template")

    local surface_builder = ivp.SurfaceBuilder_Polygon_Convex( template )
    local ledge = surface_builder:GetCompactLedge()
    if ledge then return ledge end

    local c = ColorRand()
    for _, plane in ipairs(ps_planes) do
        local c = ColorRand()
        local n = #plane.points
        for i=0, n do

            local normal = Dir2HL( plane.normal )
            local v0 = plane.points[(i%n)+1]
            local v1 = plane.points[((i+1)%n)+1]
            debugoverlay.Line(
                Pos2HL(v0) - normal * 10, 
                Pos2HL(v1) - normal * 10, 30, c, true )

        end
    end

end

function BuildSurface( ledges )

    local surf = ivp.SurfaceBuilder_Ledge_Soup()
    for _, ledge in ipairs(ledges) do
        surf:AddLedge( ledge )
    end

    return {
        ledgesoup = surf,
        keys = keytable.new_keytable(),
    }

end

function WriteStudioPHY( v )

    local final_keys = keytable.new_keytable()

    local solids = v.physics_solids

    open_data("studio/phy.dat")
    uint32(16) -- size of header
    uint32(0) -- 'id'
    uint32(#solids) -- solid count
    uint32(v:GetChecksum())

    for _, surf in ipairs(solids) do

        local compiled = surf.ledgesoup:Compile()
        local base = tell_data()
        local size = uint32(0)
        charstr("VPHY", 4)
        uint16(PHY_VERSION)
        uint16(COLLIDE_POLY)
        uint32(compiled.size) -- surfaceSize
        vector32( Vector(0,0,0) ) -- dragAxisAreas
        uint32(0) -- axisMapSize
        compiled:Write(get_data_handle())

        local final_size = tell_data() - base
        push_data(size)
        int32(final_size - 4)
        pop_data()

    end

    local keys = [[
solid {
"index" "0"
"name" "physmodel"
"mass" "50"
"surfaceprop" "flesh"
"damping" "0"
"rotdamping" "0"
"intertia" "1"
"volume" "21000"
}
editparams {
"rootname" ""
"totalmass" "50"
"concave" "0"
}]]

    --final_keys:Write()
    nullstr(keys)
    end_data()

end

return __lib