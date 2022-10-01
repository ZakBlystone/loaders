include("alchemy_toolkit.lua")

if CLIENT then return end

local reader = include("alchemy/common/datareader.lua")
local writer = include("alchemy/common/datawriter.lua")
local quat = setmetatable({x=2, y=4, z=8, w=16}, reader.quat_meta)
local quat2 = setmetatable({x=0.5, y=0.5, z=0.5, w=0.5}, reader.quat_meta)

writer.open_data("datatest.dat")
writer.uint32(120)
writer.uint16(45)
writer.uint8(255)
writer.int32(22020)
writer.int16(5003)
writer.int8(-1)
writer.char('A')
writer.charstr("Hello",16)
writer.float32(2)
--float16
writer.vector32( Vector(2,4,8) )
--vector48
writer.angle32( Angle(2,4,8) )
writer.matrix3x4( Matrix({
    {2,4,8,16},
    {2,4,8,16},
    {2,4,8,16},
    {0,0,0,1},
}))
writer.quat128(quat)
--quat64
writer.quat48(quat2)
writer.array_of(writer.uint16, {1,2,3,4,5})
writer.nullstr("STRUCTURE")

local base = writer.tell_data()
local t = {
    ind0 = writer.indirect_array( writer.uint16, {1,2,3,4,5}, false),
    ind1 = writer.indirect_array( writer.uint16, {1,2,3,4,5}, true),
    name0 = writer.indirect_name("hello world", base),
    name1 = writer.indirect_name("winners don't do drugs", base),
}

writer.write_indirect_array( t, base, "ind0" )
writer.write_indirect_array( t, base, "ind1" )
writer.write_indirect_name( t.name0 )
writer.write_indirect_name( t.name1 )

writer.end_data()


reader.open_data("datatest.dat", "DATA")

local function test(v, e)
    assert(v == e, "Expected: '" .. tostring(e) .. "' got '" .. tostring(v) .. "'")
end

local function testA(v, e)
    assert(#v == #e, "Lengths do not match: " .. #v .. " != " .. #e)
    for i=1, #v do
        assert(v[i] == e[i], "Element[" .. i .. "] mismatch: " .. tostring(v[i]) .. " != " .. tostring(e[i]))
    end
end

test(reader.uint32(), 120)
test(reader.uint16(), 45)
test(reader.uint8(), 255)
test(reader.int32(), 22020)
test(reader.int16(), 5003)
test(reader.int8(), -1)
test(reader.char(), 'A')
test(reader.vcharstr(16), "Hello")
test(reader.float32(), 2)
--float16
test(reader.vector32(), Vector(2,4,8) )
--vector48
test(reader.angle32(), Angle(2,4,8) )
test(reader.matrix3x4(), Matrix({
    {2,4,8,16},
    {2,4,8,16},
    {2,4,8,16},
    {0,0,0,1},
}))
test(reader.quat128(), quat)
--quat64
test(reader.quat48(), quat2)
testA(reader.array_of(reader.uint16, 5), {1,2,3,4,5})
test(reader.nullstr(), "STRUCTURE")

local base = reader.tell_data()
local t = {
    ind0 = reader.indirect_array( reader.uint16, false ),
    ind1 = reader.indirect_array( reader.uint16, true ),
    name0idx = reader.int32(),
    name1idx = reader.int32(),
}

PrintTable(t)

reader.load_indirect_array(t, base, "ind0")
reader.load_indirect_array(t, base, "ind1")
reader.indirect_name(t, base, "name0idx")
reader.indirect_name(t, base, "name1idx")

PrintTable(t)

testA(t.ind0, {1,2,3,4,5})
testA(t.ind1, {1,2,3,4,5})
test(t.name0, "hello world")
test(t.name1, "winners don't do drugs")

reader.end_data()