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

-- TEMPLATE_SURFACE
local meta = {}
meta.__index = meta

function meta:Init( line_count )
    self.normal = Vector(0,0,0)
    self.templ_poly = nil -- TEMPLATE_POLYGON
    self.lines = {}
    self.reverse_line = {}

    for i=1, line_count do
        self.lines[#self.lines+1] = 0
        self.reverse_line[#self.reverse_line+1] = 0
    end

    return self
end

function meta:SetLine(i, line_index, revert)
    self.lines[i] = line_index
    self.reverse_line[i] = revert
end

function Template_Surface( line_count )

    return setmetatable({}, meta):Init( line_count )

end

-- TEMPLATE_POLYGON
local meta = {}
meta.__index = meta

function meta:Init( template )
    self.points = {}
    self.lines = {}
    self.surfaces = {}
    return self
end

function Template_Polygon()

    return setmetatable({}, meta):Init()

end