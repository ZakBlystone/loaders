include("alchemy_toolkit.lua")

if true then return end
alchemy.Init()

local mdl = alchemy.Loader("mdl")

--if true then return end

local function Prof( k, f, ... )

    local s = SysTime()
    local r = f(...)
    local e = SysTime()
    print(k .. " took " .. (e - s) * 1000 .. "ms" )
    return r

end

if CLIENT then

    local mdl_test = "models/Gibs/Fast_Zombie_Legs.mdl"
    mdl_test = "models/Gibs/HGIBS.mdl"
    mdl_test = "models/Lamarr.mdl"
    --mdl_test = "models/vortigaunt.mdl"
    --mdl_test = "models/crow.mdl"
    --mdl_test = "models/Alyx.mdl"
    mdl_test = "models/kazditi/protogen/protogen.mdl"
    --mdl_test = "models/gman_high.mdl"
    --mdl_test = "models/Combine_dropship.mdl"
    --mdl_test = "models/Combine_turrets/Floor_turret.mdl"
    --mdl_test = "models/combine_camera/combine_camera.mdl"
    --mdl_test = "models/AntLion.mdl"
    --mdl_test = "models/props_phx/construct/metal_tube.mdl"
    mdl_test = "models/dog.mdl"
    mdl_test = "models/Zombie/Classic_legs.mdl"
    mdl_test = "models/raptor/aeon_enhanced/aeon.mdl"
    mdl_test = "models/n7legion/fortnite/hybrid_player_alt.mdl"
    --mdl_test = "models/player/LeymiRBA/GrifGrif.mdl" [this one breaks...]
    --mdl_test = "models/Gibs/Fast_Zombie_Torso.mdl"
    --mdl_test = "models/Combine_Strider.mdl"
    --mdl_test = "models/props_junk/wood_crate001a.mdl"
    --mdl_test = "models/props_lab/frame001a.mdl"
    --mdl_test = "models/props_lab/Cleaver.mdl"
    print("LOADING: " .. tostring(mdl_test))
    local loaded = Prof( "LoadModel", mdl.LoadModel, mdl_test )
    
    print(tostring(loaded))
    
    hook.Add("PostDrawOpaqueRenderables", "test_mdl", function()
    
        if true then return end
        if loaded then
            loaded:Render()
        end
        --local parts = loaded:GetBodyParts()
        --loaded:RenderBodyPart(parts[1])
    
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