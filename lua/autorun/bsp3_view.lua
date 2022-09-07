if true then return end

include("bsp3.lua")

function AtlasPacker(w, h)

    local free = { x=0, y=0, w=w, h=h }
    return function(width, height)

        local node, prev = free, nil
        while node ~= nil do
            if width <= node.w and height <= node.h then break end
            prev, node = node, node.next
        end
        if node == nil then return end
    
        local rwidth = node.w - width
        local rheight = node.h - height
        local left, right
    
        if rwidth >= rheight then
            left = { x=node.x, y=node.y + height, w=width, h=rheight }
            right = { x=node.x + width, y=node.y, w=rwidth, h=node.h }
        else
            left = { x=node.x + width, y=node.y, w=rwidth, h=height }
            right = { x=node.x, y=node.y + height, w=node.w, h=rheight }
        end
    
        if prev then prev.next = left else free = left end
        left.next = right
        right.next = node.next
        node.w, node.h, node.next = width, height, nil
        return node

    end

end

if CLIENT then

    local LIGHTMAP_PAGE_SIZE = 1024
    if true then return end

    for _, m in ipairs(G_BSP_MESHES or {}) do m:Destroy() end
    G_BSP_MESHES = {}

    local map_name = game.GetMap()
    --map_name = "gm_fork"
    --map_name = "gm_testarea"
    --map_name = "ctf_2fort"
    --map_name = "gm_genesis"
    --map_name = "gm_flatgrass"
    map_name = "gm_construct"

    local bsp_data = bsp3.LoadBSP( "maps/" .. map_name .. ".bsp", {
        bsp3.LUMP_PLANES,
        bsp3.LUMP_VERTEXES,
        bsp3.LUMP_VISIBILITY,
        bsp3.LUMP_NODES,
        bsp3.LUMP_LEAFS,
        bsp3.LUMP_FACES,
        bsp3.LUMP_EDGES,
        bsp3.LUMP_SURFEDGES,
        bsp3.LUMP_MODELS,
        bsp3.LUMP_LEAFFACES,
        bsp3.LUMP_TEXINFO,
        bsp3.LUMP_TEXDATA,
        bsp3.LUMP_TEXDATA_STRING_DATA,
        bsp3.LUMP_PAKFILE,
        bsp3.LUMP_DISPINFO,
        bsp3.LUMP_DISP_VERTS,
        bsp3.LUMP_DISP_TRIS,
        bsp3.LUMP_LIGHTING,
        bsp3.LUMP_LIGHTING_HDR,
    })

    local bsp_material = CreateMaterial( "bsp_material" .. RealTime(), "LightmappedGeneric", {
        ["$basetexture"] = "dev/dev_measuregeneric01b",
        ["$model"] = 0,
        ["$translucent"] = 0,
        ["$ignorez"] = 0,
        ["$vertexcolor"] = 0,
        ["$vertexalpha"] = 0,
    })

    local disp_material = CreateMaterial( "disp_material" .. RealTime(), "WorldVertexTransition", {
        ["$basetexture"] = "dev/dev_measuregeneric01b",
        ["$basetexture2"] = "dev/dev_measuregeneric01",
    })

    local function CreateVertexLitTexture( texture )

        return CreateMaterial( "bsp_material_" .. texture, "UnLitGeneric", {
            ["$basetexture"] = texture,
            ["$model"] = 1,
            ["$translucent"] = 1,
            ["$ignorez"] = 0,
            ["$vertexcolor"] = 1,
            ["$vertexalpha"] = 1,
        })

    end

    local function CreateLightmappedTexture( texture )

        return CreateMaterial( "bsp_material_lmx_" .. texture, "LightmappedGeneric", {
            ["$basetexture"] = texture,
        })

    end

    local function GetCorrectTexDataMaterial( texdata )

        -- Some texdata materials are patches which are stored in the bsp pak
        -- These patches are used to append cubemaps, but we don't really care about those right now
        -- Resolve the patches to their root materials
        local material = texdata.material
        local mlookup = "materials/" .. material .. ".vmt"
        if string.find(texdata.material, "maps/") and bsp_data:PakContains( mlookup ) then

            local m = bsp_data:ReadPakFile( mlookup ):match([["include"%s+"([^"]+)"]])
            if m then
                m = m:gsub("materials/", ""):sub(1, -5)
                material = m
            end

        end

        return string.lower(material)

    end

    local function GetAllUsedFaceMaterials( model )

        local leafs = {}
        local mh = {}
        local materials = {}
        bsp_data:GetModelLeafs( model, leafs )

        for _,l in ipairs(leafs) do
            for _,f in ipairs(l.faces) do
                local m = GetCorrectTexDataMaterial( f.texinfo.texdata )
                if not mh[m] then mh[m],materials[#materials+1] = true, m end
            end
        end
        return materials

    end

    PrintTable( GetAllUsedFaceMaterials( bsp_data.models[1] ) )

    local function TriangulateFace( face, lm_node )

        local texinfo = face.texinfo
        local texdata = texinfo.texdata
        local function Vertex( pos )
            local u,v = texinfo.textureVecs:GetUV( pos )
            local lu, lv = texinfo.lightmapVecs:GetUV( pos )
            lu = lu - face.lightmaptextureminsinluxels[1] + 0.5
            lv = lv - face.lightmaptextureminsinluxels[2] + 0.5
            lu = (lu + lm_node.x) / LIGHTMAP_PAGE_SIZE
            lv = (lv + lm_node.y) / LIGHTMAP_PAGE_SIZE
            mesh.Position(pos)
            mesh.TexCoord(0, u / texdata.width, v / texdata.height)
            mesh.TexCoord(1, lu, lv)
            mesh.Normal( face.plane.normal )
            mesh.AdvanceVertex()
        end

        for i=2, #face.edges do
            local edge = face.edges[i]
            Vertex( face.edges[1][1] )
            Vertex( edge[1] )
            Vertex( edge[2] )
        end

    end

    local recomputed = {}

    local function MakeClusterMeshes( cluster, lightmap )

        local leafs = bsp_data:GetClusterLeafs( cluster )
        local meshes = {}
        local matLookup = {}
        local materialFaces = {}
        for _, l in ipairs(leafs) do
            for _, f in ipairs(l.faces) do

                local texinfo = f.texinfo
                local texdata = texinfo.texdata
                local material = GetCorrectTexDataMaterial( texdata )
                local faceList = nil

                if not matLookup[material] then
                    matLookup[material] = #materialFaces+1
                    materialFaces[#materialFaces+1] = { material = material, triCount = 0 }
                end

                local faceList = materialFaces[ matLookup[material] ]
                faceList.triCount = faceList.triCount + #f.edges
                faceList[#faceList+1] = f
            end
        end

        local out = {}
        for _, faces in ipairs( materialFaces ) do

            local material = faces.material
            local mat = Material(material)
            local msh = Mesh(mat)

            if not recomputed[material] then
                mat:Recompute()
                recomputed[material] = true
            end

            mesh.Begin( msh, MATERIAL_TRIANGLES, faces.triCount + 100 )

            local b,e = pcall( function()

                for _, f in ipairs(faces) do
                    local lm_node = lightmap.nodes[ lightmap.lookup[f.id] ]
                    TriangulateFace(f, lm_node)
                end

            end)

            mesh.End()

            if not b then assert(false, e) end

            local cluster_mesh = {
                msh = msh,
                material = mat,
                texture = material,
                vertex_lit = CreateVertexLitTexture( material ),
                lightmapped = CreateLightmappedTexture( material ),
            }

            out[#out+1] = cluster_mesh

        end

        return out

    end

    local function MakeDisplacementMeshes( lightmaps )

        local out = {}

        for _, disp in ipairs(bsp_data.displacements or {}) do

            local face = disp.face
            local texinfo = face.texinfo
            local texdata = texinfo.texdata
            local material = GetCorrectTexDataMaterial( texdata )
            local mat = Material( material )
            local lm_node = lightmaps[ face.id ]

            local function Vertex( pos, alpha )
                
                local u,v = texinfo.textureVecs:GetUV( pos )
                local lu, lv = texinfo.lightmapVecs:GetUV( pos )
                lu = lu - face.lightmaptextureminsinluxels[1] + 0.5
                lv = lv - face.lightmaptextureminsinluxels[2] + 0.5
                lu = (lu + lm_node.x) / LIGHTMAP_PAGE_SIZE
                lv = (lv + lm_node.y) / LIGHTMAP_PAGE_SIZE

                mesh.Position(pos)
                mesh.Color(1,1,1,alpha)
                mesh.Normal(face.plane.normal)
                mesh.TexCoord(0, u / texdata.width, v / texdata.height)
                mesh.TexCoord(1, lu, lv)
                mesh.AdvanceVertex()

            end

            if not recomputed[material] then
                mat:Recompute()
                recomputed[material] = true
            end

            local msh = Mesh( mat )
            mesh.Begin( msh, MATERIAL_TRIANGLES, #disp.indices / 3 )

            local b,e = pcall( function()

            local verts = {}
            for _, idx in ipairs(disp.indices) do

                local pos = disp.positions[idx]
                verts[#verts+1] = Vertex( pos, disp.alphas[idx] )

            end

            end)

            mesh.End()

            if not b then assert(false, e) end

            if msh:IsValid() then
                G_BSP_MESHES[#G_BSP_MESHES+1] = msh
            end

            out[#out+1] = {
                vertex_lit = CreateVertexLitTexture( material ),
                material = mat,
                msh = msh,
                lm_page = lm_node.page,
            }

        end

        return out

    end

    local function AllocateClusterLightmapNodes( cluster, page )

        local lm_data = {
            nodes = {},
            lookup = {},
        }

        local packer = page.packer
        local leafs = bsp_data:GetClusterLeafs( cluster )
        for _, l in ipairs(leafs) do
            for _, f in ipairs(l.faces) do
                local width = f.lightmaptexturesizeinluxels[1] + 1
                local height = f.lightmaptexturesizeinluxels[2] + 1
                local node = packer(width, height)
                if node == nil then return nil end
                node.lightofs = f.lightofs
                lm_data.lookup[f.id] = #lm_data.nodes+1
                lm_data.nodes[#lm_data.nodes+1] = node
            end
        end

        return lm_data

    end

    local cluster_meshes = {}
    local cluster_lightmaps = {}
    local displacement_lightmaps = {}
    local lightmaps_pages = {}

    local function AllocLightmap(size)

        print("Allocate lightmap page: " .. #lightmaps_pages)
        local num = #lightmaps_pages+1
        local lm = {
            packer = AtlasPacker(size, size),
            index = num,
            lightmaps = {},
        }

        lm.target = GetRenderTargetEx(
            "viewer_lightmap_hdr_" .. num .. "x" .. size, 
            size, 
            size, 
            RT_SIZE_NO_CHANGE, 
            0,
            MATERIAL_RT_DEPTH_NONE,
            CREATERENDERTARGETFLAGS_HDR, 
            IMAGE_FORMAT_RGBA16161616F)

        lightmaps_pages[num] = lm
        return lm

    end

    local lm_page = AllocLightmap(LIGHTMAP_PAGE_SIZE)
    for i=0, bsp_data:GetNumClusters()-1 do

        local lm_data = AllocateClusterLightmapNodes(i, lm_page)
        if not lm_data then
            lm_page = AllocLightmap(LIGHTMAP_PAGE_SIZE)
            lm_data = AllocateClusterLightmapNodes(i, lm_page)

            assert(lm_data ~= nil, "Cluster too big for lightmap")
        end

        lm_data.page = lm_page
        lm_page.lightmaps[#lm_page.lightmaps+1] = lm_data
        cluster_lightmaps[i] = lm_data

    end

    for _, disp in ipairs(bsp_data.displacements or {}) do

        local face = disp.face
        local width = face.lightmaptexturesizeinluxels[1] + 1
        local height = face.lightmaptexturesizeinluxels[2] + 1
        local node = lm_page.packer(width, height)
        if node == nil then
            lm_page = AllocLightmap(LIGHTMAP_PAGE_SIZE)
            node = lm_page.packer(width, height)
        end
        node.lightofs = face.lightofs
        displacement_lightmaps[face.id] = node
        lm_page.lightmaps[#lm_page.lightmaps+1] = { nodes = {node} }
        node.page = lm_page

    end

    local function DrawLightmapRough( page, iter )

        local function cc(x)
            return math.max(x + 32, 0)
        end

        for _, lm in ipairs(page.lightmaps) do

            for _, node in ipairs(lm.nodes) do

                local w = node.w
                local h = node.h
                local num = (w*h)
                if iter >= num+1 then continue end
                local pix = 4 * math.floor((w * h) / 2)
                if iter ~= 0 then pix = 4 * math.floor(iter-1) end

                local r,g,b = bsp_data:GetLightmapPixel( node.lightofs + pix )
                if r ~= nil and g ~= nil and b ~= nil then
                --exp = math.pow(exp, 0.5) * 0.5
                surface.SetDrawColor(r,g,b,255)

                if iter == 0 then
                    surface.DrawRect(node.x, node.y, node.w, node.h)
                else
                    local x = (iter-1) % w
                    local y = math.floor((iter-1) / w)
                    surface.DrawRect(node.x + x, node.y + y, 1, 1)
                end

                end

            end

        end

    end

    for i=0, bsp_data:GetNumClusters()-1 do

        cluster_meshes[i] = MakeClusterMeshes(i, cluster_lightmaps[i])

    end

    local disp_meshes = MakeDisplacementMeshes( displacement_lightmaps )

    local function RenderLightMap( page, iter )

        render.PushRenderTarget( page.target )
        cam.Start2D()

        if iter == 0 then render.Clear(2, 2, 2, 255) end
        surface.SetDrawColor(255,255,255)
        DrawLightmapRough(page, iter)

        cam.End2D()
        render.PopRenderTarget()

    end

    for i, page in ipairs(lightmaps_pages) do
        RenderLightMap(page, 0)
    end


    local lm_iter = 1
    hook.Add("HUDPaint", "map_draw_test", function()
    
        for i, page in ipairs(lightmaps_pages) do
            RenderLightMap(page, lm_iter)
        end
        lm_iter = lm_iter + 1

        cam.Start3D()

        local b,e = pcall(function()

            local mtx = Matrix()
            mtx:SetScale(Vector(0.1,0.1,0.1))
            cam.PushModelMatrix(mtx)
        
            render.SetMaterial( bsp_material )
            render.OverrideDepthEnable( true, true )

            for i=0, bsp_data:GetNumClusters()-1 do

                local lightmap_page = cluster_lightmaps[i].page
                --if lightmap_page.index ~= 1 then continue end

                render.SetLightmapTexture( lightmap_page.target )

                if cluster_meshes[i] ~= nil then
                    for _,submesh in ipairs( cluster_meshes[i] ) do

                        --bsp_material:SetTexture( "$basetexture", submesh.texture )
                        --render.SetMaterial( submesh.vertex_lit )

                        render.SetMaterial( submesh.material )
                        --render.SetMaterial( bsp_material )
                        submesh.msh:Draw()
                        
                    end
                end
            end

            for _, disp in ipairs(disp_meshes) do

                render.SetLightmapTexture( disp.lm_page.target )

                render.SetMaterial( disp.material )
                disp.msh:Draw()
            end

            render.OverrideDepthEnable( false, false )
            cam.PopModelMatrix()
        
        end)

        if not b then print(e) end

        cam.End3D()

        --surface.SetDrawColor(255,255,255)
        --DrawLightmapRough(1)

    end)

end