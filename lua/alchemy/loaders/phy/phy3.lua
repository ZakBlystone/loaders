--[[
This file is a part of the Loaders repository:
https://github.com/ZakBlystone/loaders

PHY3: source-engine vcollide parser:
loads a vcollide binary input and converts it into readable data.

Usage:
phy3.LoadVCollideString( data, solidCount )
returns an object containing raw data for the requested vcollide data

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
        alchemy.keytable,
    }
})

alchemy.InstallDataReader(false, __lib)

COLLIDE_POLY = 0
COLLIDE_MOPP = 1

local unit_scale_meters = 0.0254
local unit_scale_meters_inv = 1/unit_scale_meters

function PHY2HL(x) return x * unit_scale_meters_inv end
function Pos2HL(v) return Vector( PHY2HL(v.x), PHY2HL(v.z), -PHY2HL(v.y) ) end
function Dir2HL(v) return Vector( v.x, v.z, -v.y) end

local str_byte = string.byte
local str_sub = string.sub
local str_find = string.find
local str_char = string.char
local lshift, rshift, band, bor, bnot = bit.lshift, bit.rshift, bit.band, bit.bor, bit.bnot

local m_solid = {}
m_solid.__index = m_solid

local CompactLedgeSize = 16
local function CompactLedge()

    return {
        c_point_offset = int32(),
        ledgetree_node_offset = int32(),
        data = uint32(),
        n_triangles = int16(),
        unknown = int16(),
    }

end

local CompactLedgeTreeNodeSize = 28
local function CompactLedgeTreeNode()

    return {
        offset_right_node = int32(),
        offset_compact_ledge = int32(),
        center = vector32(),
        radius = float32(),
        box_sizes = { uint8(), uint8(), uint8() },
        pad = uint8(),
    }

end

local CompactEdgeSize = 4
local CompactTriangleSize = 16
local function CompactTriangle()

    return {
        indices = uint32(), --tri_index:12, pierce_index:12, material_index:7, is_virtual:1
        edges = array_of(uint32, 3),
    }

end

local function CompactSurfaceHeader()

    return {
        surfaceSize = int32(),
        dragAxisAreas = vector32(),
        axisMapSize = int32(),
    }

end

local CompactPolyPointSize = 16
local CompactSurfaceSize = 48
local function CompactSurface()

    return {
        mass_center = vector32(), --12
        rotation_inertia = vector32(), --12
        upper_limit_radius = float32(), --4
        size_and_max_surface_deviation = int32(), --4
        offset_ledgetree_root = int32(), --4
        dummy = array_of(int32, 3), --12
    }

end

local function LoadCompactLedge( ptr )

    local ledge = CompactLedge()
    ledge.has_children_flag = band( ledge.data, 0x00000003 ) ~= 0
    ledge.is_compact_flag = rshift( band( ledge.data, 0x0000000C ), 2 ) ~= 0
    ledge.size = rshift( band( ledge.data, 0xFFFFFF00 ), 8 ) * 16
    ledge.num_points = (ledge.size / 16) - ledge.n_triangles - 1
    ledge.triangles = {}
    ledge.edge_lookup = {}

    assert(ledge.is_compact_flag, "Ledges are expected to be compact")

    if not ledge.has_childen_flag then
        ledge.client_data = ledge.ledgetree_node_offset
        ledge.ledgetree_node_offset = nil
        ledge.is_terminal = true
    else
        ledge.is_terminal = false
    end

    seek_data( ptr + CompactLedgeSize )

    local tri_base = tell_data()
    for i=1, ledge.n_triangles do

        local edge_base = tell_data() - tri_base
        local tri = CompactTriangle()
        tri.tri_index = band( tri.indices, 0x00000FFF )
        tri.pierce_index = rshift( band( tri.indices, 0x00FFF000 ), 12 )
        tri.material_index = rshift( band( tri.indices, 0x7F000000 ), 24 )
        tri.is_virtual = band( tri.indices, 0x80000000 ) ~= 0
        tri.indices = nil

        for j=1, 3 do

            local edge = {}
            local indices = tri.edges[j]
            edge.addr = edge_base
            edge.start = band( indices, 0x0000FFFF )
            edge.opposite = rshift( band( indices, 0x7FFF0000 ), 16 )

            if band( edge.opposite, 0x4000 ) ~= 0 then
                edge.opposite = -(0x8000 - edge.opposite)
            end

            edge.opposite = edge.addr + edge.opposite * CompactEdgeSize
            edge.is_virtual = band( indices, 0x80000000 ) ~= 0
            edge.indices = nil
            edge_base = edge_base + CompactEdgeSize
            ledge.edge_lookup[edge.addr] = edge
            tri.edges[j] = edge

        end

        ledge.triangles[#ledge.triangles+1] = tri

    end

    return ledge

end

local function LoadPhysCollideCompactSurface( header, index )

    local out_surface = {}
    local base = tell_data()
    local ptr = base
    local size = header.surfaceSize
    local surf = CompactSurface()

    local num_ledges = 0
    local num_tris = 0
    local num_nodes = 0

    surf.max_factor_surface_deviation = band( surf.size_and_max_surface_deviation, 0xFF ) * (1/250)
    surf.byte_size = rshift( band( surf.size_and_max_surface_deviation, 0xFFFFFF00 ), 8 )
    surf.size_and_max_surface_deviation = nil
    surf.radius_deviation = surf.max_factor_surface_deviation * surf.upper_limit_radius

    for k,v in pairs(surf) do
        out_surface[k] = v
    end

    local function WalkTo( ptr, is_node )

        seek_data( ptr )
        if is_node then

            local out_node = {}

            num_nodes = num_nodes + 1

            local node = CompactLedgeTreeNode()
            if node.offset_compact_ledge ~= 0 then
                out_node.leaf = WalkTo( ptr + node.offset_compact_ledge, false )
            end
            if node.offset_right_node ~= 0 then
                out_node.left = WalkTo( ptr + CompactLedgeTreeNodeSize, true )
                out_node.right = WalkTo( ptr + node.offset_right_node, true )
            end
            return out_node

        else

            local ledge = LoadCompactLedge( ptr )
            num_ledges = num_ledges + 1
            num_tris = num_tris + ledge.n_triangles
            return ledge

        end

    end

    local root = WalkTo( ptr + surf.offset_ledgetree_root, true )
    out_surface.root = root
    out_surface.points = {}

    setmetatable(out_surface, m_solid)

    local point_addr = base + CompactSurfaceSize +
    num_ledges * CompactLedgeSize +
    num_tris * CompactTriangleSize

    local point_bytes = (surf.byte_size - (point_addr - base)) - 
    num_nodes * CompactLedgeTreeNodeSize

    local num_points = point_bytes / CompactPolyPointSize

    seek_data( point_addr )

    for i=1, num_points do
        local point, w = vector32(), float32()
        out_surface.points[#out_surface.points+1] = Pos2HL(point)
    end

    return out_surface

end

local function LoadPhysCollide( size, index )

    local header = {
        ident = table.concat(array_of(char, 4)),
        version = int16(),
        modelType = int16(),
    }

    if header.ident == "VPHY" then
        assert( header.version == 0x100, "Invalid version in PhysCollide" )
        if header.modelType == COLLIDE_POLY then
            local header = CompactSurfaceHeader()
            return LoadPhysCollideCompactSurface( header, index )
        elseif header.modelType == COLLIDE_MOPP then
            print("MOPP Collision type not supported [" .. index .. "], skipping")
        else
            assert(false, "Invalid modelType: " .. header.modelType)
        end

    else
        assert(false, "Unsupported data in PhysCollide")
    end

end

local function CopyDataIntoSolids( data, solids )

    for _,v in ipairs(data.solid) do

        local idx = v.index
        local solid = solids[idx+1]
        assert(solid, "Solid not found for index: " .. tostring(idx))

        solid.data = v

    end

end

function LoadVCollideString( data, solidCount )

    begin_data( data )

    local solids = {}
    for i=1, solidCount do

        local size = int32()
        local nextaddr = tell_data() + size
        solids[#solids+1] = LoadPhysCollide( size, i )

        seek_data( nextaddr )

    end

    local remain = get_data_size() - tell_data()
    local key_data = charstr(remain)
    local data = new_keytable():FromString(key_data):ToTable()

    CopyDataIntoSolids(data, solids)

    end_data()

    return {
        solids = solids,
        data = data,
    }

end

function LoadVCollideFile( filename, path )

    open_data(filename, path)
    local header = {
        size = int32(),
        id = int32(),
        solidCount = int32(),
        checkSum = int32(),
    }

    local solids = {}
    for i=1, header.solidCount do

        local size = int32()
        local nextaddr = tell_data() + size
        solids[#solids+1] = LoadPhysCollide( size, i )

        seek_data( nextaddr )

    end

    local remain = get_data_size() - tell_data()
    local key_data = charstr(remain)
    local data = new_keytable():FromString(key_data):ToTable()

    CopyDataIntoSolids(data, solids)

    end_data()

    return {
        solids = solids,
        data = data,
    }

end

if SERVER then return end

vcollide_mat = CreateMaterial( "vcollide_test", "UnLitGeneric", {
    ["$basetexture"] = "color/white",
    ["$model"] = 1,
    ["$translucent"] = 1,
    ["$ignorez"] = 0,
    ["$vertexcolor"] = 1,
    ["$vertexalpha"] = 1,
})

local mesh_begin = mesh.Begin
local mesh_end = mesh.End
local mesh_position = mesh.Position
local mesh_color = mesh.Color
local mesh_advance = mesh.AdvanceVertex
local render_num = 0
local colors = {
    Color(218,65,65),
    Color(117,212,53),
    Color(24,206,206),
    Color(221,207,76),
    Color(225,0,245),
    Color(133,51,136),
    Color(173,250,243),
    Color(190,255,13),
    Color(214,173,97),
    Color(116,158,155),
    Color(173,102,102),
    Color(167,102,173),
    Color(42,136,190),
}

function DrawCompactLedge( ledge, points )

    points = ledge.points or points
    local c = colors[ 1 + (render_num-1) % #colors ]
    render_num = render_num + 1
     
    local ok = true
    mesh_begin( MATERIAL_TRIANGLES, #ledge.triangles )

    local b,e = pcall( function()

        for _, tri in ipairs(ledge.triangles) do

            for i=#tri.edges, 1, -1 do
                
                local p = points[tri.edges[i].start+1]
                if p then

                    mesh_position(p) 
                    mesh_color(c.r,c.g,c.b,c.a) 
                    mesh_advance()

                else

                    ok = false

                end

            end
        
        end

    end)

    mesh_end()
    if not b then print(e) end

end

function DrawVCollide( vcollide )

    local num_ledges = 0
    local points = nil

    local function DrawNode( node )

        if node.leaf then DrawCompactLedge( node.leaf, points ) end
        if node.left then DrawNode( node.left ) end
        if node.right then DrawNode( node.right ) end

    end

    render.SetMaterial(vcollide_mat)
    render.OverrideDepthEnable(true, true)

    for k,solid in ipairs(vcollide.solids) do
        --if k == 1 then continue end
        points = solid.points
        DrawNode( solid.root )
    end

    render.OverrideDepthEnable(false, false)

end

local function DrawNode( node, points )

    if node.leaf then DrawCompactLedge( node.leaf, points ) end
    if node.left then DrawNode( node.left, points ) end
    if node.right then DrawNode( node.right, points ) end

end

function m_solid:Render(i)

    i = i or 0
    render_num = i

    render.SetMaterial(vcollide_mat)
    render.OverrideDepthEnable(true, true)

    if self.root.left and self.root.right then
        DrawNode( self.root.left, self.points )
        DrawNode( self.root.right, self.points )
    else
        DrawNode( self.root, self.points )
    end

    render.OverrideDepthEnable(false, false)

end

return __lib