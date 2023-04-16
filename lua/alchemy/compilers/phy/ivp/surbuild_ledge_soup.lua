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
local rshift = bit.rshift
local bor = bit.bor
local bnot = bit.bnot
local band = bit.band
local utils = alchemy.utils

IVP_COMPACT_BOUNDINGBOX_STEP_SIZE = 1.0 / 250.0
P_FLOAT_RES = 1e-6

-- COMPACT SURFACE
local meta = {}
meta.__index = meta

function meta:Init()
    self.mass_center = Vector()
    self.rotation_inertia = Vector(0.1, 0.1, 0.1)
    self.upper_limit_radius = 0
    self.max_factor_surface_deviation = 0 -- 8
    self.byte_size = 0 -- 24
    self.data = 0
    self.offset_ledgetree_root = 0

    self.tmp_nodes = {}
    self.tmp_ledges = {}
    self.tmp_points = {}

    self.root = nil
    return self
end

function meta:SetByteSize( size )
    self.byte_size = size
    self.data = band(self.data, 0x000000FF)
    self.data = bor(self.data, lshift(size, 8))
end

function meta:SetMaxSurfaceDeviation( dev )
    self.max_factor_surface_deviation = dev
    self.data = band(self.data, 0xFFFFFF00)
    self.data = bor(self.data, dev)
end

function meta:Write( stream )

    local base = stream:Tell()

    stream:WriteFloat( self.mass_center.x )
    stream:WriteFloat( self.mass_center.y )
    stream:WriteFloat( self.mass_center.z )
    stream:WriteFloat( self.rotation_inertia.x )
    stream:WriteFloat( self.rotation_inertia.y )
    stream:WriteFloat( self.rotation_inertia.z )
    stream:WriteFloat( self.upper_limit_radius )
    stream:WriteULong( self.data )
    stream:WriteULong( self.offset_ledgetree_root )
    stream:Write("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")

    for _, ledge in ipairs(self.tmp_ledges) do

        --print( ("W: ledge: %x"):format( (stream:Tell() - base) ) )

        --print("W: ledge " .. (stream:Tell() - base) .. " : " .. ledge.tmp_addr .. " (" .. ledge.tmp_addr+ledge.c_point_offset .. ")")
        ledge:Write(stream)
    end

    for _, point in ipairs(self.tmp_points) do

        --print( ("W: point: %x"):format( (stream:Tell() - base) ) )

        local v = point.v
        --print("W: point " .. v.x .. " : " .. v.y .. " : " .. v.z .. " " .. (stream:Tell() - base))
        stream:WriteFloat(v.x)
        stream:WriteFloat(v.y)
        stream:WriteFloat(v.z)
        stream:WriteFloat(0)
    end

    for _, node in ipairs(self.tmp_nodes) do
        local addr = (stream:Tell() - base)
        --print( ("W: node: %x"):format( addr ) )
        --print("W: node " .. addr .. " " .. tostring(node.center) .. " : " .. node.tmp_addr .. " (" .. (node.tmp_addr-addr) .. ")")
        node:Write(stream)
    end

end

function CompactSurface()
    return setmetatable({}, meta):Init()
end

-- LEDGETREE NODE
local meta = {}
meta.__index = meta

function meta:Init()
    self.offset_right_node = 0
    self.offset_compact_ledge = 0
    self.center = Vector()
    self.radius = 0
    self.box_sizes = Vector()
    return self
end

function meta:Write(stream)

    stream:WriteLong( self.offset_right_node )
    stream:WriteLong( self.offset_compact_ledge )
    stream:WriteFloat( self.center.x )
    stream:WriteFloat( self.center.y )
    stream:WriteFloat( self.center.z )
    stream:WriteFloat( self.radius )
    stream:WriteByte( self.box_sizes.x )
    stream:WriteByte( self.box_sizes.y )
    stream:WriteByte( self.box_sizes.z )
    stream:WriteByte( 0 )

end

function CompactLedgeTreeNode()
    return setmetatable({}, meta):Init()
end

-- Ledge soup builder
local meta = {}
meta.__index = meta

function meta:Init()
    self.dragAreaEpsilon = 0.25
    self.buildOuterConvexHull = false
    self.buildDragAxisAreas = false
    self.buildOptimizedTraceTables = false
    self.pForcedOuterHull = nil
    self.ledges = {}
    self.all_spheres = {}
    self.terminal_spheres = {}
    self.extents_min = Vector(math.huge, math.huge, math.huge)
    self.extents_max = Vector(-math.huge, -math.huge, -math.huge)
    self.smallest_radius = math.huge
    self.longest_axis = 0
    self.num_nodes = 0
    self.num_terminal_spheres = 0

    return self
end

function meta:AddLedge( compact_ledge )
    self.ledges[#self.ledges+1] = compact_ledge
end

function meta:LedgesToBoxesAndSpheres()

    local num_ledges = #self.ledges
    self.num_terminal_spheres = num_ledges

    self.spheres_cluster = {}
    for i=1, self.num_terminal_spheres+1 do
        self.spheres_cluster[#self.spheres_cluster+1] = {}
    end
    self.spheres_cluster[1].next = 2

    local n = 2
    for k, compact_ledge in ipairs(self.ledges) do

        assert(compact_ledge.n_triangles > 0)

        local sphere = {}
        self.all_spheres[#self.all_spheres+1] = sphere

        local min, max = compact_ledge:GetBoundingBox()
        sphere.center = (min + max) / 2
        local rad = max - sphere.center
        sphere.radius = rad:Length()

        --print("SPHERE CENTER: " .. tostring(sphere.center))

        utils.v_min(self.extents_min, sphere.center, sphere.radius)
        utils.v_max(self.extents_max, sphere.center, sphere.radius)

        local work = sphere.radius * IVP_COMPACT_BOUNDINGBOX_STEP_SIZE
        sphere.box_sizes = Vector(
           math.floor( (max.x - sphere.center.x) / work ) + 1,
           math.floor( (max.y - sphere.center.y) / work ) + 1,
           math.floor( (max.z - sphere.center.z) / work ) + 1)

        sphere.compact_ledge = compact_ledge
        sphere.child_1 = nil
        sphere.child_2 = nil
        sphere.number = n

        self.spheres_cluster[n].previous = n-1
        self.spheres_cluster[n].next = n+1
        self.spheres_cluster[n].sphere = sphere


        self.smallest_radius = math.min(sphere.radius, self.smallest_radius)
        self.terminal_spheres[#self.terminal_spheres+1] = sphere

        n = n + 1

    end

    self.spheres_cluster[n-1].next = 1

    if #self.ledges > 1 then
        local ext = self.extents_max - self.extents_min
        if ext.x < ext.y then
            if ext.y < ext.z then
                self.longest_axis = 3
            else
                self.longest_axis = 2
            end
        else
            if ext.x < ext.z then
                self.longest_axis = 3
            else
                self.longest_axis = 1
            end
        end
    end

end

function meta:GetTerminalListBoundingBox(terminals)

    local ext_min = Vector(math.huge, math.huge, math.huge)
    local ext_max = Vector(-math.huge, -math.huge, -math.huge)

    if #terminals == 0 then
        ext_min:SetUnpacked(0,0,0)
        ext_max:SetUnpacked(0,0,0)
        return ext_min, ext_max
    end

    for _, sphere in ipairs(terminals) do
        local work = sphere.radius * IVP_COMPACT_BOUNDINGBOX_STEP_SIZE
        local min = sphere.center - sphere.box_sizes * work
        local max = sphere.center + sphere.box_sizes * work
        utils.v_min(ext_min, min)
        utils.v_max(ext_max, max)
    end

    return ext_min, ext_max

end

function meta:ClusterSpheresRecursively(terminals, depth)

    depth = depth or 0

    --print("RECURSE AT: " .. depth)

    if depth > 20 then
        error("MAXXED OUT DEPTH!!!!")
    end

    assert(#terminals > 0)

    if #terminals == 1 then return terminals[1] end

    local ext_min, ext_max = self:GetTerminalListBoundingBox(terminals)
    --print("bounds", ext_min, ext_max)
    local new_center = (ext_min + ext_max) / 2
    local new_radius = (ext_max - new_center):Length()
    local work = new_radius * IVP_COMPACT_BOUNDINGBOX_STEP_SIZE

    local new_sphere = {
        number = 0,
        radius = new_radius,
        center = new_center,
        compact_ledge = nil,
    }

    --PrintTable(new_sphere, 2)

    new_sphere.box_sizes = Vector(
        math.floor( (ext_max.x - new_center.x) / work ) + 1,
        math.floor( (ext_max.y - new_center.y) / work ) + 1,
        math.floor( (ext_max.z - new_center.z) / work ) + 1)

    if #terminals == 2 then
        new_sphere.child_1 = self:ClusterSpheresRecursively( { terminals[1] }, depth+1 )
        new_sphere.child_2 = self:ClusterSpheresRecursively( { terminals[2] }, depth+1 )
        assert(new_sphere.child_1 ~= nil)
        assert(new_sphere.child_2 ~= nil)
        self.num_nodes = self.num_nodes + 1
        return new_sphere
    end

    local left_terminals = {{}, {}, {}}
    local right_terminals = {{}, {}, {}}
    local bounding_difference = {}

    -- Split on each axis
    local exts = ext_max - ext_min
    local axes_order = util.v_orderaxes( exts )
    for _, axis in ipairs(axes_order) do
        local left, right = left_terminals[axis], right_terminals[axis]
        local median = 0
        for _, sphere in ipairs(terminals) do
            median = median + sphere.center[axis]
        end
        median = median / #terminals
       
        local toggle = true

        for k, terminal_sphere in ipairs(terminals) do

            if terminal_sphere.center[axis] < median - P_FLOAT_RES then
                left[#left+1] = terminal_sphere
            elseif terminal_sphere.center[axis] > median + P_FLOAT_RES then
                right[#right+1] = terminal_sphere
            else
                local reference = nil
                if k == #terminals then
                    reference = terminals[k-1]
                else
                    reference = terminals[k+1]
                end

                if reference.center[axis] < median - P_FLOAT_RES then
                    right[#right+1] = terminal_sphere
                    continue
                end

                if reference.center[axis] > median + P_FLOAT_RES then
                    left[#left+1] = terminal_sphere
                    continue
                end

                -- reference on median
                if #left == 0 then left[1] = terminal_sphere continue end
                if #right == 0 then right[1] = terminal_sphere continue end

                if toggle then
                    left[#left+1] = terminal_sphere
                else
                    right[#right+1] = terminal_sphere
                end

                toggle = not toggle

            end

        end

        local left_min, left_max = self:GetTerminalListBoundingBox(left)
        local right_min, right_max = self:GetTerminalListBoundingBox(right)
        local left_ext = util.v_abs(left_max - left_min)
        local right_ext = util.v_abs(right_max - right_min)
        local left_vol = left_ext.x * left_ext.y * left_ext.z
        local right_vol = right_ext.x * right_ext.y * right_ext.z
        bounding_difference[axis] = left_vol + right_vol

    end

    -- Find the best split
    local chosen = 0
    local max_diff = math.huge
    for i=1, 3 do
        if bounding_difference[i] < max_diff then
            if #left_terminals ~= 0 and #right_terminals ~= 0 then
                chosen = i
            end
            max_diff = bounding_difference[i]
        end
    end

    new_sphere.child_1 = self:ClusterSpheresRecursively( left_terminals[chosen], depth+1 )
    new_sphere.child_2 = self:ClusterSpheresRecursively( right_terminals[chosen], depth+1 )

    assert(new_sphere.child_1 ~= nil)
    assert(new_sphere.child_2 ~= nil)

    self.num_nodes = self.num_nodes + 1

    return new_sphere

end

function meta:ClusterSpheresTopDown()

    local terminals = {}
    local next_sphere = self.spheres_cluster[1].next
    while next_sphere ~= 1 do
        terminals[#terminals+1] = self.spheres_cluster[next_sphere].sphere
        next_sphere = self.spheres_cluster[next_sphere].next
    end

    --[[for _, term in ipairs(terminals) do
        print("TERMINAL SPHERE: ", term.center, term.radius)
    end]]

    self.num_nodes = self.num_terminal_spheres
    self.spheres_cluster[self.spheres_cluster[1].next].sphere = self:ClusterSpheresRecursively(terminals)

end

local temp = Vector()
local function point_compare_func(p, point)
    temp:Set(p.v)
    temp:Sub(point.v)
    if temp:LengthSqr() < 0.0001 then return true end
    return false
end
--function meta:

function meta:LayoutCompactSurface()

    self.surface = CompactSurface()
    self.surface.tmp_ledges = {}

    local cs_header_size = IVP_Size_Conpact_Surface
    local cs_estimated_ledgelist = 0
    local cs_ledge_tree_size = self.num_nodes * IVP_Size_Compact_Ledge_Tree_Node
    local num_triangles = 0
    local num_ledges = 0
    local num_points = 0
    local ptr = 0
    local lookup = {}

    self.ptr_lookup = lookup
    
    lookup[self.surface] = 0
    ptr = ptr + cs_header_size

    local s = SysTime()

    local old_num_points = 0
    local point_hash = PointHash(point_compare_func)
    for _, sphere in ipairs(self.terminal_spheres) do
        local source = sphere.compact_ledge
        local source_points = source:TakePoints()
        for k, point in ipairs(source_points) do
            local p, idx = point_hash:FindPoint(point)
            --if p ~= nil then print("FOUND", p.v, point.v) end
            if p == nil then
                point.compact_index = point_hash:Len()
                point_hash:AddPoint(point)
                num_points = num_points + 1
            else
                point.compact_index = idx-1
            end
            old_num_points = old_num_points + 1
            --print(point.compact_index)
        end

        for _, v in ipairs(source.tmp_triangles) do
            for i=1, 3 do
                local edge = v.edges[i]
                local ipoint = edge.start_point_index
                local p_in = source_points[ipoint+1]
                local remap = p_in.compact_index
                edge:SetStartPointIndex( remap )
                --print( ipoint, remap )
            end
        end

        num_triangles = num_triangles + source.n_triangles
        num_ledges = num_ledges + 1
        self.surface.tmp_ledges[#self.surface.tmp_ledges+1] = source
    end

    print("  Build point-list took: " .. (SysTime() - s) * 1000 .. "ms " .. old_num_points .. " -> " .. num_points )

    local cs_point_addr = cs_header_size +
        num_triangles * IVP_Size_Compact_Triangle +
        num_ledges * IVP_Size_Compact_Ledge

    local cs_ledgelist_size = 
        num_triangles * IVP_Size_Compact_Triangle +
        num_ledges * IVP_Size_Compact_Ledge +
        num_points * IVP_Size_PolyPoint

    for _, sphere in ipairs(self.terminal_spheres) do
        local source = sphere.compact_ledge
        local ledge_size = source:GetSize()
        --print("LEDGE SIZE: " .. ledge_size)
        source:SetOffsetLedgePoints( cs_point_addr - ptr )
        source.tmp_addr = ptr
        lookup[source] = ptr
        ptr = ptr + IVP_Size_Compact_Ledge
        for _, v in ipairs(source.tmp_triangles) do
            lookup[v] = ptr
            ptr = ptr + 4
            for i=1, 3 do
                lookup[v.edges[i]] = ptr
                ptr = ptr + IVP_Size_Compact_Edge
            end
        end
        --ptr = ptr + ledge_size
        cs_estimated_ledgelist = cs_estimated_ledgelist + ledge_size
    end

    assert(#point_hash.points == num_points)


    ptr = cs_header_size + cs_ledgelist_size
    --print("NODES START AT: " .. ptr)

    local cs_real_size = cs_header_size + cs_ledgelist_size + cs_ledge_tree_size

    self.surface:SetByteSize(cs_real_size)
    self.surface.offset_ledgetree_root = cs_header_size + cs_ledgelist_size
    self.surface.tmp_points = point_hash.points
    self.surface.tmp_nodes = {}
    self.surface.size = cs_real_size

    for k, point in ipairs(self.surface.tmp_points) do
        lookup[point] = cs_point_addr + (k-1) * IVP_Size_PolyPoint
    end

    self.point_addr = cs_point_addr

    for i=1, self.num_nodes do
        local node = CompactLedgeTreeNode()
        node.tmp_addr = ptr
        lookup[node] = ptr
        ptr = ptr + IVP_Size_Compact_Ledge_Tree_Node
        self.surface.tmp_nodes[#self.surface.tmp_nodes+1] = node
    end

    local i_node = 1
    local nodes = self.surface.tmp_nodes
    local function build_tree(node)

        local current_node = nodes[i_node]
        i_node = i_node + 1

        current_node.center:Set( node.center )
        current_node.radius = node.radius
        current_node.box_sizes = node.box_sizes

        if node.child_1 ~= nil then
            
            assert(node.child_2 ~= nil)
            if node.compact_ledge ~= nil then
                print("COMPACT LEDGE HAS CHILDREN?")
                current_node.tmp_compact_ledge = node.compact_ledge
                current_node.offset_compact_ledge = lookup[node.compact_ledge] - lookup[current_node]
                node.compact_ledge.ledgetree_node_offset = lookup[current_node] - lookup[node.compact_ledge]
                node.compact_ledge.has_children_flag = true
            else
                current_node.offset_compact_ledge = 0
            end

            build_tree(node.child_1)
            local right = build_tree(node.child_2)

            current_node.offset_right_node = lookup[right] - lookup[current_node]

        else

            node.compact_ledge.has_children_flag = false

            current_node.tmp_compact_ledge = node.compact_ledge
            current_node.offset_compact_ledge = lookup[node.compact_ledge] - lookup[current_node]
            current_node.offset_right_node = 0

        end

        return current_node

    end

    local s = SysTime()
    local root = self.spheres_cluster[ self.spheres_cluster[1].next ].sphere
    build_tree(root)
    print("  Build node-tree took: " .. (SysTime() - s) * 1000 .. "ms")

    --print("EMIT NODES: " .. (i_node-1))

end

-- Just hacking this for now
function meta:InsertRadius()

    local root = self.spheres_cluster[ self.spheres_cluster[1].next ].sphere
    local center = root.center
    local radius = root.radius

    self.surface.mass_center = center
    self.surface.upper_limit_radius = radius
    self.surface:SetMaxSurfaceDeviation(1 * 250)

end

local function soft_assert(cnd, str)
    if not cnd then print("ASSERT: " .. str) end
end

function meta:Validate()

    local lookup = self.ptr_lookup
    for ledgenum, ledge in ipairs(self.surface.tmp_ledges) do
        assert( bit.band(lookup[ledge], 0xF) == 0, "Invalid ledge address " .. ledgenum .. " " .. lookup[ledge] )
        assert( lookup[ledge] + ledge.c_point_offset == self.point_addr, "Ledge does not index into point-array" )
        assert( ledge.n_triangles == #ledge.tmp_triangles, "Triangle count incorrect" )
        for k, tri in ipairs(ledge.tmp_triangles) do
            local idx_toledge = (lookup[tri] - tri.tri_index * IVP_Size_Compact_Triangle) - IVP_Size_Compact_Ledge
            local idx_off = idx_toledge - lookup[ledge]
            assert( tri.tri_index == k-1, "Triangle with invalid index: " .. tri.tri_index .. " ~= " .. (k-1) .. " on ledge# " .. ledgenum )
            assert( idx_off == 0, "Triangle does not index properly: " .. k .. " on ledge# " .. ledgenum .. " (" .. idx_off .. ")" )
            assert( tri.pierce_index == ledge.tmp_triangles[tri.pierce_index+1].tri_index, "Triangle pierce index invalid" )

            for _, edge in ipairs(tri.edges) do
                local idx_off = lookup[edge] + edge.opposite_index * IVP_Size_Compact_Edge - lookup[edge.opposite]
                assert( bit.band( lookup[edge], 0xFFFFFFF0 ) == lookup[tri], "Edge does not index to its triangle" )
                assert( idx_off == 0, "Edge does not index to opposite: " .. idx_off )
            end

        end
    end

    assert(self.surface.offset_ledgetree_root == lookup[self.surface.tmp_nodes[1]], "Root is not first node.")

    for nodenum, node in ipairs(self.surface.tmp_nodes) do
        if node.offset_compact_ledge ~= 0 then
            assert(lookup[node] + node.offset_compact_ledge == lookup[node.tmp_compact_ledge], "Node does not point to child")
        end
    end

end

function meta:Compile()

    local s = SysTime()
    self:LedgesToBoxesAndSpheres()
    print(" Ledges to box spheres took: " .. (SysTime() - s) * 1000 .. "ms")

    local s = SysTime()
    self:ClusterSpheresTopDown()
    print(" Cluster spheres top-down took: " .. (SysTime() - s) * 1000 .. "ms")

    local s = SysTime()
    self:LayoutCompactSurface()
    print(" Layout compact surface took: " .. (SysTime() - s) * 1000 .. "ms")

    self:InsertRadius()
    self:Validate()

    return self.surface

end

function SurfaceBuilder_Ledge_Soup()

    return setmetatable({}, meta):Init()

end