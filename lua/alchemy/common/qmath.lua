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

quat_meta = {}
quat_meta.__index = quat_meta
quat_meta.__tostring = function(s) 
	return string.format("%0.2f, %0.2f, %0.2f, %0.2f", s.x, s.y, s.z, s.w)
end
quat_meta.__eq = function(a,b)
	return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w
end

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

local deg_2_rad = math.pi / 180
function quat_meta:FromAngles(angles)

	local p,y,r = angles:Unpack()
	p = p * deg_2_rad
	y = y * deg_2_rad
	r = r * deg_2_rad

	local sp = math.sin(p * 0.5)
	local cp = math.cos(p * 0.5)

	local sy = math.sin(y * 0.5)
	local cy = math.cos(y * 0.5)

	local sr = math.sin(r * 0.5)
	local cr = math.cos(r * 0.5)

	local srXcp = sr * cp
	local crXsp = cr * sp

	self.x = srXcp*cy-crXsp*sy; // X
	self.y = crXsp*cy+srXcp*sy; // Y

	local crXcp = cr * cp
	local srXsp = sr * sp;

	self.z = crXcp*sy-srXsp*cy; // Z
	self.w = crXcp*cy+srXsp*sy; // W (real component)

	return self

end

function quat_meta:FromMatrix(m)

	return self:FromAngles( m:GetAngles() )

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

function quat(x,y,z,w)

    return setmetatable( {
        x = x or 0,
        y = y or 0,
        z = z or 0,
        w = w or 0,
    }, quat_meta)

end

return __lib