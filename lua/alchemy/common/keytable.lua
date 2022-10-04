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
        include("utils.lua"),
    }
})

local meta = {}
meta.__index = meta

function meta:__newindex(k, v)

    if k == "__name" then rawset(self, "__name", v) return end
    if k == "__parent" then rawset(self, "__parent", v) return end
    local vt = rawget(self, "values")
    vt[tostring(k)] = tostring(v)

end

function meta:FromString( str )

    local len = #str
    local bIsValue = false
    local bLiteral = false
    local literal = ""
    local active_section = self
    local key = ""
    local value = ""
    local section = ""
    for i=1, len do
        local ch = str[i]
        if ch == "\"" then
            bLiteral = not bLiteral
            if not bLiteral then
                if bIsValue then
                    value = literal
                    active_section[key] = value
                else
                    key = literal
                end
                bIsValue = not bIsValue
                literal = ""
            end
        elseif ch:match("%s") then
            if bLiteral then literal = literal .. ch end
        elseif ch == "{" then
            active_section = active_section:AddSection( section )
            section = ""
        elseif ch == "}" then
            active_section = active_section.__parent
        else
            if bLiteral then literal = literal .. ch else section = section .. ch end
        end
    end

    return self

end

function meta:ToString( indent )

    indent = indent or 0
    local prefix = string.rep(" ", indent)
    local str = ""
    for _, section in ipairs(self.sections) do
        str = str .. prefix .. section.__name .. "\n{\n"
        str = str .. section:ToString(indent+1)
        str = str .. prefix .. "}\n"
    end
    for key, value in pairs(self.values) do
        str = str .. prefix .. string.format([["%s" "%s"]], key, value) .. "\n"
    end

    if indent == 0 then str = str:sub(1,-2) end
    return str

end

function meta:ToTable()

    local t = {}
    for _, section in ipairs(self.sections) do
        t[section.__name] = t[section.__name] or {}
        local st = t[section.__name]
        st[#st+1] = section:ToTable()
    end

    for key, value in pairs(self.values) do
        t[key] = value
    end
    return t

end

function meta:AddSection(name)

    local section = new_keytable()
    section.__name = name
    section.__parent = self
    self.sections[#self.sections+1] = section
    return section

end

function meta:Set(key, value)

    self.values[tostring(key)] = tostring(value)

end

function new_keytable()

    return setmetatable({ sections = {}, values = {} }, meta)

end

function load_keytable()

    return setmetatable({ sections = {}, values = {} }, meta)

end

-- TEST CODE
if CLIENT and false then

    print("KEYTABLE")
    local test = new_keytable()
    local solid = test:AddSection("solid")
    solid.index = 0
    solid.name = "physmodel"
    solid.mass = 50
    solid.surfaceprop = "flesh"
    solid.damping = 0
    solid.rotdamping = 0
    solid.intertia = 1
    solid.volume = 21000

    local solid = test:AddSection("solid")
    solid.index = 0
    solid.name = "physmodel2"
    solid.mass = 100
    solid.surfaceprop = "metal"
    solid.damping = 0
    solid.rotdamping = 0
    solid.intertia = 1
    solid.volume = 21000

    local edit = test:AddSection("editparams")
    edit.rootname = ""
    edit.totalmass = 50
    edit.concave = 0

    print( test:ToString() )

    local loaded = new_keytable():FromString( [[solid{"key" "value" "other,key.test" "other value"} solid {"hello" "true"} ]] )

    print_table(loaded:ToTable(), "keytable")
    print( loaded:ToString() )

end

return __lib