if true then return end

AddCSLuaFile("bsp3.lua")
AddCSLuaFile("phy3.lua")

include("bsp3.lua")
include("phy3.lua")

if CLIENT then

	local requested_lumps = {
		bsp3.LUMP_PLANES,
		bsp3.LUMP_VERTEXES,
		bsp3.LUMP_FACES,
		bsp3.LUMP_EDGES,
		bsp3.LUMP_SURFEDGES,
		bsp3.LUMP_NODES,
		bsp3.LUMP_LEAFS,
		bsp3.LUMP_MODELS,
		bsp3.LUMP_LEAFFACES,
		bsp3.LUMP_LEAFBRUSHES,
		bsp3.LUMP_BRUSHES,
		bsp3.LUMP_BRUSHSIDES,
		bsp3.LUMP_DISPINFO,
		bsp3.LUMP_DISP_VERTS,
		bsp3.LUMP_DISP_TRIS,
	}
	
	local bsp_data = bsp3.LoadBSP( "maps/" .. game.GetMap() .. ".bsp", requested_lumps )





    if true then return end

    local bsp_data = bsp3.LoadBSP( "maps/" .. game.GetMap() .. ".bsp", {
        bsp3.LUMP_PHYSCOLLIDE,
		bsp3.LUMP_PLANES,
		bsp3.LUMP_NODES,
		bsp3.LUMP_MODELS,
		bsp3.LUMP_LEAFS,
		bsp3.LUMP_LEAF_AMBIENT_LIGHTING,
		bsp3.LUMP_LEAF_AMBIENT_INDEX,
    })

    local phys = bsp_data.physcollide
    local vcollides = {}
    for k, p in ipairs(phys) do
        vcollides[#vcollides+1] = phy3.LoadVCollideString(p.vcollide, p.count)
    end

    local vcollide = phy3.LoadVCollideFile("models/props_c17/FurnitureSink001a.phy")
	local linear_to_screen = {}
	local tex_gamma_table = {}

	local function LinearToScreenGamma( f )
		local i = math.floor( 0.5 + math.min( math.max(f * 1023, 0), 1023 ) + 1 )
		return linear_to_screen[i]
	end

	local function TexLightToLinear( c, e )
		return c * (2 ^ e) / 255
	end

	local function BuildGammaTable( gamma, texGamma, brightness, overbright )

		local g = 1 / math.min(gamma, 3)
		local g1 = texGamma * g
		local g3 = 0

		if brightness <= 0 then 
			g3 = 0.125
		elseif brightness > 1.0 then
			g3 = 0.05
		else
			g3 = 0.125 - (brightness*brightness) * 0.075
		end

		for i=0, 255 do
			local inf = math.Clamp( 255 * (( i/255 ) ^ g1), 0, 255 )
			tex_gamma_table[i+1] = inf
		end

		for i=0, 1023 do
			local f = i/1023
			if brightness > 1.0 then f = f * brightness end
			if f <= g3 then
				f = (f / g3) * 0.125
			else
				f = 0.125 + ((f - g3) / (1.0 - g3)) * 0.875
			end

			local inf = math.Clamp( 255 * ( f ^ g ), 0, 255 )
			linear_to_screen[i+1] = inf
		end

	end

	local function ColorRGBExp32(r,g,b,e)
		r = 255 * TexLightToLinear(r, e)
		g = 255 * TexLightToLinear(g, e)
		b = 255 * TexLightToLinear(b, e)
		r = LinearToScreenGamma(r)
		g = LinearToScreenGamma(g)
		b = LinearToScreenGamma(b)
		return r,g,b
	end

	BuildGammaTable(2.2, 2.2, 0, 2.0)

	hook.Add("HUDPaint", "leaftest", function()
	
		--[[local pos = EyePos()
		local leaf = bsp_data:GetLeafAtPos( pos )
		local over = 10000
		for sample in bsp_data:LeafAmbientSamples(leaf) do
			local p = sample.pos:ToScreen()
			surface.SetDrawColor(255,255,255)
			surface.DrawRect(p.x, p.y, 2, 2)
		end
		print(leaf.ambient.ambientSampleCount)]]

	end)

	local cube = {
		Vector(1,0,0),
		Vector(-1,0,0),
		Vector(0,1,0),
		Vector(0,-1,0),
		Vector(0,0,1),
		Vector(0,0,-1)
	}

	local function CubeColor(face)
		local r,g,b,e = unpack(face)
		return bsp3.CVT_ColorRGBExp32(r,g,b,e)
	end

    hook.Add("PostDrawOpaqueRenderables", "vcollide_test", function( bDrawingDepth, bDrawingSkybox, isDraw3DSkybox )

		if true then return end

        --phy3.DrawVCollide( vcollide )

		--phy3.DrawVCollide( vcollides[1] )
		if isDraw3DSkybox or bDrawingSkybox then return end

		local pos = EyePos()
		local leaf = bsp_data:GetLeafAtPos( pos )
		local size = 12.5
		local avg = {}
		local den = {}
		for i=1, 6 do avg[i] = {0,0,0} end
		for i=1, 6 do den[i] = 0 end

		for sample in bsp_data:LeafAmbientSamples(leaf) do
			for i=1, #cube do
				local dist = sample.pos:Distance(pos)
				local c = sample.cube[i]
				local r,g,b = CubeColor(c)
				render.DrawQuadEasy( sample.pos + cube[i] * size, cube[i], size*2, size*2, Color(r,g,b), 0 )
				r = (r / dist)
				g = (g / dist)
				b = (b / dist)
				avg[i][1] = avg[i][1] + r
				avg[i][2] = avg[i][2] + g
				avg[i][3] = avg[i][3] + b
				den[i] = den[i] + 1/dist
			end
		end

		for i=1, 6 do
			for j=1, 3 do
				avg[i][j] = avg[i][j] / den[i]
			end
		end

		--[[for sample in bsp_data:LeafAmbientSamples(leaf) do
			local dist = sample.pos:Distance(pos)
			max_dist = math.max(max_dist, dist)
		end
		for sample in bsp_data:LeafAmbientSamples(leaf) do
			local dist = max_dist - sample.pos:Distance(pos)
			--max_dist = math.max(max_dist, dist)
			total_dist = total_dist + dist
			num = num + 1
		end
		for sample in bsp_data:LeafAmbientSamples(leaf) do

			render.SetColorMaterial()

			local dist = max_dist - sample.pos:Distance(pos)
			local frac = (dist / total_dist)
			for i=1, #cube do
				local c = sample.cube[i]
				local r,g,b = CubeColor(c)
				avg[i][1] = avg[i][1] + r * frac
				avg[i][2] = avg[i][2] + g * frac
				avg[i][3] = avg[i][3] + b * frac
				render.DrawQuadEasy( sample.pos + cube[i] * size, cube[i], size*2, size*2, Color(r,g,b), 0 )
			end
			acc = acc + frac

			cam.Start3D2D( sample.pos, Angle(0,0,0), 0.5 )
			draw.SimpleText( tostring(frac), "DermaDefault", 0, 0, Color(255,255,255) )
			cam.End3D2D()

		end]]

		--print(acc)

		render.SetColorMaterial()

		local dpos = pos + EyeAngles():Forward() * 50
		for i=1, 6 do
			render.DrawQuadEasy( dpos + cube[i] * size, cube[i], size*2, size*2, Color(avg[i][1],avg[i][2],avg[i][3]), 0 )
		end

    end)


end

if true then return end

--[[local bsp_data = LoadBSP( "maps/" .. game.GetMap() .. ".bsp", {
	LUMP_PLANES
})]]

--[[local bsp_data = LoadBSP( "maps/" .. game.GetMap() .. ".bsp", {
	LUMP_PLANES,
	LUMP_VERTEXES,
	LUMP_FACES,
	LUMP_EDGES,
	LUMP_SURFEDGES,
	LUMP_NODES,
	LUMP_LEAFS,
	LUMP_MODELS,
	LUMP_LEAFFACES,
	LUMP_LEAFBRUSHES,
	LUMP_BRUSHES,
	LUMP_BRUSHSIDES,
	LUMP_FACEIDS,
	LUMP_DISPINFO,
	LUMP_DISP_VERTS,
	LUMP_DISP_TRIS,
	LUMP_ENTITIES, 
	LUMP_TEXDATA,
	LUMP_TEXDATA_STRING_DATA,
	LUMP_TEXDATA_STRING_TABLE,
	LUMP_OCCLUSION,
	LUMP_LIGHTING,
	LUMP_AREAS,
	LUMP_AREAPORTALS,
	LUMP_WORLDLIGHTS,
	LUMP_VERTNORMALS,
	LUMP_VERTNORMALINDICES,
	LUMP_LEAFWATERDATA,
	LUMP_OVERLAYS,
	LUMP_LEAFMINDISTTOWATER,
	LUMP_FACE_MACRO_TEXTURE_INFO,
	LUMP_LEAF_AMBIENT_LIGHTING,
	LUMP_LEAF_AMBIENT_INDEX,
	LUMP_MAP_FLAGS,
	LUMP_OVERLAY_FADES,
	LUMP_WATEROVERLAYS,
	LUMP_CUBEMAPS,
	LUMP_GAME_LUMP,
	LUMP_PRIMITIVES,
	LUMP_PRIMVERTS,
	LUMP_PRIMINDICES,
	LUMP_CLIPPORTALVERTS,
	LUMP_PAKFILE} )]]


--[[local bsp_data = LoadBSP( "maps/" .. game.GetMap() .. ".bsp", {
	LUMP_PAKFILE,
	--LUMP_GAME_LUMP,
})

local data = bsp_data:ReadPakFile("materials/maps/ctf_2fort/nature/blendgroundtogravel001_wvt_patch.vmt")
file.Write("lzma_temp.dat", data)]]

if CLIENT then

	if true then return end

	local wire_mat = CreateMaterial("wire_test", "Wireframe", {

	})

	local bsp_data = LoadBSP( "maps/gm_genesis.bsp", {
		LUMP_PLANES,
		LUMP_VERTEXES,
		LUMP_FACES,
		LUMP_ORIGINALFACES,
		LUMP_EDGES,
		LUMP_SURFEDGES,
		LUMP_LEAFFACES,
		LUMP_LEAFS,
		LUMP_NODES,
		LUMP_MODELS,
		LUMP_VISIBILITY,
		--LUMP_GAME_LUMP,
	})	

	local mesh_position = mesh.Position
	local mesh_advance = mesh.AdvanceVertex
	hook.Add("HUDPaint", "map_render_test", function()

		if true then return end
	
		local drawn = {}

		local forward = LocalPlayer():GetAimVector()
		local cam_ang = EyeAngles() --Angle(0,0,0)
		local cam_pos = EyePos() --Vector(0,0,30)

		cam.Start3D(cam_pos, cam_ang, nil, 0, 0, 512, 512)

		--render.SetMaterial(wire_mat)
		render.SetColorMaterial()

		local function draw_leaf(l, mode)

			for _,f in ipairs(l.faces) do
				if cam_pos:Dot(f.plane.normal) - f.plane.dist < 0 then continue end
				if f.origFace then f = f.origFace end
				if drawn[f] then continue end
				drawn[f] = true

				mesh.Begin( mode, #f.edges )
				for _,edge in ipairs(f.edges) do
					mesh_position( edge[1] )
					mesh_advance()
				end
				mesh.End()
			end

		end

		local model = bsp_data.models[1]
		local leafs = {}
		bsp_data:GetModelLeafs( model, leafs )

		local vis_clusters = {}
		local current_leaf = bsp_data:GetLeafAtPos( cam_pos )
		if current_leaf ~= nil then
			local vis = bsp_data:UnpackClusterVis( current_leaf.cluster )
			local clusters = bsp_data:GetVisibleClusters(vis)
			for _, cluster in ipairs(clusters) do
				vis_clusters[cluster] = true
			end
		end

		local size = model.maxs - model.mins
		local longest = math.max(size.x, size.y, size.z)

		local mtx = Matrix()
		--mtx:SetScale( (Vector(1,1,1) / longest) * 32 )
		cam.PushModelMatrix(mtx)

		render.SetColorMaterial()

		render.OverrideColorWriteEnable(true, false)
		render.OverrideDepthEnable(true, true)
		for _, leaf in ipairs(leafs) do
			if not vis_clusters[leaf.cluster] then continue end
			draw_leaf( leaf, MATERIAL_POLYGON )
		end
		render.OverrideColorWriteEnable(false, false)
		render.OverrideDepthEnable(false, false)

		drawn = {}
		render.SetMaterial(wire_mat)
		for _, leaf in ipairs(leafs) do
			if not vis_clusters[leaf.cluster] then continue end
			draw_leaf( leaf, MATERIAL_LINE_LOOP )
		end

		cam.PopModelMatrix()

		cam.End3D()

	end)

end