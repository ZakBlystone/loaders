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
local str_len = string.len
local str_rep = string.rep
local lshift, rshift, band, bor, bnot = bit.lshift, bit.rshift, bit.band, bit.bor, bit.bnot
local File = FindMetaTable("File")
local m_file = nil
local m_stack = nil
local WriteUShort = File.WriteUShort
local WriteShort = File.WriteShort
local WriteULong = File.WriteULong
local WriteLong = File.WriteLong
local WriteByte = File.WriteByte
local WriteDouble = File.WriteDouble
local WriteFloat = File.WriteFloat
local Write = File.Write

function open_data( filename, path )

    local f = file.Open(filename, "wb", path or "DATA")
    m_stack, m_file = {}, f
    return f ~= nil

end

function end_data()

    if not m_file then return end
    m_file:Close()
    m_file = nil

end

function seek_data( pos )
    m_file:Seek(pos)
end

function tell_data()
    return m_file:Tell()
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

function uint32(v)
    WriteULong(m_file, v)
end

function uint16(v)
    WriteUShort(m_file, v)
end

function uint8(v)
    WriteByte(m_file, v)
end

function int32(v)
    WriteLong(m_file, v)
end

function int16(v)
    WriteShort(m_file, v)
end

function int8(v)
    WriteByte(m_file, v)
end

function char(v)
    WriteByte(m_file, str_byte(v))
end

function charstr(str, n)
    local len = str_len(str)
    Write(m_file, str .. str_rep('\0', n - len))
end

function float16(v)
    assert(false, "Not yet implemented")
end

function float32(v)
    WriteFloat(m_file, v)
end

function vector32(v) local x,y,z = v:Unpack() float32(x) float32(y) float32(z) end
function vector48(v) local x,y,z = v:Unpack() float16(x) float16(y) float16(z) end
function angle32(v) local x,y,z = v:Unpack() float32(x) float32(y) float32(z) end

function matrix3x4(m)
    local e0,  e1,  e2,  e3,
          e4,  e5,  e6,  e7,
          e8,  e9,  e10, e11,
          e12, e13, e14, e15 = m:Unpack()

    float32(e0) float32(e1) float32(e2) float32(e3)
    float32(e4) float32(e5) float32(e6) float32(e7)
    float32(e8) float32(e9) float32(e10) float32(e11)
end

function quat128(q)

    float32(q.x)
    float32(q.y)
    float32(q.z)
    float32(q.w)

end

function quat64()
    assert(false, "Not yet implemented")
end

function quat48()
    assert(false, "Not yet implemented")
end

function array_of( f, v )

    for i=1, #v do
        f(v[i])
    end

end

function indirect_array( dtype, v, flipped )

    local arr = {
        values = v,
        num = #v,
        offset = 0,
        dtype = dtype,
        flipped = flipped,
    }

    arr.offset = tell_data()
    if flipped then
        int32(0)
        int32(arr.num)
    else
        arr.offset = arr.offset + 4
        int32(arr.num)
        int32(0)
    end

    return arr

end

function write_indirect_array( tbl, base, field, aux, ... )

    local arr = aux or tbl[field]
    if not arr.offset then return end

    local num, offset = arr.num, arr.offset
    local dtype = arr.dtype

    if num == 0 then return end
    
    base = tell_data() - base

    push_data( arr.offset )
    int32( base )
    pop_data()

    for i=1, num do
        arr.dtype( arr.values[i] )
    end

end

function indirect_name( str )

    local name = {
        offset = 0,
        str = str,
    }

    name.offset = tell_data()
    int32(0)

    return name

end

function nullstr( str )

    Write(m_file, str .. "\0")

end

function write_indirect_name( name, base )

    base = tell_data() - base
    push_data( name.offset )
    int32( base )
    pop_data()
    nullstr( name.str )

end


return __lib