--[[
This file is a part of the Loaders repository:
https://github.com/ZakBlystone/loaders

MDL3: source-engine studiomdl parser:
loads a studiomdl model

Usage:
mdl3.LoadModel( filename, <path> )
loads mdl, vtx, vvd

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

if SERVER then AddCSLuaFile() return end

local MDL3_VERSION = 1

if mdl3 ~= nil and mdl3.VERSION > MDL3_VERSION then return end

module("mdl3", package.seeall)

VERSION = MDL3_VERSION

STUDIO_CONST	= 1	-- get float
STUDIO_FETCH1	= 2	-- get Flexcontroller value
STUDIO_FETCH2	= 3	-- get flex weight
STUDIO_ADD		= 4
STUDIO_SUB		= 5
STUDIO_MUL		= 6
STUDIO_DIV		= 7
STUDIO_NEG		= 8	-- not implemented
STUDIO_EXP		= 9	-- not implemented
STUDIO_OPEN		= 10 -- only used in token parsing
STUDIO_CLOSE	= 11
STUDIO_COMMA	= 12 -- only used in token parsing
STUDIO_MAX		= 13
STUDIO_MIN		= 14
STUDIO_2WAY_0	= 15 -- Fetch a value from a 2 Way slider for the 1st value RemapVal( 0.0, 0.5, 0.0, 1.0 )
STUDIO_2WAY_1	= 16 -- Fetch a value from a 2 Way slider for the 2nd value RemapVal( 0.5, 1.0, 0.0, 1.0 )
STUDIO_NWAY		= 17 -- Fetch a value from a 2 Way slider for the 2nd value RemapVal( 0.5, 1.0, 0.0, 1.0 )
STUDIO_COMBO	= 18 -- Perform a combo operation (essentially multiply the last N values on the stack)
STUDIO_DOMINATE	= 19 -- Performs a combination domination operation
STUDIO_DME_LOWER_EYELID = 20
STUDIO_DME_UPPER_EYELID = 21

STUDIO_X		= 0x00000001
STUDIO_Y		= 0x00000002	
STUDIO_Z		= 0x00000004
STUDIO_XR		= 0x00000008
STUDIO_YR		= 0x00000010
STUDIO_ZR		= 0x00000020

STUDIO_LX		= 0x00000040
STUDIO_LY		= 0x00000080
STUDIO_LZ		= 0x00000100
STUDIO_LXR		= 0x00000200
STUDIO_LYR		= 0x00000400
STUDIO_LZR		= 0x00000800

STUDIO_LINEAR	= 0x00001000

STUDIO_TYPES	= 0x0003FFFF
STUDIO_RLOOP	= 0x00040000 -- controller that wraps shortest distance

STUDIO_LOOPING	= 0x0001		-- ending frame should be the same as the starting frame
STUDIO_SNAP		= 0x0002		-- do not interpolate between previous animation and this one
STUDIO_DELTA	= 0x0004		-- this sequence "adds" to the base sequences, not slerp blends
STUDIO_AUTOPLAY	= 0x0008		-- temporary flag that forces the sequence to always play
STUDIO_POST		= 0x0010
STUDIO_ALLZEROS	= 0x0020		-- this animation/sequence has no real animation data

STUDIO_CYCLEPOSE = 0x0080		-- cycle index is taken from a pose parameter index
STUDIO_REALTIME	 = 0x0100		-- cycle index is taken from a real-time clock, not the animations cycle index
STUDIO_LOCAL	 = 0x0200		-- sequence has a local context sequence
STUDIO_HIDDEN	 = 0x0400		-- don't show in default selection views
STUDIO_OVERRIDE	 = 0x0800		-- a forward declared sequence (empty)
STUDIO_ACTIVITY	 = 0x1000		-- Has been updated at runtime to activity index
STUDIO_EVENT	 = 0x2000		-- Has been updated at runtime to event index
STUDIO_WORLD	 = 0x4000		-- sequence blends in worldspace
STUDIO_EVENT_CLIENT = 0x8000	-- Has been updated at runtime to event index on client

STUDIO_AL_POST		= 0x0010
STUDIO_AL_SPLINE	= 0x0040		-- convert layer ramp in/out curve is a spline instead of linear
STUDIO_AL_XFADE		= 0x0080		-- pre-bias the ramp curve to compense for a non-1 weight, assuming a second layer is also going to accumulate
STUDIO_AL_NOBLEND	= 0x0200		-- animation always blends at 1.0 (ignores weight)
STUDIO_AL_LOCAL		= 0x1000		-- layer is a local context sequence
STUDIO_AL_POSE		= 0x4000		-- layer blends using a pose parameter instead of parent cycle

STUDIO_PROC_AXISINTERP = 1
STUDIO_PROC_QUATINTERP = 2
STUDIO_PROC_AIMATBONE = 3
STUDIO_PROC_AIMATATTACH = 4
STUDIO_PROC_JIGGLE = 5

JIGGLE_IS_FLEXIBLE	            = 0x01
JIGGLE_IS_RIGID				    = 0x02
JIGGLE_HAS_YAW_CONSTRAINT	    = 0x04
JIGGLE_HAS_PITCH_CONSTRAINT	    = 0x08
JIGGLE_HAS_ANGLE_CONSTRAINT	    = 0x10
JIGGLE_HAS_LENGTH_CONSTRAINT    = 0x20
JIGGLE_HAS_BASE_SPRING			= 0x40

MAX_NUM_LODS = 8
MAX_NUM_BONES_PER_VERT = 3

-- Strip flags
STRIP_IS_TRILIST = 1
STRIP_IS_TRISTRIP = 2

-- Stripgroup flags
STRIPGROUP_IS_FLEXED = 0x01
STRIPGROUP_IS_HWSKINNED = 0x02
STRIPGROUP_IS_DELTA_FLEXED = 0x04
STRIPGROUP_SUPPRESS_HW_MORPH = 0x08

-- Mesh flags
MESH_IS_TEETH = 0x01
MESH_IS_EYES = 0x02

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

local function coverage_data( start, stop )
    for i=start, stop do
        m_coverage[i] = true
    end
end

local function begin_data( data )
    m_data, m_ptr, m_stack, m_coverage = data, 1, {}, {}
end

local function open_data( filename, path )
    local f = file.Open(filename, "rb", path or "GAME")
    local size = f:Size()
    local data = f:Read(size)
    m_size = size
    m_array_spans = {}
    f:Close()
    print("OPEN: '" .. filename .. "' " .. size .. " bytes")
    begin_data(data)
end

local function dump_data( first, last )

    local c0 = Color(160, 160, 160)
    local c1 = Color(100, 230, 250)
    local c2 = Color(200, 130, 150)
    local row = "0x%0.4x: "
    local col = "%0.2x "
    local newline = "\n"
    local separator = ": "
    local separator2 = " : "

    local function printable(b)
        if b >= 32 and b <= 125 then return string.char(b) else return "." end
    end

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

local function end_data()
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

    --[[for _, s in ipairs(spans) do
        print("SPAN: " .. (s[2] - s[1]) )
        dump_data(s[1], s[2])
    end]]

    --PrintTable(spans)
    m_data = nil
end

local function seek_data( pos )
    m_ptr = pos + 1
end

local function tell_data()
    return m_ptr - 1
end

local function push_data(addr)
    m_stack[#m_stack+1] = tell_data()
    seek_data(addr)
end

local function pop_data()
    local n = #m_stack
    seek_data(m_stack[n])
    m_stack[n] = nil
end

local function uint32()
    coverage_data(m_ptr, m_ptr+4)
    local a,b,c,d = str_byte(m_data, m_ptr, m_ptr + 4)
    m_ptr = m_ptr + 4
    local n = bor( lshift(d,24), lshift(c,16), lshift(b, 8), a )
    if n < 0 then n = (0x1p32) - 1 - bnot(n) end
    return n
end

local function uint16()
    coverage_data(m_ptr, m_ptr+2)
    local a,b = str_byte(m_data, m_ptr, m_ptr + 2)
    m_ptr = m_ptr + 2
    return bor( lshift(b, 8), a )
end

local function uint8()
    coverage_data(m_ptr, m_ptr)
    local a = str_byte(m_data, m_ptr, m_ptr)
    m_ptr = m_ptr + 1
    return a
end

local function int32()
    coverage_data(m_ptr, m_ptr+4)
    local a,b,c,d = str_byte(m_data, m_ptr, m_ptr + 4)
    m_ptr = m_ptr + 4
    local n = bor( lshift(d,24), lshift(c,16), lshift(b, 8), a )
    return n
end

local function int16()
    coverage_data(m_ptr, m_ptr+2)
    local a,b = str_byte(m_data, m_ptr, m_ptr + 2)
    m_ptr = m_ptr + 2
    local n = bor( lshift(b, 8), a )
    if band( b, 0x80 ) ~= 0 then n = -(0x1p16) + n end
    return n
end

local function int8()
    coverage_data(m_ptr, m_ptr)
    local a = str_byte(m_data, m_ptr, m_ptr)
    m_ptr = m_ptr + 1
    if band( a, 0x80 ) ~= 0 then a = -(0x100) + a end
    return a
end

local function char()
    coverage_data(m_ptr, m_ptr)
    local a = str_sub(m_data, m_ptr, m_ptr)
    m_ptr = m_ptr + 1
    return a
end

local function charstr(n)
    coverage_data(m_ptr, m_ptr + n)
    local a = str_sub(m_data, m_ptr, m_ptr + n - 1)
    m_ptr = m_ptr + n
    return a
end

local function float16()
    local v = uint16()
    local mantissa = band( v, 0x3FF )
    local exp = band( rshift(v, 10), 0x1F )
    local sgn = band( rshift(v, 15), 0x01 ) and -1 or 1

    mantissa = lshift(mantissa, 23-10)
    local _exp = (exp - 15) * (exp ~= 0 and 1 or 0)
    return math.ldexp( (math.ldexp(mantissa, -23) + 1) * sgn, _exp )
end

local function float32()
    coverage_data(m_ptr, m_ptr + 4)
    local a,b,c,d = str_byte(m_data, m_ptr, m_ptr + 4)
    m_ptr = m_ptr + 4
    local fr = bor( lshift( band(c, 0x7F), 16), lshift(b, 8), a )
    local exp = bor( band( d, 0x7F ) * 2, rshift( c, 7 ) )
    if exp == 0 then return 0 end

    local s = d > 127 and -1 or 1
    local n = math.ldexp( ( math.ldexp(fr, -23) + 1 ) * s, exp - 127 )
    return n
end

local function vector32()
    return Vector( float32(), float32(), float32() )
end

local function vector48()
    return Vector( float16(), float16(), float16() )
end

local function angle32()
    return Angle( float32(), float32(), float32() )
end

local function matrix3x4()
    return Matrix({
        {float32(), float32(), float32(), float32()},
        {float32(), float32(), float32(), float32()},
        {float32(), float32(), float32(), float32()},
        {0,0,0,1},
    })
end

local quat_meta = {}
quat_meta.__index = quat_meta

function quat_meta:Angle()

    local q = self
    local fx, fy, fz, rx, ry, rz, ux, uy, uz
    fx = 1.0 - 2.0 * q.y * q.y - 2.0 * q.z * q.z;
	fy = 2.0 * q.x * q.y + 2.0 * q.w * q.z;
	fz = 2.0 * q.x * q.z - 2.0 * q.w * q.y;
	rx = 2.0 * q.x * q.y - 2.0 * q.w * q.z;
	ry = 1.0 - 2.0 * q.x * q.x - 2.0 * q.z * q.z;
	rz = 2.0 * q.y * q.z + 2.0 * q.w * q.x;
	ux = 2.0 * q.x * q.z + 2.0 * q.w * q.y;
	uy = 2.0 * q.y * q.z - 2.0 * q.w * q.x;
	uz = 1.0 - 2.0 * q.x * q.x - 2.0 * q.y * q.y;

    local xyDist = math.sqrt( fx * fx + fy * fy );
	local angle = Angle()

	if xyDist > 0.001 then
		angle.y = math.atan2( fy, fx ) * 57.3
		angle.p = math.atan2( -fz, xyDist ) * 57.3
		angle.r = math.atan2( rz, uz ) * 57.3
	else
		angle.y = math.atan2( -rx, ry ) * 57.3
		angle.p = math.atan2( -fz, xyDist ) * 57.3
		angle.r = 0
	end

    return angle

end

function quat_meta:RotateVector(v)

    local x,y,z = v:Unpack()
    local q = self
	local x2 = 2 * x
	local y2 = 2 * y
	local z2 = 2 * z
	local ww = q.w * q.w - 0.5
	local dot2 = (q.x * x2 + q.y * y2 + q.z * z2)

	return Vector(
		x2 * ww + (q.y * z2 - q.z * y2) * q.w + q.x * dot2,
		y2 * ww + (q.z * x2 - q.x * z2) * q.w + q.y * dot2,
		z2 * ww + (q.x * y2 - q.y * x2) * q.w + q.z * dot2
	)

end

function quat_meta:Blend( other, t, dst )

	other = self:QuaternionAlign( other )

	local sclp = 1.0 - t
	local sclq = t
    dst.x = (1-t) * self.x + t * other.x
    dst.y = (1-t) * self.y + t * other.y
    dst.z = (1-t) * self.z + t * other.z
    dst.w = (1-t) * self.w + t * other.w

	qt:Normalize()
	return qt

end

function quat_meta:Dot(b)

	local a = self
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w

end

function quat_meta:Normalize()

	local radius = self:Dot(self)
	if radius ~= 0 then
		radius = math.sqrt(radius);
		local iradius = 1.0/radius;
		self.x = self.x * iradius;
		self.y = self.y * iradius;
		self.z = self.z * iradius;
		self.w = self.w * iradius;
	end
	return radius

end

local function quat()

    return setmetatable( {
        x = 0,
        y = 0,
        z = 0,
        w = 0,
    }, quat_meta)

end

local function quat128()

    return setmetatable( {
        x = float32(),
        y = float32(),
        z = float32(),
        w = float32(),
    }, quat_meta)

end

local NAN = 0/0
local function quat64()

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

local function quat48()

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

local function array_of( f, count )

    local t = {}
    for i=1, count do
        t[#t+1] = f()
    end
    return t

end

local function nullstr()

    local k = str_find(m_data, "\0", m_ptr, true)
    if k then 
        coverage_data(m_ptr, k)
        local str = str_sub(m_data, m_ptr, k-1)
        m_ptr = k
        return str
    end

end

local function vcharstr(n)

    local str = charstr(n)
    local k = str_find(str, "\0", 0, true)
    if k then 
        str = str_sub(str, 1, k-1)
    end
    return str

end

local function mdl_array( dtype )

    return {
        num = int32(),
        offset = int32(),
        dtype = dtype,
    }

end

local m_span = {} m_span.__index = m_span
function m_span:Stop()
    self[2] = tell_data()
    m_array_spans[#m_array_spans+1] = self
    m_active_span = self[4]
end
local function mdl_span( name )
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

local function mdl_loadarray( tbl, base, field, aux, ... )

    local arr = aux or tbl[field]
    if not arr.offset then return end
    local data = {}

    local num, offset = arr.num, arr.offset
    local dtype = arr.dtype

    arr.num = nil
    arr.offset = nil
    arr.dtype = nil

    push_data(base + offset)
    local span = mdl_span(field)

    for i=1, num do
        local obj = dtype(...)
        arr[#arr+1] = obj
    end

    span:Stop()
    pop_data()

end

local function mdl_loadname( tbl, base, field, num )

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
    local span = mdl_span("name: ")
    tbl[newfield] = nullstr()
    span[3] = "name: " .. tostring(tbl[newfield])
    span:Stop()
    pop_data()
    
    --print("'" .. tbl[newfield] .. "' AT: " .. ("0x%x"):format(base + tbl[field]))

    tbl[field] = nil

    if tbl[num] then tbl[num] = nil end

end

local function mdl_axisinterpbone()

    return {
        control = int32(),
        axis = int32(),
        pos = array_of(vector32, 6),
        quat = array_of(quat128, 6),
    }

end

local function mdl_quatinterpinfo()

    return {
        inv_tolerance = float32(),
        trigger = quat128(),
        pos = vector32(),
        quat = quat128(),
    }

end

local function mdl_quatinterpbone()

    local base = tell_data()
    local quatinterp = {
        control = int32(),
        triggers = mdl_array(mdl_quatinterpinfo),
    }

    mdl_loadarray(quatinterp, base, "triggers")

    return quatinterp

end

local function mdl_aimatbone()

    return {
        parent = int32(),
        aim = int32(),
        aimvector = vector32(),
        upvector = vector32(),
        basepos = vector32(),
    }

end

local function mdl_jigglebone()

    return {
        flags = int32(),
        length = float32(),
        tipMass = float32(),
        yawStiffness = float32(),
        yawDamping = float32(),
        pitchStiffness = float32(),
        pitchDamping = float32(),
        alongStiffness = float32(),
        alongDamping = float32(),
        angleLimit = float32(),

        minYaw = float32(),
        maxYaw = float32(),
        yawFriction = float32(),
        yawBounce = float32(),

        minPitch = float32(),
        maxPitch = float32(),
        pitchFriction = float32(),
        pitchBounce = float32(),

        baseMass = float32(),
        baseStiffness = float32(),
        baseDamping = float32(),
        baseMinLeft = float32(),
        baseMaxLeft = float32(),
        baseLeftFriction = float32(),
        baseMinUp = float32(),
        baseMaxUp = float32(),
        baseUpFriction = float32(),
        baseMinForward = float32(),
        baseMaxForward = float32(),
        baseForwardFriction = float32(),
    }

end

local function mdl_bone()

    local base = tell_data()
    local bone = {
        nameidx = int32(),
        parent = int32(),
        bonecontroller = array_of(int32, 6),
        pos = vector32(),
        quat = quat128(),
        rot = angle32(),
        posscale = vector32(),
        rotscale = vector32(),
        poseToBone = matrix3x4(),
        qAlignment = quat128(),
        flags = int32(),
        proctype = int32(),
        procindex = int32(),
        physicsbone = float32(),
        surfacepropidx = int32(),
        contents = int32(),
    }

    push_data(base + bone.procindex)
    if bone.proctype == STUDIO_PROC_AXISINTERP then
        bone.quatinterp = mdl_axisinterpbone()
    elseif bone.proctype == STUDIO_PROC_QUATINTERP then
        bone.quatinterp = mdl_quatinterpbone()
    elseif bone.proctype == STUDIO_PROC_AIMATBONE then
        bone.aimatbone = mdl_aimatbone()
    elseif bone.proctype == STUDIO_PROC_AIMATATTACH then
        bone.aimatattach = mdl_aimatbone()
    elseif bone.proctype == STUDIO_PROC_JIGGLE then
        bone.jiggle = mdl_jigglebone()
    end
    pop_data()

    array_of(int32, 8) -- unused
    mdl_loadname(bone, base)
    mdl_loadname(bone, base, "surfacepropidx")

    return bone

end

local function mdl_bonecontroller()

    local ctrl = {
        bone = int32(),
        type = int32(),
        _start = float32(),
        _end = float32(),
        rest = int32(),
        inputfield = int32(),
    }

    array_of(int32, 8) -- unused
    return ctrl

end

local function mdl_hitbox()

    local base = tell_data()
    local bbox = {
        name = "",
        bone = int32(),
        group = int32(),
        bbmin = vector32(),
        bbmax = vector32(),
        nameidx = int32(),
    }

    array_of(int32, 8) -- unused

    if bbox.nameidx ~= 0 then
        mdl_loadname(bbox, base)
    end

    return bbox

end

local function mdl_hitboxset()

    local base = tell_data()
    local set = {
        nameidx = int32(),
        hitboxes = mdl_array(mdl_hitbox),
    }

    mdl_loadname(set, base)
    mdl_loadarray(set, base, "hitboxes")

    return set

end

local function mdl_movement()

    return {
        endframe = int32(),
        motionflags = int32(),
        v0 = float32(),
        v1 = float32(),
        angle = float32(),
        vector = vector32(),
        position = vector32(),
    }

end

local function mdl_animblock()

    return {
        datastart = int32(),
        dataend = int32(),
    }

end

local function mdl_ikrule()

    local ikrule = {
        index = int32(),
        type = int32(),
        chain = int32(),
        bone = int32(),
        slot = int32(),
        height = float32(),
        radius = float32(),
        floor = float32(),
        pos = vector32(),
        q = quat128(),
        compressedikerrorindex = int32(),
        unused2 = int32(),
        iStart = int32(),
        ikerrorindex = int32(),
        _start = float32(),
        _peak = float32(),
        _tail = float32(),
        _end = float32(),
        unused3 = float32(),
        contact = float32(),
        drop = float32(),
        top = float32(),
        unused6 = int32(),
        unused7 = int32(),
        unused8 = int32(),
        szattachmentindex = int32(),
    }

    array_of(int32, 7) -- unused

    return ikrule

end

local function mdl_localhierarchy()

    local hierarchy = {
        iBone = int32(),
        iNewParent = int32(),
        _start = float32(),
        _peak = float32(),
        _tail = float32(),
        _end = float32(),
        iStart = int32(),
        localanimindex = int32(),
    }

    array_of(int32, 4) -- unused

    return hierarchy

end

local function mdl_animsection()

    return {
        animblock = int32(),
        animindex = int32(),
    }

end

local function mdl_animdesc()

    local base = tell_data()
    local anim = {
        baseptr = base,
        studiooffset = int32(),
        nameidx = int32(),
        fps = float32(),
        flags = int32(),
        numframes = int32(),
        movements = mdl_array(mdl_movement),
        _unused1 = array_of(int32, 6),
        animblock = int32(),
        animindex = int32(),
        numikrules = int32(),
        ikruleindex = int32(),
        animblockikruleindex = int32(),
        localhierarchy = mdl_array(mdl_localhierarchy),
        sectionindex = int32(),
        sectionframes = int32(),
        zeroframespan = int16(),
        zeroframecount = int16(),
        zeroframeindex = int32(),
        zeroframestalltime = float32(),
    }

    mdl_loadname(anim, base)

    mdl_loadarray(anim, base, "movements")
    mdl_loadarray(anim, base, "localhierarchy")

    if anim.sectionframes ~= 0 then
        local sections = {}
        local num = math.floor(anim.numframes / anim.sectionframes) + 2
        push_data(base + anim.sectionindex)
        local span = mdl_span("section")
        for i=1, num do
            sections[#sections+1] = mdl_animsection()
        end
        span:Stop()
        pop_data()
        anim.sections = sections
    end

    return anim

end

local function mdl_event()

    local base = tell_data()
    local event = {
        cycle = float32(),
        event = int32(),
        type = int32(),
        options = vcharstr(64),
        nameidx = int32(),
    }

    mdl_loadname(event, base)

    return event

end

local function mdl_autolayer()

    return {
        iSequence = int16(),
        iPose = int16(),
        flags = int32(),
        _start = float32(),
        _peak = float32(),
        _tail = float32(),
        _end = float32(),
    }

end

local function mdl_iklock()

    local lock = {
        chain = int32(),
        flPosWeight = float32(),
        flLocalQWeight = float32(),
        flags = int32(),
    }

    array_of(int32, 4) -- unused

    return lock

end

local function mdl_activitymodifier()

    local base = tell_data()
    local actmod = {
        nameidx = int32(),
    }

    mdl_loadname(actmod, base)

    return actmod

end

local function mdl_seqdesc()

    local base = tell_data()
    local seq = {
        baseptr = base,
        studiooffset = int32(),
        labelidx = int32(),
        actnameidx = int32(),
        flags = int32(),
        activity = int32(),
        actweight = int32(),
        events = mdl_array(mdl_event),
        bbmin = vector32(),
        bbmax = vector32(),
        numblends = int32(),
        animindexindex = int32(),
        movementindex = int32(),
        groupsize = array_of(int32, 2),
        paramindex = array_of(int32, 2),
        paramstart = array_of(float32, 2),
        paramend = array_of(float32, 2),
        paramparent = int32(),
        fadeintime = float32(),
        fadeouttime = float32(),
        localentrynode = int32(),
        localexitnode = int32(),
        nodeflags = int32(),
        entryphase = float32(),
        exitphase = float32(),
        lastframe = float32(),
        nextseq = int32(),
        pose = int32(),
        numikrules = int32(),
        autolayers = mdl_array(mdl_autolayer),
        weightlistindex = int32(),
        posekeyindex = int32(),
        iklocks = mdl_array(mdl_iklock),
        keyvalueindex = int32(),
        keyvaluesize = int32(),
        cycleposeindex = int32(),
        activitymodifiers = mdl_array(mdl_activitymodifier),
    }

    array_of(int32, 5) -- unused

    mdl_loadname(seq, base, "labelidx")
    mdl_loadname(seq, base, "actnameidx")

    mdl_loadarray(seq, base, "events")
    mdl_loadarray(seq, base, "autolayers")
    mdl_loadarray(seq, base, "iklocks")
    mdl_loadarray(seq, base, "activitymodifiers")

    --PrintTable(seq)

    return seq

end

local function mdl_texture()

    local base = tell_data()
    local tex = {
        nameidx = int32(),
        flags = int32(),
        used = int32(),
        unused1 = int32(),
    }

    array_of(int32, 12) -- unused

    mdl_loadname(tex, base)

    return tex

end

local function mdl_cdtexture()

    local base = tell_data()
    local cdtex = { nameidx = int32(), }

    mdl_loadname(cdtex, 0)

    return cdtex.name

end

local function mdl_flex()

    local base = tell_data()
    local flex = {
        flexdesc = int32(),
        target0 = float32(),
        target1 = float32(),
        target2 = float32(),
        target3 = float32(),
        numverts = int32(),
        vertindex = int32(),
        flexpair = int32(),
        vertanimtype = uint8(),
        unusedchar = array_of(uint8, 3),
    }

    array_of(int32, 6) -- unused

    return flex

end

local function mdl_mesh()

    local base = tell_data()
    local mesh = {
        material = int32(),
        modelindex = int32(),
        numvertices = int32(),
        vertexoffset = int32(),
        flexes = mdl_array(mdl_flex),
        materialtype = int32(),
        materialparam = int32(),
        meshid = int32(),
        center = vector32(),
    }

    array_of(int32, 17) -- unused

    mesh.modelindex = mesh.modelindex + base
    mdl_loadarray(mesh, base, "flexes")

    return mesh

end

local function mdl_eyeball()

    local base = tell_data()
    local eyeball = {
        nameidx = int32(),
        bone = int32(),
        org = vector32(),
        zoffset = float32(),
        radius = float32(),
        up = vector32(),
        forward = vector32(),
        texture = int32(),
        unused1 = int32(),
        iris_scale = float32(),
        unused2 = int32(),
        upperflexdesc = array_of(int32, 3),
        lowerflexdesc = array_of(int32, 3),
        uppertarget = array_of(float32, 3),
        lowertarget = array_of(float32, 3),
        upperlidflexdesc = int32(),
        lowerlidflexdesc = int32(),
        unused = array_of(int32, 4),
        nonFACS = uint8(),
        unused3 = array_of(uint8, 3),
        unused4 = array_of(int32, 7),
    }

    return eyeball

end

local function mdl_model()

    local base = tell_data()
    local model = {
        ptr = base,
        name = vcharstr(64),
        type = int32(),
        boundingradius = float32(),
        meshes = mdl_array(mdl_mesh),
        numvertices = int32(),
        vertexindex = int32(),
        tangentsindex = int32(),
        numattachments = int32(),
        attachmentindex = int32() + base,
        eyeballs = mdl_array(mdl_eyeball),
    }

    array_of(int32, 10) -- unused

    mdl_loadarray(model, base, "meshes")
    mdl_loadarray(model, base, "eyeballs")

    return model

end

local function mdl_bodypart()

    local base = tell_data()
    local part = {
        nameidx = int32(),
        nummodels = int32(),
        base = int32(),
        modelindex = int32(),
    }

    mdl_loadname(part, base)

    local models = { 
        num = part.nummodels, 
        offset = part.modelindex, 
        dtype = mdl_model, 
    }
    mdl_loadarray(part, base, "models", models)

    part.nummodels = nil
    part.modelindex = nil
    part.models = models

    return part

end

local function mdl_attachment()

    local base = tell_data()
    local attach = {
        nameidx = int32(),
        flags = uint32(),
        localbone = int32(),
        _local = matrix3x4(),
    }

    array_of(int32, 8) -- unused

    mdl_loadname(attach, base)

    return attach

end

local function mdl_flexdesc()

    local base = tell_data()
    local flexdesc = {
        facsidx = int32(),
    }

    mdl_loadname(flexdesc, base, "facsidx")

    return flexdesc

end

local function mdl_flexcontroller()

    local base = tell_data()
    local flexctrl = {
        typeidx = int32(),
        nameidx = int32(),
        localToGlobal = int32(),
        min = float32(),
        max = float32(),
    }

    mdl_loadname(flexctrl, base, "typeidx")
    mdl_loadname(flexctrl, base, "nameidx")

    return flexctrl

end

local float_ops = {
    [STUDIO_CONST] = true,
}

local int_ops = {
    [STUDIO_FETCH1] = true,
    [STUDIO_FETCH2] = true,
    [STUDIO_COMBO] = true,
    [STUDIO_DOMINATE] = true,
    [STUDIO_2WAY_0] = true,
    [STUDIO_2WAY_1] = true,
    [STUDIO_NWAY] = true,
    [STUDIO_DME_LOWER_EYELID] = true,
    [STUDIO_DME_UPPER_EYELID] = true,
}

local function mdl_flexop()

    local flexop = {
        op = int32(),
    }

    if float_ops[flexop.op] then
        flexop.value = float32()
    elseif int_ops[flexop.op] then
        flexop.index = int32()
    else
        int32()
    end

    return flexop

end

local function mdl_flexrule()

    local base = tell_data()
    local flexrule = {
        flex = int32(),
        flexops = mdl_array(mdl_flexop),
    }

    mdl_loadarray(flexrule, base, "flexops")

    return flexrule

end

local function mdl_ikchainlink()

    return {
        bone = int32(),
        kneeDir = vector32(),
        unused0 = vector32(),
    }

end

local function mdl_ikchain()

    local base = tell_data()
    local chain = {
        nameidx = int32(),
        linktype = int32(),
        links = mdl_array(mdl_ikchainlink),
    }

    mdl_loadname(chain, base)
    mdl_loadarray(chain, base, "links")

    return chain

end

local function mdl_mouth()

    return {
        bone = int32(),
        forward = vector32(),
        flexdesc = int32(),
    }

end

local function mdl_poseparamdesc()

    local base = tell_data()
    local poseparam = {
        nameidx = int32(),
        flags = int32(),
        _start = float32(),
        _end = float32(),
        _loop = float32(),
    }

    mdl_loadname(poseparam, base)

    return poseparam

end

local function mdl_modelgroup()

    local base = tell_data()
    local group = {
        labelidx = int32(),
        nameidx = int32(),
    }

    mdl_loadname(group, base, "labelidx")
    mdl_loadname(group, base, "nameidx")

    return group

end

local function mdl_flexcontrollerui()

    local base = tell_data()
    local ctrlui = {
        nameidx = int32(),
        param0idx = int32(),
        param1idx = int32(),
        param2idx = int32(),
        remaptype = uint8(),
        stereo = uint8(),
        unused = uint16(),
    }

    mdl_loadname(ctrlui, base)

    return ctrlui

end

local function mdl_studiohdr2()

    local span = mdl_span("header_2")
    local base = tell_data()
    local hdr2 = {
        numsrcbonetransform = int32(),
        srcbonetransformindex = int32(),
        illumpositionattachmentindex = int32(),
        flMaxEyeDeflection = float32(),
        linearboneindex = int32(),
        reserved = array_of(int32, 59),
    }

    span:Stop()

    return hdr2

end

local function mdl_header()

    local base = tell_data()
    local header = {
        id = int32(),
        version = int32(),
        checksum = int32(),
        name = vcharstr(64),
        length = int32(),
        eyeposition = vector32(),
        illumposition = vector32(),
        hull_min = vector32(),
        hull_max = vector32(),
        view_bbmin = vector32(),
        view_bbmax = vector32(),
        flags = int32(),
        bones = mdl_array(mdl_bone),
        bone_controllers = mdl_array(mdl_bonecontroller),
        hitbox_sets = mdl_array(mdl_hitboxset),
        local_anims = mdl_array(mdl_animdesc),
        local_sequences = mdl_array(mdl_seqdesc),
        activitylistversion = int32(),
        eventsindexed = int32(),
        textures = mdl_array(mdl_texture),
        cdtextures = mdl_array(mdl_cdtexture),
        numskinref = int32(),
        numskinfamilies = int32(),
        skinindex = int32(),
        bodyparts = mdl_array(mdl_bodypart),
        attachments = mdl_array(mdl_attachment),
        numlocalnodes = int32(),
        localnodeindex = int32(),
        localnodenameindex = int32(),
        flexes = mdl_array(mdl_flexdesc),
        flexcontrollers = mdl_array(mdl_flexcontroller),
        flexrules = mdl_array(mdl_flexrule),
        ikchains = mdl_array(mdl_ikchain),
        mouths = mdl_array(mdl_mouth),
        poseparams = mdl_array(mdl_poseparamdesc),
        surfacepropidx = int32(),
        keyvaluesidx = int32(),
        keyvaluessize = int32(),
        localikautoplaylocks = mdl_array(mdl_iklock),
        mass = float32(),
        contents = int32(),
        includemodels = mdl_array(mdl_modelgroup),
        virtualModel = int32(),
        animblocknameidx = int32(),
        animblocks = mdl_array(mdl_animblock),
        animblockModel = int32(),
        bonetablebynameindex = int32(),
        pVertexBase = int32(),
        pIndexBase = int32(),
        constdirectionallightdot = uint8(),
        rootLOD = uint8(),
        numAllowedRootLODs = uint8(),
        unused = uint8(),
        unused4 = uint32(),
        flexcontrollerui = mdl_array(mdl_flexcontrollerui),
        flVertAnimFixedPointScale = float32(),
        unused3 = int32(),
        studiohdr2index = int32(),
        unused2 = int32(),
    }

    push_data(base + header.bonetablebynameindex)
    local t = {}
    for i=1, header.bones.num do
        t[#t+1] = uint8()
    end
    header.bonetablebynameindex = t
    pop_data()

    if header.studiohdr2index ~= 0 then
        push_data(base + header.studiohdr2index)
        header.hdr2 = mdl_studiohdr2()
        pop_data()
    end

    mdl_loadname(header, base, "surfacepropidx")
    mdl_loadname(header, base, "animblocknameidx")
    mdl_loadname(header, base, "keyvaluesidx", "keyvaluessize")

    return header

end

local function vvd_boneweight()

    return {
        weight = array_of(float32, MAX_NUM_BONES_PER_VERT),
        bone = array_of(uint8, MAX_NUM_BONES_PER_VERT),
        numBones = uint8(),
    }

end

local vvd_boneweight_size = 5 * MAX_NUM_BONES_PER_VERT + 1
local vvd_vertex_size = vvd_boneweight_size + 24 + 8
local function vvd_vertex()

    return {
        weights = vvd_boneweight(),
        position = vector32(),
        normal = vector32(),
        u = float32(),
        v = float32(),
    }

end

local function vvd_tangent()

    return {
        x = float32(),
        y = float32(),
        z = float32(),
        w = float32(),
    }

end

local function vvd_header()

    return {
        id = int32(),
        version = int32(),
        checksum = int32(),
        numLODs = int32(),
        numLODVertices = array_of(int32, MAX_NUM_LODS),
        numFixups = int32(),
        fixupTableStart = int32(),
        vertexDataStart = int32(),
        tangentDataStart = int32(),
    }

end

local function vvd_fixup()

    return {
        lod = int32(),
        sourceID = int32(),
        numVertices = int32(),
    }

end

local function vtx_vertex()

    return {
        boneWeightIndex = array_of(uint8, 3),
        numBones = uint8(),
        origMeshVertID = uint16(),
        boneID = array_of(int8, 3),
    }

end

local function vtx_strip()

    local base = tell_data()
    local strip = {
        numIndices = int32(),
        indexOffset = int32(),
        numVerts = int32(),
        vertOffset = int32(),
        numBones = int16(),
        flags = uint8(),
        numBoneStateChanges = int32(),
        boneStateChangeOffset = int32(),
    }

    if band(strip.flags, STRIP_IS_TRILIST) ~= 0 then
        strip.isTriList = true
    elseif band(strip.flags, STRIP_IS_TRISTRIP) ~= 0 then
        strip.isTriStrip = true
    end
    strip.flags = nil

    return strip

end

local function vtx_stripgroup()

    local base = tell_data()
    local group = {
        vertices = mdl_array(vtx_vertex),
        indices = mdl_array(uint16),
        strips = mdl_array(vtx_strip),
        flags = uint8(),
    }

    if band(group.flags, STRIPGROUP_IS_FLEXED) ~= 0 then group.isFlexed = true end
    if band(group.flags, STRIPGROUP_IS_HWSKINNED) ~= 0 then group.isHWSkinned = true end
    if band(group.flags, STRIPGROUP_IS_DELTA_FLEXED) ~= 0 then group.isDeltaFlexed = true end
    if band(group.flags, STRIPGROUP_SUPPRESS_HW_MORPH) ~= 0 then group.supressHWMorph = true end
    group.flags = nil

    mdl_loadarray(group, base, "vertices")
    mdl_loadarray(group, base, "indices")
    mdl_loadarray(group, base, "strips")

    local vertices = group.vertices
    local indices = group.indices

    for i=1, #indices do
        local idx = indices[i]
        local vidx = vertices[idx+1].origMeshVertID+1
        indices[i] = vidx
    end

    group.vertices = nil

    return group

end

local function vtx_mesh()

    local base = tell_data()
    local mesh = {
        stripgroups = mdl_array(vtx_stripgroup),
        flags = uint8(),
    }

    if band(mesh.flags, MESH_IS_TEETH) ~= 0 then mesh.isTeeth = true end
    if band(mesh.flags, MESH_IS_EYES) ~= 0 then mesh.isEyes = true end
    mesh.flags = nil

    mdl_loadarray(mesh, base, "stripgroups")
    return mesh

end

local function vtx_modellod()

    local base = tell_data()
    local lod = {
        meshes = mdl_array(vtx_mesh),
        switchPoint = float32(),
    }

    mdl_loadarray(lod, base, "meshes")
    return lod

end

local function vtx_model()

    local base = tell_data()
    local model = {
        lods = mdl_array(vtx_modellod),
    }

    mdl_loadarray(model, base, "lods")
    return model

end

local function vtx_bodypart()

    local base = tell_data()
    local part = {
        models = mdl_array(vtx_model),
    }

    mdl_loadarray(part, base, "models")
    return part

end

local function vtx_header()

    local header = {
        version = int32(),
        vertCacheSize = int32(),
        maxBonesPerStrip = uint16(),
        maxBonesPerTri = uint16(),
        maxBonesPerVert = int32(),
        checksum = int32(),
        numLODs = int32(),
        materialReplacementListOffset = int32(),
        bodyParts = mdl_array( vtx_bodypart ),
    }

    mdl_loadarray(header, 0, "bodyParts")
    return header

end

local function LoadVVD( filename, path, lod, bLoadTangents )

    open_data(filename, path)

    local header = vvd_header()
    local fixups, vertices, tangents

    lod = math.Clamp(lod or 1, 1, header.numLODs)

    if header.numFixups > 0 then
        seek_data( header.fixupTableStart )
        fixups = array_of( vvd_fixup, header.numFixups )
    end
    
    seek_data( header.vertexDataStart )
    vertices = array_of( vvd_vertex, header.numLODVertices[lod] )

    if bLoadTangents then
        seek_data( header.tangentDataStart )
        tangents = array_of( vvd_tangent, header.numLODVertices[lod] )
    end

    if fixups then

        local corrected = table.Copy( vertices )
		local target = 0
		for _, fixup in ipairs( fixups ) do
			if fixup.lod < 0 then continue end

			for i=1, fixup.numVertices do
				corrected[ i + target ] = vertices[ i + fixup.sourceID ]
			end

			target = target + fixup.numVertices
		end
		vertices = corrected

    end

    end_data()

    if tangents then
        assert(#vertices == #tangents, "Tangent -> Vertex mismatch")
        for i=1, #vertices do
            vertices[i].tangent = tangents[i]
        end
    end

    header.vertices = vertices

	return header

end

local function LoadVTX( filename, path )

    open_data(filename, path)
    local header = vtx_header()
    end_data()
    return header

end

STUDIO_ANIM_RAWPOS	= 0x01 // Vector48
STUDIO_ANIM_RAWROT	= 0x02 // Quaternion48
STUDIO_ANIM_ANIMPOS	= 0x04 // mstudioanim_valueptr_t
STUDIO_ANIM_ANIMROT	= 0x08 // mstudioanim_valueptr_t
STUDIO_ANIM_DELTA	= 0x10
STUDIO_ANIM_RAWROT2	= 0x20 // Quaternion64

local function LoadFrameData(numframes, bone, pos)

    print("LOAD FRAMES: " .. numframes)
    local base = tell_data()
    local offsets = array_of(int16, 3)
    local values = {{},{},{}}
    local posscale = bone and bone.posscale or {1,1,1}
    local rotscale = bone and bone.rotscale or {1,1,1}
    for i=1, 3 do
        if offsets[i] ~= 0 then
            local scale = pos and posscale[i] or rotscale[i]
            local k = numframes
            local ptr = base + offsets[i]
            push_data(ptr)
            local span = mdl_span("__")
            local valid = uint8()
            local total = uint8()
            local vt = values[i]

            while total ~= 0 and total <= k do
                k = k - total
                for i=1, total do
                    local value = int16()
                    vt[#vt+1] = value * scale
                end
                valid = uint8()
                total = uint8()
            end
            span:Stop()
            pop_data()
        end
    end

    return values

end

local function LoadAnimBlock(numframes, bones)

    for i=1, 1000 do
        local base = tell_data()
        local bone = bones[uint8()+1]
        local flags = uint8()
        local nextoffset = uint16()
        local rawpos = bit.band(flags, STUDIO_ANIM_RAWPOS) ~= 0
        local rawrot = bit.band(flags, STUDIO_ANIM_RAWROT) ~= 0
        local rawrot2 = bit.band(flags, STUDIO_ANIM_RAWROT2) ~= 0
        local animpos = bit.band(flags, STUDIO_ANIM_ANIMPOS) ~= 0
        local animrot = bit.band(flags, STUDIO_ANIM_ANIMROT) ~= 0
        local delta = bit.band(flags, STUDIO_ANIM_DELTA) ~= 0
        local _rot = nil
        local _pos = nil
        if animrot then _rot = LoadFrameData(numframes, bone, false) end
        if animpos then _pos = LoadFrameData(numframes, bone, true) end
        if rawrot then _rot = quat48() end
        if rawrot2 then _rot = quat64() end
        if rawpos then _pos = vector48() end
        local posrot = {
            _pos = _pos,
            _rot = _rot,
            rawpos = rawpos,
            rawrot = rawrot,
            rawrot2 = rawrot2,
            animpos = animpos,
            animrot = animrot,
            delta = delta,
        }
        --print(bone, flags, nextoffset)
        if rawpos or true then PrintTable(posrot) end
        if nextoffset == 0 then break end
        seek_data(base + nextoffset)
    end

end

local m_vis = {}

local mdl_meta = {}
mdl_meta.__index = mdl_meta

function mdl_meta:GetBodyParts()

    return self.bodyparts

end

function mdl_meta:GetMeshMaterial( mesh )

    return self.materials[mesh.material+1]

end

function mdl_meta:GetVertices()

    return self.vvd.vertices

end

local function LoadMDL( filename, path )

    open_data(filename, path)

    local span = mdl_span("header")
    local header = mdl_header()
    span:Stop()

    setmetatable(header, mdl_meta)

    mdl_loadarray(header, 0, "bones")
    mdl_loadarray(header, 0, "bone_controllers")
    mdl_loadarray(header, 0, "hitbox_sets")
    mdl_loadarray(header, 0, "local_anims")
    mdl_loadarray(header, 0, "local_sequences")
    mdl_loadarray(header, 0, "textures")
    mdl_loadarray(header, 0, "cdtextures")
    mdl_loadarray(header, 0, "bodyparts")
    mdl_loadarray(header, 0, "attachments")
    mdl_loadarray(header, 0, "flexrules")
    mdl_loadarray(header, 0, "ikchains")
    mdl_loadarray(header, 0, "mouths")
    mdl_loadarray(header, 0, "poseparams")
    mdl_loadarray(header, 0, "localikautoplaylocks")
    mdl_loadarray(header, 0, "includemodels")
    mdl_loadarray(header, 0, "animblocks")
    mdl_loadarray(header, 0, "flexcontrollerui")
    mdl_loadarray(header, 0, "flexcontrollers")
    mdl_loadarray(header, 0, "flexes")

    print("ANIM BLOCK NAME: " .. header.animblockname)

    local mat_lookup = {}
    header.materials = {}

    for i, tex in ipairs(header.textures) do
        for _, path in ipairs(header.cdtextures) do
            local material = mat_lookup[tex] or Material(path .. tex.name)
            if material and not material:IsError() then
                header.materials[#header.materials+1] = material
            end
        end
    end

    PrintTable(header.bones)


    --[[if datastart == dataend then return nil end

    local size = dataend - datastart
    print("DATABLOCK SIZE: " .. size .. " READ AT: " .. datastart)
    push_data(datastart)

    local bone = uint8()
    local flags = uint8()
    local nextoffset = uint16()
    print(bone, flags, nextoffset)

    pop_data()]]

    for _, anim in ipairs(header.local_anims) do

        if anim.animblock == 0 then
            print("Anim: " .. anim.name)
            local base = anim.baseptr
            local ptr = base + anim.animindex
            push_data(ptr)
            local span = mdl_span("Anim: " .. anim.name)
            LoadAnimBlock(anim.numframes, header.bones)
            span:Stop()
            pop_data()
        end

    end

    m_vis.array_spans = m_array_spans
    m_vis.size = m_size
    m_vis.ready = true

    end_data()

    if header.animblockname ~= "" then
        print("LOAD ANIM BLOCK")
    end

    for k,v in pairs(header) do
        if type(v) == "table" and v.offset and v.num then
            print( (k .. " : 0x%x | %i"):format( v.offset, v.num ) )
        end
    end

    --PrintTable(header.local_anims)

    return header

end

local function LoadBundle( filename, path )

    local mdl = LoadMDL( filename, path )
    local vvd = LoadVVD( filename:sub(1, -4) .. "vvd", path, 1, true )
    local vtx = LoadVTX( filename:sub(1, -4) .. "dx90.vtx", path )
    assert(mdl.checksum == vtx.checksum)
    assert(mdl.checksum == vvd.checksum)

    mdl.vtx = vtx
    mdl.vvd = vvd

    print(#vvd.vertices .. " verts")

    for i=1, #mdl.bodyparts do
        for j=1, #mdl.bodyparts[i].models do
            local mdl_model = mdl.bodyparts[i].models[j]
            for k=1, #mdl.bodyparts[i].models[j].meshes do
                local mdl_mesh = mdl_model.meshes[k]
                local vtx_mesh = mdl.vtx.bodyParts[i].models[j].lods[1].meshes[k]
                for x,y in pairs(vtx_mesh) do
                    mdl_mesh[x] = y
                end
                local index_offset = mdl_mesh.vertexoffset + mdl_model.vertexindex / vvd_vertex_size
                for l=1, #vtx_mesh.stripgroups do
                    local stripgroup = vtx_mesh.stripgroups[l]
                    local indices = stripgroup.indices
                    for m=1, #indices do
                        indices[m] = indices[m] + index_offset
                    end
                end
            end
        end
    end

    return mdl

end

function LoadModel( filename, path )

    local b,e = xpcall(LoadBundle, function( err )
        print("Error loading mdl: " .. tostring(err))
        debug.Trace()

    end, filename, path)
    return e

end

local function Prof( k, f, ... )

    local s = SysTime()
    local r = f(...)
    local e = SysTime()
    print(k .. " took " .. (e - s) * 1000 .. "ms" )
    return r

end

local mdl_test = "models/Gibs/Fast_Zombie_Legs.mdl"
mdl_test = LocalPlayer():GetModel()
mdl_test = "models/Gibs/HGIBS.mdl"
mdl_test = "models/Lamarr.mdl"
mdl_test = "models/vortigaunt.mdl"
--mdl_test = "models/crow.mdl"
--mdl_test = "models/Alyx.mdl"
--mdl_test = "models/kazditi/protogen/protogen.mdl"
--mdl_test = "models/gman_high.mdl"
--mdl_test = "models/Combine_dropship.mdl"
--mdl_test = "models/Combine_turrets/Floor_turret.mdl"
--mdl_test = "models/combine_camera/combine_camera.mdl"
--mdl_test = "models/AntLion.mdl"
--mdl_test = "models/props_phx/construct/metal_tube.mdl"
mdl_test = "models/dog.mdl"
mdl_test = "models/Zombie/Classic_legs.mdl"
mdl_test = "models/Gibs/Fast_Zombie_Torso.mdl"
mdl_test = "models/Combine_Strider.mdl"
mdl_test = "models/props_junk/wood_crate001a.mdl"
mdl_test = "models/props_lab/frame001a.mdl"
--mdl_test = "models/props_lab/Cleaver.mdl"
--print("LOADING: " .. tostring(mdl_test))
local loaded = Prof( "LoadModel", LoadModel, mdl_test )


hook.Add("PostDrawOpaqueRenderables", "test_mdl", function()

    local vertices = loaded:GetVertices()
    for _, p in ipairs(loaded:GetBodyParts()) do

        for _, m in ipairs(p.models) do

            for _, msh in ipairs(m.meshes) do

                local mat = loaded:GetMeshMaterial(msh)
                if mat == nil then continue end

                render.SetMaterial(mat)

                for _, strip in ipairs(msh.stripgroups) do

                    mesh.Begin( MATERIAL_TRIANGLES, #strip.indices / 3 )

                    for i=1, #strip.indices, 3 do

                        local i0 = strip.indices[i]
                        local i1 = strip.indices[i+1]
                        local i2 = strip.indices[i+2]

                        local v0 = vertices[i0]
                        local v1 = vertices[i1]
                        local v2 = vertices[i2]

                        mesh.Position(v0.position)
                        mesh.Normal(v0.normal)
                        mesh.TexCoord(0, v0.u, v0.v)
                        mesh.UserData(v0.tangent.x, v0.tangent.y, v0.tangent.z, v0.tangent.w)
                        mesh.AdvanceVertex()

                        mesh.Position(v1.position)
                        mesh.Normal(v1.normal)
                        mesh.TexCoord(0, v1.u, v1.v)
                        mesh.UserData(v1.tangent.x, v1.tangent.y, v1.tangent.z, v1.tangent.w)
                        mesh.AdvanceVertex()

                        mesh.Position(v2.position)
                        mesh.Normal(v2.normal)
                        mesh.TexCoord(0, v2.u, v2.v)
                        mesh.UserData(v2.tangent.x, v2.tangent.y, v2.tangent.z, v2.tangent.w)
                        mesh.AdvanceVertex()

                    end

                    mesh.End()

                end

            end

        end

    end

end)

--[[local old_avg = 0
local new_avg = 0
local iters = 10

for i=1, iters do
    local start = SysTime()
    studiomdl.Load( mdl_test )
    local finish = SysTime()
    old_avg = old_avg + ((finish - start)*1000)
end

for i=1, iters do
    local start = SysTime()
    local loaded = LoadModel( mdl_test )
    local finish = SysTime()
    new_avg = new_avg + ((finish - start)*1000)
end

print("OLD MDL LOADER TOOK: " .. (old_avg/iters) .. "ms")
print("NEW MDL LOADER TOOK: " .. (new_avg/iters) .. "ms")]]

--print( LocalPlayer():GetModel() )

hook.Add("HUDPaint", "paint_spans", function()

    --if true then return end
    if not m_vis.ready then return end

    local size = m_vis.size
    local array_spans = m_vis.array_spans
    local height = ScrH() - 100

    surface.SetDrawColor(80,80,80)
    surface.DrawRect(0, 0, 1000, height)

    for _,v in ipairs(array_spans) do

        local x = v[5] * 100
        local y0 = (v[1] / size) * height
        local y1 = (v[2] / size) * height
        if y1 - y0 == 0 then continue end

        surface.SetDrawColor(255,255,255)
        surface.DrawRect(x, y0, 100, y1-y0)

        surface.DrawLine(x + 100, y0, 500, y0)
        draw.SimpleText(v[3] .. ": " .. (v[2] - v[1]) .. "b", "DermaDefault", 510, y0+5, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    end

end)