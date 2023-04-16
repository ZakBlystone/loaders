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


local utils = alchemy.utils
local meta = {}
meta.__index = meta

local function qhash(p)
    local x,y,z = p:Unpack()
    return string.format("%0.4f_%0.4f_%0.4f", x,y,z)
end

function meta:Init(compare)
    self.compare = compare
    self.points = {}
    self.hash = {}
    return self
end

function meta:AddPoint(point)
    self.points[#self.points+1] = point
    self.hash[utils.hash_vec(point.v or point)] = #self.points
end

function meta:PointToIndex(point)
    --[[for k, p in ipairs(self.points) do
        if self.compare(p, point) then return k end
    end]]
    return self.hash[utils.hash_vec(point.v or point)] or -1
    --return -1
end

function meta:RemovePoint(p)
    local idx = self:PointToIndex(p)
    if idx ~= -1 then table.remove(self.points, idx) end
end

function meta:FindPoint(p)
    local idx = self:PointToIndex(p)
    if idx ~= -1 then return self.points[idx], idx end
    return nil
end

function meta:Len()
    return #self.points
end

function PointHash(compare)

    return setmetatable({}, meta):Init(compare)

end