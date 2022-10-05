include("alchemy_toolkit.lua")

alchemy.Init()

local mdl = alchemy.Loader("mdl")
local utils = alchemy.utils

--if true then return end

local function Prof( k, f, ... )

    local s = SysTime()
    local r = f(...)
    local e = SysTime()
    print(k .. " took " .. (e - s) * 1000 .. "ms" )
    return r

end

if CLIENT then

    local function make_cube(strip, size, pos)
        local function q(ang)
            local function av(x,y,z) local v = Vector(x,y,z) v:Rotate(ang) return v end
            local nrm, tgt = av(0,0,1), av(1,0,0)
            strip:Vertex( pos+av(-size,-size,size), nrm, 0, 0, tgt.x,tgt.y,tgt.z,1 )
            strip:Vertex( pos+av(size,-size,size), nrm, 1, 0, tgt.x,tgt.y,tgt.z,1 )
            strip:Vertex( pos+av(size,size,size), nrm, 1, 1, tgt.x,tgt.y,tgt.z,1 )
            strip:Vertex( pos+av(-size,size,size), nrm, 0, 1, tgt.x,tgt.y,tgt.z,1 )
            strip:Triangle(-1,-2,-3)
            strip:Triangle(-4,-1,-3)
        end

        q(Angle(0,0,0))
        q(Angle(90,0,0))
        q(Angle(180,0,0))
        q(Angle(270,0,0))
        q(Angle(0,0,90))
        q(Angle(0,0,-90))
    end

    local ref = mdl.LoadModel("models/n7legion/fortnite/hybrid_player.mdl")
    print("loaded reference ok")

    local renderdata = ref:RenderBodyPart(ref:GetBodyPart(2), 0, {})
    local studiomdl = alchemy.Compiler("mdl")

    local studio = studiomdl.New("gtest7")
    local rootbone = studio:Bone("rootbone")
    --local model = studio:BodyPart():Model()
    --local msh = model:Mesh( "models/flesh" )
    --local stripgroup = msh:StripGroup()
    --local strip0 = stripgroup:Strip()

    print(#ref:GetBodyParts() .. " bodyparts")
    for k, part in ipairs(ref:GetBodyParts()) do
        --if k ~= 1 and k ~= 2 and k ~= 4 then continue end
        --if k ~= 1 and k ~= 4 then continue end
        print("BODYPART: " .. part.name)
        local newPart = studio:BodyPart(part.name)
        for _, model in ipairs(part.models) do
            print(" -> MODEL: " .. model.name)
            local newModel = newPart:Model(model.name)
            for _, msh in ipairs(model.meshes) do
                local renderdata = ref:RenderMesh(msh, 0, {})
                local newMesh = newModel:Mesh( ref:GetMeshMaterial(msh, 0, true) )
                local newStrip = newMesh:StripGroup():Strip()

                local center = utils.compute_center(renderdata.vertices, "position")
                for _, v in ipairs(renderdata.vertices) do
                    newStrip:Vertex(v.position, v.normal, v.u, v.v, 
                    v.tangent.x, v.tangent.y, v.tangent.z, v.tangent.w)
                end
                local indices = renderdata.indices
                for i=1, #indices, 3 do
                    newStrip:Triangle(indices[i], indices[i+1], indices[i+2])
                end

            end
        end
    end

    --[[
    local center = utils.compute_center(renderdata.vertices, "position")
    for _, v in ipairs(renderdata.vertices) do
        strip0:Vertex(v.position - center, v.normal, v.u, v.v, 
        v.tangent.x, v.tangent.y, v.tangent.z, v.tangent.w)
    end
    local indices = renderdata.indices
    for i=1, #indices, 3 do
        strip0:Triangle(indices[i], indices[i+1], indices[i+2])
    end]]

    --make_cube(strip0, 10, Vector(0,0,0))
    --make_cube(strip0, 10, Vector(0,0,40))

    local phys = studio:PhysBone( rootbone )
    phys:SetSurfaceProp("bloodyflesh")
    phys:BuildFromEntireModel()
    studio:Write()
    --studio:Mount("__gtest1")

    --local strip1 = stripgroup:Strip()
    --make_cube(strip1, 30, Vector(200,0,50))

    hook.Add("PostDrawOpaqueRenderables", "test_studio", function()
    
        local mtx = Matrix()
        mtx:SetTranslation(Vector(70,0,0))
        --if true then return end
        cam.PushModelMatrix(mtx)
        studio:Render()
        cam.PopModelMatrix()

    end)

    --if true then return end
    

    local mdl_test = "models/Gibs/Fast_Zombie_Legs.mdl"
    mdl_test = "models/Gibs/HGIBS.mdl"
    --mdl_test = "models/Lamarr.mdl"
    --mdl_test = "models/vortigaunt.mdl"
    --mdl_test = "models/crow.mdl"
    --mdl_test = "models/Alyx.mdl"
    --mdl_test = "models/kazditi/protogen/protogen.mdl"
    --mdl_test = "models/gman_high.mdl"
    --mdl_test = "models/Combine_dropship.mdl"
    --mdl_test = "models/Combine_turrets/Floor_turret.mdl"
    --mdl_test = "models/combine_camera/combine_camera.mdl"
    --mdl_test = "models/AntLion.mdl"
    --mdl_test = "models/dog.mdl"
    --mdl_test = "models/Zombie/Classic_legs.mdl"
    --mdl_test = "models/raptor/aeon_enhanced/aeon.mdl"
    mdl_test = "models/n7legion/fortnite/hybrid_player.mdl"
    --mdl_test = "models/player/LeymiRBA/GrifGrif.mdl" --[this one breaks...]
    --mdl_test = "models/Gibs/Fast_Zombie_Torso.mdl"
    --mdl_test = "models/Combine_Strider.mdl"
    --mdl_test = "models/props_junk/wood_crate001a.mdl"
    --mdl_test = "models/props_junk/PlasticCrate01a.mdl"
    --mdl_test = "models/props_lab/frame001a.mdl"
    --mdl_test = "models/props_lab/Cleaver.mdl"
    --mdl_test = "models/magnusson_device.mdl"
    --mdl_test = "models/antlion_worker.mdl"
    --mdl_test = "models/props_lab/kennel_physics.mdl"
    --mdl_test = "models/props_junk/TrashDumpster02.mdl"

    --mdl_test = "models/props_lab/binderblue.mdl"
    --mdl_test = "models/maxofs2d/companion_doll.mdl"
    --mdl_test = "models/props_phx/construct/metal_plate1.mdl"
    mdl_test = "studio/mdl.dat"

    print("LOADING: " .. tostring(mdl_test))
    local loaded = Prof( "LoadModel", mdl.LoadModel, mdl_test )
    
    if true then
        --[[print(tostring(loaded))
        local keys = {}
        for k,v in pairs(loaded) do`
            keys[#keys+1] = k
        end
        table.sort(keys)
        for _, v in ipairs(keys) do
            print(v .. " : " .. tostring(loaded[v]))
        end]]

        --PrintTable(loaded.bodyparts)

        --PrintTable(loaded.rawheader)
        --MsgC(Color(255,255,255), string.rep("=", 80) .. "\n")
        --utils.print_table(loaded, "model", {"vertices", "indices", "rawheader", "local_sequences", "local_anims"}, 2)

        --utils.print_table(loaded.bodyparts[2], "parts", {"boneStateChanges"}, 100, 8)
        --utils.print_table(loaded.bodyparts[1].models[1].meshes[1].flexes, "model", {}, -1, 5)
        --if loaded.hdr2 then PrintTable(loaded.hdr2) end

        --utils.print_table(loaded.bodyparts, "", {"vertices", "indices"})
        --PrintTable(loaded.bones)
        --PrintTable(loaded.hitbox_sets)
        --print("ANIMS")
        --PrintTable(loaded.local_anims)
        --print("SEQUENCES")
        --PrintTable(loaded.local_sequences)
        --print(loaded.name)
        utils.print_table(loaded.bodyparts, "", {"vertices", "indices"}, -1, 20)
    end

    --PrintTable(loaded.vvd.vertices)
    --PrintTable(loaded.vtx.materialReplacementList)

    --utils.print_table(loaded.phy.data, "", {}, 4)
    
    hook.Add("PostDrawOpaqueRenderables", "test_mdl", function()
    
        --if true then return end
        if not loaded then return end
        --loaded:Render()
        if loaded.phy and false then
            --mdl.DrawVCollide( loaded.phy )
            local solids = loaded.phy.solids
            for k, solid in ipairs(solids) do
                local bone = loaded:FindBone( solid.data.name )
                if bone then
                    cam.PushModelMatrix(bone.invPoseToBone)
                    solid:Render(k)
                    cam.PopModelMatrix()
                else
                    solid:Render(k)
                end
                --print(solid.data.name)
                --utils.print_table(solid.data)
            end
        else
            --print("no phy: " .. CurTime())
        end

        local parts = loaded:GetBodyParts()
        loaded:RenderModel( parts[8].models[2] )
    
    end)
    
    hook.Add("HUDPaint", "paint_spans", function()
    
        if true then return end

        local m_vis = mdl.get_coverage_vis()
        if not m_vis or not m_vis.ready then return end
    
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
    
end