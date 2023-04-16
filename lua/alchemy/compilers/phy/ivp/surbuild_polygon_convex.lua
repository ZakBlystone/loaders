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

local meta = {}
meta.__index = meta

function meta:Init( template )
    self.point_hash = {}
    self.tetras = Object_Polygon_Tetra( template )
    self:InitSurfaceManagerPolygon()
    return self
end

function meta:GetCompactLedge()
    return self.compact_ledge
end

function meta:InitSurfaceManagerPolygon()

    self.tetras:MakeTriangles()

    local triangles = {}
    local tri = self.tetras.first_triangle
    while tri ~= nil do
        tri:CalcHesse()
        tri = tri.next
    end

    self.tetras:InsertPierceInfo()
    self.tetras:CheckTriangles()

    tri = self.tetras.first_triangle
    while tri ~= nil do
        triangles[#triangles+1] = tri
        tri = tri.next
    end

    local gen = Compact_Ledge_Generator()
    gen:Prepare( triangles )
    
    local c_ledge = gen:Generate()
    self.compact_ledge = c_ledge

    return gen

end

function SurfaceBuilder_Polygon_Convex( template )

    return setmetatable({}, meta):Init(template)

end