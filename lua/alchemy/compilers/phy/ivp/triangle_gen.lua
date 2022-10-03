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

local utils = include("../../../common/utils.lua")
local ll_insert = utils.ll_insert
local ll_remove = utils.ll_remove

-- POINT
local meta = {}
meta.__index = meta

function meta:Init(point_num)
	self.v = Vector(0,0,0)
	self.point_num = point_num
	self.was_reached = false
	self.line_ref = nil
	return self
end

function meta:DistSqr(other)
	return self.v:DistToSqr(other.v)
end

function meta:Set(x,y,z)
	self.v:SetUnpacked(x,y,z)
end

local function P_Sur_2D_Point(point_num)

	return setmetatable({}, meta):Init(point_num)

end

-- LINE
local meta = {}
meta.__index = meta

local P_Pop_Eps = 0.001
local P_Pop_Too_Flat_Eps = 2.1 * P_Pop_Eps
local P_CROSS_EPS = 0.0001
local P_OVERLAP_EPS = 1E-8
local P_DOUBLE_EPS = 1E-10
local P_CROSS_EPS_QUAD = P_CROSS_EPS * P_CROSS_EPS
local DET_EPS = 0.000000001

function meta:Init(start_point, end_point)
	self.next = nil
	self.prev = nil
	self.start_point = start_point
	self.end_point = end_point
	self.delta_x = end_point.v.x - start_point.v.x
	self.delta_y = end_point.v.y - start_point.v.y
	return self
end

function meta:DistToPoint(p)

	local norm = self.delta_y * self.delta_y + self.delta_x * self.delta_x
	if norm < P_DOUBLE_EPS then
		local dx = self.start_point.v.x - p.v.x
		local dy = self.start_point.v.y - p.v.y
		return dx*dx + dy*dy
	end

	return self:HesseDistToPoint(p) / math.sqrt(norm)

end

function meta:HesseDistToPoint(p)

	local hesse_dist = 
		self.delta_y * ( self.start_point.v.x - p.v.x ) +
		self.delta_x * ( p.v.y - self.start_point.v.y )

	return hesse_dist

end

function meta:PointLiesToTheLeft(p)

	local hesse_dist = self:HesseDistToPoint(p)
	if hesse_dist <= P_DOUBLE_EPS then return 0 end
	if hesse_dist <= P_Pop_Too_Flat_Eps then return 2 end
	return 1

end

function meta:HasPoints(point_a, point_b)

	if point_b == nil then
		return self.start_point == point_a or self.end_point == point_a
	end

	if self.start_point == point_a and self.end_point == point_b then 
		return true 
	end
	if self.end_point == point_a and self.start_point == point_b then 
		return true 
	end
	return false

end

function meta:PointLiesInInterval(p)

	local abs_delta = math.abs( self.delta_x )
	if abs_delta < P_OVERLAP_EPS then
		local dx = self.delta_x > 0 and 1 or -1
		local point_delta = (p.v.x - self.start_point.v.x) * dx
		if point_delta > P_CROSS_EPS and point_delta < abs_delta - P_CROSS_EPS then
			return true
		end
		return false
	end

	local abs_delta = math.abs( self.delta_y )
	if abs_delta < P_OVERLAP_EPS then
		local dy = self.delta_y > 0 and 1 or -1
		local point_delta = (p.v.y - self.start_point.v.y) * dy
		if point_delta > P_CROSS_EPS and point_delta < abs_delta - P_CROSS_EPS then
			return true
		end
		return false
	end

	return false

end

function meta:OverlapsWithLine(other)

	local abs_delta = math.abs( self.delta_x )
	if abs_delta < P_OVERLAP_EPS then
		local u_lower, u_higher
		if self.delta_x > 0.0 then
			u_lower = self.start_point.v.x
			u_higher = self.end_point.v.x
		else
			u_lower = self.end_point.v.x
			u_higher = self.start_point.v.x
		end
		u_lower = u_lower + P_OVERLAP_EPS
		u_higher = u_higher - P_OVERLAP_EPS
		local v_start = other.start_point.v.x
		local v_end = other.end_point.v.x
		if (v_start <= u_lower and v_end <= u_lower) or 
		   (v_start >= u_higher and v_end >= u_higher) then
			   return false end
		return true
	end

	local abs_delta = math.abs( self.delta_y )
	if abs_delta < P_OVERLAP_EPS then
		local u_lower, u_higher
		if self.delta_y > 0.0 then
			u_lower = self.start_point.v.y
			u_higher = self.end_point.v.y
		else
			u_lower = self.end_point.v.y
			u_higher = self.start_point.v.y
		end
		u_lower = u_lower + P_OVERLAP_EPS
		u_higher = u_higher - P_OVERLAP_EPS
		local v_start = other.start_point.v.y
		local v_end = other.end_point.v.y
		if (v_start <= u_lower and v_end <= u_lower) or 
		   (v_start >= u_higher and v_end >= u_higher) then
			   return false end
		return true
	end

	return other:PointLiesInInterval(self.start_point)

end

function meta:IsCrossingLine(other)

	local u_dx = self.delta_x
	local u_dy = self.delta_y
	local v_dx = other.delta_x
	local v_dy = other.delta_y

	local d = v_dx * u_dy - u_dx * v_dy
	if math.abs(d) < DET_EPS then
		
		if math.abs( self:DistToPoint( other.start_point ) ) < P_CROSS_EPS_QUAD then
			return self:OverlapsWithLine(other)
		else
			return false
		end

	end

	if (self.start_point == other.end_point) or
	   (self.start_point == other.start_point ) or 
	   (self.end_point == other.start_point ) or
	   (self.end_point == other.end_point ) then 
		return false end

	local o_dx = other.start_point.v.x - self.start_point.v.x
	local o_dy = other.start_point.v.y - self.start_point.v.y

	local left_border, right_border
	if d > 0 then
		left_border = 0
		right_border = d
	else
		left_border = d
		right_border = 0
	end

	local u_t = v_dx * o_dy - v_dy * o_dx
	if u_t < left_border or u_t > right_border then return false end
	local v_t = u_dx * o_dy - u_dy * o_dx
	if v_t < left_border or v_t > right_border then return false end

	return true

end

local function P_Sur_2D_Line(start_point, end_point)

	return setmetatable({}, meta):Init(start_point, end_point)

end

-- TRIANGLE
local function P_Sur_2D_Triangle(pn0, pn1, pn2)
	return 
	{
		next = nil,
		prev = nil,
		point_nums = {pn0, pn1, pn2},
	}
end

local meta = {}
meta.__index = meta

function meta:Init( tetra, surf )
	self.tetra = tetra
	self.surf = surf
	self.first_line = nil
	self.first_triangle = nil

	return self
end

function meta:CalcLineRepresentation()

	local points = {}
	local tetra = self.tetra
	local surf = self.surf
	local norm = surf.normal
	local max_coord = 1
	local max_coord_val = math.abs( norm.x )
	if math.abs( norm.y ) > max_coord_val then
		max_coord_val = math.abs( norm.y )
		max_coord = 2
	end
	if math.abs( norm.z ) > max_coord_val then
		max_coord_val = math.abs( norm.z )
		max_coord = 3
	end

	local k0,k1 = 2,3
	if max_coord == 2 then k0,k1 = 1,3 end
	if max_coord == 3 then k0,k1 = 1,2 end

	local is_mirrored = 0
	if norm[max_coord] < 0.0 then is_mirrored = 1 end
	if max_coord == 2 then is_mirrored = 1-is_mirrored end

	--[[print("SURF LINES: " .. is_mirrored)
	for i=#surf.lines, 1, -1 do
		local line_num = surf.lines[i]
		local line = tetra.template.lines[line_num]
		local reverse = surf.reverse_line[i]
		if is_mirrored ~= 0 then reverse = 1-reverse end
		local start_point_num = line[ reverse + 1 ]
		local end_point_num = line[ (1-reverse) + 1 ]
		print(start_point_num .. " -> " .. end_point_num .. "  " .. (reverse+1) .. " " .. ((1-reverse)+1) )
		print("\t", tetra.points[start_point_num].v[k0], tetra.points[end_point_num].v[k0])
		print("\t", tetra.points[start_point_num].v[k1], tetra.points[end_point_num].v[k1])
	end]]


	for i=#surf.lines, 1, -1 do

		local line_num = surf.lines[i]
		local line = tetra.template.lines[line_num]
		local reverse = surf.reverse_line[i]
		if is_mirrored ~= 0 then reverse = 1-reverse end
		local start_point_num = line[ reverse + 1 ]
		local end_point_num = line[ (1-reverse) + 1 ]

		local start_point = points[start_point_num]
		if start_point == nil then
			start_point = P_Sur_2D_Point(start_point_num)
			points[start_point_num] = start_point
		end
		start_point:Set( 
			tetra.points[start_point_num].v[k0],
			tetra.points[start_point_num].v[k1],
			0)

		local end_point = points[end_point_num]
		if end_point == nil then
			end_point = P_Sur_2D_Point(end_point_num)
			points[end_point_num] = end_point
		end
		end_point:Set( 
			tetra.points[end_point_num].v[k0],
			tetra.points[end_point_num].v[k1],
			0)

		local td_line = P_Sur_2D_Line(start_point, end_point)
		start_point.line_ref = td_line

		self.first_line = ll_insert(self.first_line, td_line)

	end

end

local function CountReachable( point )

	local reached_counter = 0
	while point and not point.was_reached do
		point.was_reached = true
		reached_counter = reached_counter + 1
		point = point.line_ref.end_point
	end

	return reached_counter

end

function meta:CalcTriangleRepresentation()

	local has_islands = false
	local triangle_count = 0
	local n_lines = #self.surf.lines
	local reached_points_counter = CountReachable( self.first_line.start_point )
	--print("REACHED: " .. reached_points_counter .. "/" .. n_lines)

	if reached_points_counter < n_lines then
		has_islands = true
	end
	--print("HAS ISLANDS: " .. tostring(has_islands))
	has_islands = true

	--[[local l = self.first_line
	while l ~= nil do
		print(l.start_point.v, l.end_point.v)
		l = l.next
	end]]
	--error("NYI")

	local loop_counter = 0
	local td_base_line = nil
	while self.first_line ~= nil do
		local td_lines = {}
		loop_counter = loop_counter + 1
		td_base_line = self.first_line

		--print("Looped: " .. loop_counter)
		if loop_counter > 100 then error("Cannot Convert") end

		local point_a = td_base_line.start_point
		local point_b = td_base_line.end_point
		local td_point_line = self.first_line
		while td_point_line ~= nil do 
			local point_c = td_point_line.start_point
			td_lines[#td_lines+1] = {
				td_point_line,
				point_c:DistSqr(point_a) + point_c:DistSqr(point_b),
			}
			td_point_line = td_point_line.next
		end
		table.sort(td_lines, function(a,b) return a[2] < b[2] end)

		while #td_lines > 0 do
			td_point_line = td_lines[1][1]
			table.remove(td_lines, 1)

			if td_point_line == td_base_line then continue end
			if td_point_line.start_point == td_base_line.end_point then continue end
			--print("Trying point " .. td_point_line.start_point.point_num)

			local point_c = td_point_line.start_point
			local dist_flag = td_base_line:PointLiesToTheLeft(point_c)
			if dist_flag == 1 then
				--print("Lies on wrong side: " .. #td_lines)
				continue
			elseif dist_flag == 2 then
				--print("Lies too near to triangle: " .. #td_lines)
				continue
			end
			--print("Side OK")

			local skip_this_point = false

			local td_ca_line = P_Sur_2D_Line(point_c, point_a)
			local td_bc_line = P_Sur_2D_Line(point_b, point_c)

			local td_cross_line = self.first_line
			while td_cross_line ~= nil do
				if td_cross_line:HasPoints( point_c, point_a ) then
					if td_cross_line:IsCrossingLine(td_ca_line) then
						skip_this_point = true
						break
					end
				end

				if td_cross_line:HasPoints( point_b, point_c ) then
					if td_cross_line:IsCrossingLine(td_bc_line) then
						skip_this_point = true
						break
					end
				end

				td_cross_line = td_cross_line.next
			end

			if skip_this_point then
				if #td_lines == 0 then
					error("Couldn't find a matching point to baseline!")
				end
				print("Giving up on " .. td_point_line.start_point.point_num .. " because of crossing")
				table.remove(td_lines, 1)
				continue
			end

			if has_islands then
				local td_inside_line = self.first_line
				while td_inside_line ~= nil do
					local sp = td_inside_line.start_point
					if td_base_line:PointLiesToTheLeft(sp) ~= 0 and
					   td_bc_line:PointLiesToTheLeft(sp) ~= 0 and
					   td_ca_line:PointLiesToTheLeft(sp) ~= 0 then
						skip_this_point = true
						break
					   end
					td_inside_line = td_inside_line.next
				end
			end

			if skip_this_point then
				if td_point_line.next == nil then
					error("Couldn't find a matching point to baseline!")
				end
				print("Giving up on " .. td_point_line.start_point.point_num .. " because points inside")
				continue
			end

			local triangle = P_Sur_2D_Triangle(
				point_a.point_num, 
				point_c.point_num, 
				point_b.point_num)

			self.first_triangle = ll_insert(self.first_triangle, triangle)
			self.first_line = ll_remove(self.first_line, td_base_line)

			local ca_removed = false
			local bc_removed = false

			local td_ident_line = self.first_line
			local td_ident_line_next = nil
			while td_ident_line ~= nil do
				td_ident_line_next = td_ident_line.next

				if td_ident_line:HasPoints(point_c, point_a) then
					--print("REMOVED LINE: " .. td_ident_line.start_point.point_num)
					self.first_line = ll_remove(self.first_line, td_ident_line)
					ca_removed  = true
					td_ident_line = nil
				elseif td_ident_line:HasPoints(point_c, point_b) then
					--print("REMOVED LINE: " .. td_ident_line.start_point.point_num)
					self.first_line = ll_remove(self.first_line, td_ident_line)
					bc_removed = true
					td_ident_line = nil
				end

				td_ident_line = td_ident_line_next
			end

			if not ca_removed then
				--print("Insert CA")
				self.first_line = ll_insert(self.first_line, P_Sur_2D_Line(point_a, point_c))
			end

			if not bc_removed then
				--print("Insert BC")
				self.first_line = ll_insert(self.first_line, P_Sur_2D_Line(point_c, point_b))
			end

			break
		end

		--error("NYI")

	end

	--error("NYI")

end

function P_Sur_2D( tetra, surf )

	return setmetatable({}, meta):Init( tetra, surf )

end