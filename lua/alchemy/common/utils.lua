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
local __lib = alchemy.MakeLib()

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
    Color(182,182,182),
}

local function recursive_print_table(t, depth, max, exclude, parent, visited)

    local vcolor = Color(255,255,255)
    local dcolor = colors[ 1 + (depth-1) % #colors ]
    local prefix = string.rep("  ", depth)
    local keys = {}
    for k, v in pairs(t) do keys[#keys+1] = k end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local keystr = tostring(k)
        local value = t[k]
        local valuestr = tostring(value)
        if type(value) == "string" then valuestr = "'" .. valuestr .. "'" end
        if type(value) ~= "table" then
            if type(k) == "number" then
                MsgC(dcolor, prefix .. "[" .. keystr .. "]: ")
                MsgC(vcolor, valuestr .. "\n")
            else
                MsgC(dcolor, prefix .. keystr .. " = ")
                MsgC(vcolor, valuestr .. "\n")
            end
        else
            local mt = getmetatable(value)
            if mt and mt.__tostring then
                MsgC(dcolor, prefix .. keystr .. " = ")
                MsgC(vcolor, valuestr .. "\n")
            elseif depth < max then
                if visited[value] then
                    MsgC(dcolor, prefix .. keystr .. ": [...]\n")
                elseif not exclude[k] then
                    local head = keystr
                    if type(k) == "number" then
                        head = "->" .. parent .. "[" .. k .. "]"
                    else
                        MsgC(dcolor, prefix .. head .. ": \n")
                    end
                    visited[value] = true
                    recursive_print_table(value, depth+1, max, exclude, k, visited)
                else
                    MsgC(dcolor, prefix .. keystr .. ": ...\n")
                end
            end
        end
    end

end

function print_table(t, name, exclude, maxDepth)

    if exclude then
        if type(exclude) == "string" then
            exclude = {}
            exclude[exclude] = true
        else
            for k,v in ipairs(exclude) do
                exclude[k] = nil
                exclude[v] = true
            end
        end
    else
        exclude = {}
    end

    local visited = {}
    print((name or "table") .. ": ")
    recursive_print_table(t, 1, maxDepth or 100, exclude, (name or "table"), visited)

end

return __lib