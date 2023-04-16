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

local function recursive_print_table(t, depth, maxDepth, maxEntries, exclude, parent, visited)

    local vcolor = Color(255,255,255)
    local dcolor = colors[ 1 + (depth-1) % #colors ]
    local prefix = string.rep("  ", depth)
    local keys = {}
    local rmaxEntries = maxEntries
    for k, v in pairs(t) do keys[#keys+1] = k end
    table.sort(keys)

    for _, k in ipairs(keys) do
        if maxEntries == 0 then break end
        local keystr = tostring(k)
        local value = t[k]
        local valuestr = tostring(value)
        if type(value) == "string" then valuestr = "'" .. valuestr .. "'" end
        if type(value) ~= "table" then
            if type(k) == "number" then
                MsgC(dcolor, prefix .. "[" .. keystr .. "]: ")
                MsgC(vcolor, valuestr .. "\n")
                maxEntries = maxEntries - 1
            else
                MsgC(dcolor, prefix .. keystr .. " = ")
                MsgC(vcolor, valuestr .. "\n")
            end
        else
            local mt = getmetatable(value)
            if mt and mt.__tostring then
                MsgC(dcolor, prefix .. keystr .. " = ")
                MsgC(vcolor, valuestr .. "\n")
            else
                if visited[value] then
                    MsgC(dcolor, prefix .. keystr .. ": [...]\n")
                elseif not exclude[k] then
                    local head = keystr
                    visited[value] = true
                    if depth < maxDepth or maxDepth == -1 then
                        if type(k) == "number" then
                            head = "->" .. parent .. "[" .. k .. "]:"
                            maxEntries = maxEntries - 1
                            MsgC(vcolor, prefix .. head .. "\n")
                        else
                            MsgC(dcolor, prefix .. head .. ": \n")
                        end
                        recursive_print_table(value, depth+1, maxDepth, rmaxEntries, exclude, k, visited)
                    else
                        MsgC(dcolor, prefix .. head .. ": (" .. #value .. ")\n")
                    end
                else
                    MsgC(dcolor, prefix .. keystr .. ": ...\n")
                end
            end
        end
    end

end

function print_table(t, name, exclude, maxDepth, maxEntries)

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
    recursive_print_table(t, 1, maxDepth or -1, maxEntries or -1, exclude, (name or "table"), visited)

end

function ll_insert(first, elem)
	elem.next = first
	if first ~= nil then
		first.prev = elem
	end
	elem.prev = nil
	first = elem
	return first
end

function ll_remove(first, elem)
	local e, h = elem, elem.prev
	if h ~= nil then
		h.next = e.next
	else
		first = e.next
	end
	h = e.next
	if h ~= nil then
		h.prev = e.prev
	end
	e.next = nil
	return first
end

local min = math.min
function v_min(vec, test, pad)
    pad = pad or 0
    local x0,y0,z0 = vec:Unpack()
    local x1,y1,z1 = test:Unpack()

    x0 = min(x0, x1-pad)
    y0 = min(y0, y1-pad)
    z0 = min(z0, z1-pad)
    vec:SetUnpacked(x0,y0,z0)
end

local max = math.max
function v_max(vec, test, pad)
    pad = pad or 0
    local x0,y0,z0 = vec:Unpack()
    local x1,y1,z1 = test:Unpack()

    x0 = max(x0, x1+pad)
    y0 = max(y0, y1+pad)
    z0 = max(z0, z1+pad)
    vec:SetUnpacked(x0,y0,z0)
end

local str_find = string.find
local str_sub = string.sub
function str_lines(str)
    local setinel = 0
    return function()
        local k, b = str_find(str, "\n", setinel+1)
        if not k then return end
        b, setinel = setinel, k
        return str_sub(str, b+1, k-1)
    end
end

function compute_center(points, key)

    local center = Vector()
    local add = center.Add
    for _,v in ipairs(points) do
        local p = key and v[key] or v
        add(center, p)
    end
    center:Div(#points)
    return center

end

-- Converts a GUID from binary to a printable string
function guid_to_string( guid, raw )

	local fmt = nil
	if raw then
		fmt = "%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X"
	else
		fmt = "{%0.2X%0.2X%0.2X%0.2X-%0.2X%0.2X%0.2X%0.2X-%0.2X%0.2X%0.2X%0.2X-%0.2X%0.2X%0.2X%0.2X}"
	end
	return string.format(fmt,
		guid[1]:byte(),
		guid[2]:byte(),
		guid[3]:byte(),
		guid[4]:byte(),
		guid[5]:byte(),
		guid[6]:byte(),
		guid[7]:byte(),
		guid[8]:byte(),
		guid[9]:byte(),
		guid[10]:byte(),
		guid[11]:byte(),
		guid[12]:byte(),
		guid[13]:byte(),
		guid[14]:byte(),
		guid[15]:byte(),
		guid[16]:byte())

end

-- Generates a new globally unique ID
function new_guid()

	local d,b,g,m=os.date"*t",function(x,y)return x and y or 0 end,system,bit
	local r,n,s,u,x,y=function(x,y)return m.band(m.rshift(x,y or 0),0xFF)end,
	math.random(2^32-1),_G.__guidsalt or b(CLIENT,2^31),os.clock()*1000,
	d.min*1024+d.hour*32+d.day,d.year*16+d.month;_G.__guidsalt=s+1;return
	string.char(r(x),r(x,8),r(y),r(y,8),r(n,24),r(n,16),r(n,8),r(n),r(s,24),r(s,16),
	r(s,8),r(s),r(u,16),r(u,8),r(u),d.sec*4+b(g.IsWindows(),2)+b(g.IsLinux(),1))

end

local rshift = bit.rshift
local frexp, ldexp, floor, abs = math.frexp, math.ldexp, math.floor, math.abs
local strchar = string.char
function hash_float(v)

    local fr,exp = frexp(abs(v))
    fr = floor(ldexp(fr, 24))
    exp = exp + 126
    if v == 0.0 then fr,exp = 0,0 end
    return strchar(fr%256, rshift(fr,8)%256, (exp%2)*128+rshift(fr,16)%128, (v<0 and 128 or 0)+rshift(exp,1))

end

local __vmeta = FindMetaTable("Vector")
local __vunpack = __vmeta.Unpack
local __vpack = __vmeta.SetUnpacked
function hash_vec(v)

    local x,y,z = __vunpack(v)
    local frx,expx = frexp(abs(x)) expx,frx = expx + 126, floor(ldexp(frx, 24))
    local fry,expy = frexp(abs(y)) expy,fry = expy + 126, floor(ldexp(fry, 24))
    local frz,expz = frexp(abs(z)) expz,frz = expz + 126, floor(ldexp(frz, 24))
    if x == 0.0 then frx,expx = 0,0 end
    if y == 0.0 then fry,expy = 0,0 end
    if z == 0.0 then frz,expz = 0,0 end
    return strchar(
        frx%256, rshift(frx,8)%256, (expx%2)*128+rshift(frx,16)%128, (x<0 and 128 or 0)+rshift(expx,1),
        fry%256, rshift(fry,8)%256, (expy%2)*128+rshift(fry,16)%128, (y<0 and 128 or 0)+rshift(expy,1),
        frz%256, rshift(frz,8)%256, (expz%2)*128+rshift(frz,16)%128, (z<0 and 128 or 0)+rshift(expz,1)
    )

end

-- truncate double to float
function snap_float(f)

    local fr,exp = frexp(abs(f))
    local s = f<0 and -1 or 1
    local sn = floor(ldexp(fr, 24))
    local k = ldexp(ldexp(sn, -23) * s, exp-1)
    return k

end

-- round double to nearest float
function round_float(f)

    local fr,exp = frexp(abs(f))
    local s = f<0 and -1 or 1
    local sn = floor(ldexp(fr, 24))
    local k = ldexp(ldexp(sn, -23) * s, exp-1)
    local k1 = ldexp(ldexp(sn+1, -23) * s, exp-1)
    local d0 = abs(f-k)
    local d1 = abs(f-k1)
    if d0 < d1 then return k else return k1 end

end

-- iterate over combinations in array
function combinations(v)

    local n,i,j=#v,1,1
    return function()
        j = j + 1
        if j == n+1 then i,j = i+1,i+2 end
        if i < n then return i,j end
    end

end

-- weld elements in an array based on a condition
function array_weld(v, cond)

    for i,j in combinations(v) do
        if cond( v[i], v[j] ) then
            v[i] = v[j]
        end
    end

end

return __lib