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
        include("qmath.lua"),
    }
})

local str_byte = string.byte
local str_sub = string.sub
local str_find = string.find
local str_char = string.char
local lshift, rshift, band, bor, bnot = bit.lshift, bit.rshift, bit.band, bit.bor, bit.bnot
local m_ptr = 1
local m_data = nil
local m_stack = nil
local m_coverage = nil
local m_size = 0
local m_active_span = nil
local m_array_spans = {}
local m_vis = {}
local m_bigendian = false

function get_ptr() return m_ptr end
function get_data() return m_data end
function get_data_size() return m_size end
function get_coverage_vis() return m_vis end

function set_big_endian(b) m_bigendian = b end

function coverage_data( start, stop )
    for i=start, stop do m_coverage[i] = true end
end

function begin_data( data )

    m_data, m_ptr, m_stack, m_coverage = data, 1, {}, {}

end

function open_data( filename, path )

    local f = file.Open(filename, "rb", path or "GAME")
    local size = f:Size()
    local data = f:Read(size)
    m_size = size
    m_array_spans = {}
    f:Close()
    print("OPEN: '" .. filename .. "' " .. size .. " bytes")
    m_data, m_ptr, m_stack, m_coverage = data, 1, {}, {}

end

local function printable(b)
    if b >= 32 and b <= 125 then return string.char(b) else return "." end
end

function dump_data( first, last )

    local c0 = Color(160, 160, 160)
    local c1 = Color(100, 230, 250)
    local c2 = Color(200, 130, 150)
    local row = "0x%0.4x: "
    local col = "%0.2x "
    local newline = "\n"
    local separator = ": "
    local separator2 = " : "

    local num = last-first
    local rnum = num
    if num % 16 ~= 0 then
        num = num + (16 - num % 16)
    end

    if name then MsgC( color_white, name .. ":\n" ) end

    for r = 0, math.floor(num / 16)-1 do
        local offset = first + r*16
        MsgC( c0, row:format( offset ) )

        for c = 0, math.min(rnum-1, 15) do

            local b = str_byte(m_data[offset+c])
            if c == 8 then MsgC(c0, separator) end
            MsgC( b and c1 or c2, b and col:format( str_byte(m_data[offset+c]) or 0 ) or "-- " )

        end

        MsgC( c0, "| " )

        for c = 0, math.min(rnum-1, 15) do

            local b = str_byte(m_data[offset+c])
            if c == 8 then MsgC(c0, separator2) end
            MsgC( c1, b and printable( str_byte(m_data[offset+c]) or 0 ) or " " )

        end

        MsgC(c0, newline)
        rnum = rnum - 16

    end

end

function end_data()

    local spans = {}
    local span = nil
    for i=1, m_size do
        if not m_coverage[i] then
            if span == nil then span = i end
        else
            if span ~= nil then 
                spans[#spans+1] = {span, i}
                span = nil
            end
        end
    end

    m_vis.array_spans = m_array_spans
    m_vis.size = m_size
    m_vis.ready = true

    m_data = nil

end

function seek_data( pos )
    m_ptr = pos + 1
end

function tell_data()
    return m_ptr - 1
end

function push_data(addr)
    m_stack[#m_stack+1] = tell_data()
    seek_data(addr)
end

function pop_data()
    local n = #m_stack
    seek_data(m_stack[n])
    m_stack[n] = nil
end

function uint32()
    coverage_data(m_ptr, m_ptr+4)
    local a,b,c,d = str_byte(m_data, m_ptr, m_ptr + 4)
    if m_bigendian then d,c,b,a = a,b,c,d end
    m_ptr = m_ptr + 4
    local n = bor( lshift(d,24), lshift(c,16), lshift(b, 8), a )
    if n < 0 then n = (0x1p32) - 1 - bnot(n) end
    return n
end

function uint16()
    coverage_data(m_ptr, m_ptr+2)
    local a,b = str_byte(m_data, m_ptr, m_ptr + 2)
    if m_bigendian then b,a = a,b end
    m_ptr = m_ptr + 2
    return bor( lshift(b, 8), a )
end

function uint8()
    coverage_data(m_ptr, m_ptr)
    local a = str_byte(m_data, m_ptr, m_ptr)
    m_ptr = m_ptr + 1
    return a
end

function int32()
    coverage_data(m_ptr, m_ptr+4)
    local a,b,c,d = str_byte(m_data, m_ptr, m_ptr + 4)
    if m_bigendian then d,c,b,a = a,b,c,d end
    m_ptr = m_ptr + 4
    local n = bor( lshift(d,24), lshift(c,16), lshift(b, 8), a )
    return n
end

function int16()
    coverage_data(m_ptr, m_ptr+2)
    local a,b = str_byte(m_data, m_ptr, m_ptr + 2)
    if m_bigendian then b,a = a,b end
    m_ptr = m_ptr + 2
    local n = bor( lshift(b, 8), a )
    if band( b, 0x80 ) ~= 0 then n = -(0x1p16) + n end
    return n
end

function int8()
    coverage_data(m_ptr, m_ptr)
    local a = str_byte(m_data, m_ptr, m_ptr)
    m_ptr = m_ptr + 1
    if band( a, 0x80 ) ~= 0 then a = -(0x100) + a end
    return a
end

function char()
    coverage_data(m_ptr, m_ptr)
    local a = str_sub(m_data, m_ptr, m_ptr)
    m_ptr = m_ptr + 1
    return a
end

function charstr(n)
    coverage_data(m_ptr, m_ptr + n)
    local a = str_sub(m_data, m_ptr, m_ptr + n - 1)
    m_ptr = m_ptr + n
    return a
end

function float16()
    local v = uint16()
    local mantissa = band( v, 0x3FF )
    local exp = band( rshift(v, 10), 0x1F )
    local sgn = band( rshift(v, 15), 0x01 ) and -1 or 1

    mantissa = lshift(mantissa, 23-10)
    local _exp = (exp - 15) * (exp ~= 0 and 1 or 0)
    return math.ldexp( (math.ldexp(mantissa, -23) + 1) * sgn, _exp )
end

function float32()
    coverage_data(m_ptr, m_ptr + 4)
    local a,b,c,d = str_byte(m_data, m_ptr, m_ptr + 4)
    if m_bigendian then d,c,b,a = a,b,c,d end
    m_ptr = m_ptr + 4
    local fr = bor( lshift( band(c, 0x7F), 16), lshift(b, 8), a )
    local exp = bor( band( d, 0x7F ) * 2, rshift( c, 7 ) )
    if exp == 0 then return 0 end

    local s = d > 127 and -1 or 1
    local n = math.ldexp( ( math.ldexp(fr, -23) + 1 ) * s, exp - 127 )
    return n
end

function float64()
    coverage_data(m_ptr, m_ptr + 8)
    local a,b,c,d,e,f,g,h = str_byte(m_data, m_ptr, m_ptr + 8)
    if not m_bigendian then h,g,f,e,d,c,b,a = a,b,c,d,e,f,g,h end
    m_ptr = m_ptr + 8

    local bytes = {a,b,c,d,e,f,g,h}
    local sign = 1
    local mantissa = bytes[2] % 2^4
    for i = 3, 8 do mantissa = mantissa * 256 + bytes[i] end
    if bytes[1] > 127 then sign = -1 end
    local exponent = (bytes[1] % 128) * 2^4 + math.floor(bytes[2] / 2^4)

    if exponent == 0 then
        return 0
    end
    mantissa = (math.ldexp(mantissa, -52) + 1) * sign
    return math.ldexp(mantissa, exponent - 1023)
end

function vector32() return Vector( float32(), float32(), float32() ) end
function vector48() return Vector( float16(), float16(), float16() ) end
function angle32() return Angle( float32(), float32(), float32() ) end

function matrix3x4()
    return Matrix({
        {float32(), float32(), float32(), float32()},
        {float32(), float32(), float32(), float32()},
        {float32(), float32(), float32(), float32()},
        {0,0,0,1},
    })
end

function quat128()

    return setmetatable( {
        x = float32(),
        y = float32(),
        z = float32(),
        w = float32(),
    }, quat_meta)

end

local NAN = 0/0
function quat64()

    --x,y,z: 21, w: 1
    --LO: yyyy yyyy yyyx xxxx | xxxx xxxx xxxx xxxx
    --HI: wzzz zzzz zzzz zzzz | zzzz zzyy yyyy yyyy

    local lo = uint32()
    local hi = uint32()
    local x = band( lo, 0x1FFFFF )
    local y = bor( band( rshift(lo, 21), 0x7FF), lshift( band(hi, 0x3FF), 11) )
    local z = band( rshift(hi, 10), 0x1FFFFF )
    local w = 0
    local ws = band( hi, 0x80000000 ) ~= 0 and -1 or 1

    x = (x - 1048576) * (1 / 1048576.5)
    y = (y - 1048576) * (1 / 1048576.5)
    z = (z - 1048576) * (1 / 1048576.5)
    w = math.sqrt( 1 - x*x - y*y - z*z) * ws
    assert(w == w, "Invalid Quat:" .. table.concat({x,y,z,w}, ','))

    return setmetatable( {
        x = x,
        y = y,
        z = z,
        w = w,
        is64 = true,
    }, quat_meta)

end

function quat48()

    local x = uint16()
    local y = uint16()
    local z = uint16()
    local w = 0
    local ws = band(z, 0x8000) ~= 0 and -1 or 1

    z = band(z, 0x7FFF)

    x = (x - 32768) * (1 / 32768)
    y = (y - 32768) * (1 / 32768)
    z = (z - 16384) * (1 / 16384)
    w = math.sqrt( 1 - x*x - y*y - z*z) * ws
    assert(w == w, "Invalid Quat:" .. table.concat({x,y,z,w}, ','))

    return setmetatable( {
        x = x,
        y = y,
        z = z,
        w = w,
    }, quat_meta)

end

function array_of( f, count )

    local t = {}
    for i=1, count do
        t[#t+1] = f()
    end
    return t

end

function indirect_array( dtype, flipped )

    local arr = {
        num = int32(),
        offset = int32(),
        dtype = dtype,
    }

    if flipped then
        arr.num, arr.offset = arr.offset, arr.num
    end
    return arr

end

function load_indirect_array( tbl, base, field, aux, ... )

    local arr = aux or tbl[field]
    if not arr.offset then return end

    local num, offset = arr.num, arr.offset
    local dtype = arr.dtype

    arr.num = nil
    arr.offset = nil
    arr.dtype = nil

    if offset == 0 and num ~= 0 then
        print("Warning: indirect array '" .. field .. "' with data and zero offset!")
        print(debug.traceback())
        return
    end
    if num == 0 then return end

    push_data(base + offset)
    local span = span_data(field)

    for i=1, num do
        local obj = dtype(...)
        arr[#arr+1] = obj
    end

    span:Stop()
    pop_data()

end

function indirect_name( tbl, base, field, num )

    field = field or "nameidx"
    local newfield = field:gsub("idx", "")

    if tbl[field] == 0 then
        tbl[newfield] = ""
        tbl[field] = nil
        if tbl[num] then tbl[num] = nil end
        return
    end

    if num and tbl[num] == 0 then
        tbl[newfield] = ""
        tbl[field] = nil
        tbl[num] = nil
        return
    end

    push_data(base + tbl[field])
    local span = span_data("name: ")
    tbl[newfield] = nullstr()
    span[3] = "name: " .. tostring(tbl[newfield])
    span:Stop()
    pop_data()
    
    --print("'" .. tbl[newfield] .. "' AT: " .. ("0x%x"):format(base + tbl[field]))

    tbl[field] = nil

    if tbl[num] then tbl[num] = nil end

end

function nullstr()

    local k = str_find(m_data, "\0", m_ptr, true)
    if k then 
        coverage_data(m_ptr, k)
        local str = str_sub(m_data, m_ptr, k-1)
        m_ptr = k+1
        return str
    end

end

function vcharstr(n)

    local str = charstr(n)
    local k = str_find(str, "\0", 0, true)
    if k then 
        str = str_sub(str, 1, k-1)
    end
    return str

end

local m_span = {} m_span.__index = m_span
function m_span:Stop()
    self[2] = tell_data()
    m_array_spans[#m_array_spans+1] = self
    m_active_span = self[4]
end

function span_data( name )
    local span = setmetatable({
        [1] = tell_data(),
        [3] = name,
        [4] = m_active_span,
    }, m_span)
    m_active_span = span
    local k, s = 1, m_active_span[4]
    while s do
        k = k + 1
        s = s[4]
    end
    m_active_span[5] = k
    return span
end

function str_int32(x)
    return str_char( band(x,0xFF), band(rshift(x, 8),0xFF), band(rshift(x, 16),0xFF), rshift(x, 24) )
end

return __lib