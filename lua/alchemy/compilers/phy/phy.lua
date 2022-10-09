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
        include("../../common/datawriter.lua"),
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

local function addToPoints(v, point_hash, newpoints)
    local h = utils.hash_vec(v)
    if point_hash[h] then return end
    point_hash[h] = true
    newpoints[#newpoints+1] = v
end

local function ReduceToUniquePoints( points )

    local hash = {}
    local out = {}
    for _, p in ipairs(points) do
        local h = utils.hash_vec(p)
        if hash[h] then continue end
        out[#out+1] = p
        hash[h] = true
    end
    return out

end

function BuildLedgeFromPoints( points )

    points = ReduceToUniquePoints(points)
    for k, p in ipairs(points) do
        points[k] = Pos2PHY(p)
    end

    local qh = quickHull.new(points) qh:build()
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

        local ps_plane = ivp.PS_Plane( face.normal * -1, ppoints )
        ps_plane:Validate()
        ps_planes[#ps_planes+1] = ps_plane

    end

    local c = ColorRand()
    for _, plane in ipairs(ps_planes) do
        local c = ColorRand()
        local n = #plane.points
        for i=0, n do

            local normal = Dir2HL( plane.normal )
            local v0 = plane.points[(i%n)+1]
            local v1 = plane.points[((i+1)%n)+1]
            debugoverlay.Line(
                Pos2HL(v0) - normal * 0.2, 
                Pos2HL(v1) - normal * 0.2, 30, c, true )

        end
    end

    --utils.print_table(newpoints, "new points")

    local template = ivp.PlanesToTemplate( newpoints, ps_planes )

    local surface_builder = ivp.SurfaceBuilder_Polygon_Convex( template )
    local ledge = surface_builder:GetCompactLedge()
    if ledge then return ledge end

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

    local physbones = v.physbones
    local totalmass = 0

    open_data("studio/phy.dat")
    uint32(16) -- size of header
    uint32(0) -- 'id'
    uint32(#physbones) -- solid count
    uint32(v:GetChecksum())

    for k, physbone in ipairs(physbones) do

        local sdata = final_keys:AddSection("solid")
        sdata.index = k - 1
        sdata.name = physbone:GetName()
        sdata.mass = physbone:GetMass()
        sdata.surfaceprop = physbone:GetSurfaceProp()
        sdata.damping = physbone:GetDamping()
        sdata.rotdamping = physbone:GetRotationDamping()
        sdata.inertia = physbone:GetInertia()
        sdata.volume = physbone:GetVolume()

        totalmass = totalmass + physbone:GetMass()

        local compiled = physbone.physics.ledgesoup:Compile()
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

    local eparams = final_keys:AddSection("editparams")
    eparams.rootname = ""
    eparams.totalmass = totalmass
    eparams.concave = ""

    nullstr(final_keys:ToString())
    end_data()

end

return __lib