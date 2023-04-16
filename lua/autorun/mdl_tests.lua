include("alchemy_toolkit.lua")

alchemy.Init()

local mdl = alchemy.Loader("mdl")
local utils = alchemy.utils

if SERVER then

    --local fbx = alchemy.Loader("fbx")
    --fbx.Load("test.fbx", "DATA")

    --[[local deflate = include("alchemy/common/libdeflate.lua")
    local r = include("alchemy/common/datareader.lua")

    r.open_data("test.unitypackage", "DATA")

    local magic = r.uint16()
    assert(magic == 0x8b1f)
    local method = r.uint8()
    assert(method == 0x8)
    local fflags = r.uint8()
    local timestamp = r.uint32()
    local cflags = r.uint8()
    local osid = r.uint8()
    local filename = nil

    if bit.band(fflags, 0x8) ~= 0 then
        filename = r.nullstr()
    end

    local remain = string.sub(r.get_data(), r.get_ptr(), -1)
    r.end_data()

    local tar = deflate:DecompressDeflate(remain)
    r.begin_data(tar)

    local function block()
        local k = r.tell_data()
        local header = {
            filename = r.vcharstr(100),
            mode = r.vcharstr(8),
            uid = r.vcharstr(8),
            gid = r.vcharstr(8),
            size = r.vcharstr(12),
            mtime = r.vcharstr(12),
            chksum = r.vcharstr(8),
            typeflag = r.char(),
            linkname = r.vcharstr(100),
            magic = r.vcharstr(6),
            version = r.vcharstr(2),
            uname = r.vcharstr(32),
            gname = r.vcharstr(32),
            devmajor = r.vcharstr(8),
            devminor = r.vcharstr(8),
            prefix = r.vcharstr(155),
        }

        if header.magic == "" then return nil end

        local remainder = r.charstr(12)

        if header.typeflag == '0' then
            local nbytes = tonumber(header.size, 8)
            local rounding = 512 - bit.band(nbytes, 511)
            header.data = r.charstr(nbytes)
            if rounding ~= 0 then
                r.seek_data( r.tell_data() + rounding )
            end

            print("FILE: " .. header.filename .. " : " .. nbytes .. "|" .. header.size)
        elseif header.typeflag == '5' then
            print("DIR: " .. header.filename)
        else
            PrintTable(header)
            error("unknown typeflag: " .. tostring(header.typeflag))
        end

        if string.find(header.filename, "pathname") ~= nil then
            print(header.data)
        end

        return header
    end

    for i=1, 10000 do
        if block() == nil then break end
    end]]
end

if true then return end

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

    local refmodel = "models/n7legion/fortnite/hybrid_player.mdl" --"models/Police.mdl"
    local ref = mdl.LoadModel(refmodel)
    print("loaded reference ok")

    local studiomdl = alchemy.Compiler("mdl")

    local studio = studiomdl.New("modeltests/gtest5")
    local rootbone = studio:Bone("rootbone")

    --[[local model = studio:BodyPart():Model()
    local msh = model:Mesh( "models/flesh" )
    local stripgroup = msh:StripGroup()
    local strip = stripgroup:Strip()
    make_cube(strip, 15, Vector(0,0,0))

    local stripgroup = msh:StripGroup()
    local strip = stripgroup:Strip()
    make_cube(strip, 15, Vector(40,0,0))

    local bp1 = studio:BodyPart()

    bp1:Model()

    local model = bp1:Model()
    local msh = model:Mesh( "models/props_wasteland/wood_fence01a" )
    local stripgroup = msh:StripGroup()
    local strip = stripgroup:Strip()
    make_cube(strip, 15, Vector(0,0,40))

    local msh = model:Mesh( "phoenix_storms/metalfloor_2-3" )
    local stripgroup = msh:StripGroup()
    local strip = stripgroup:Strip()
    make_cube(strip, 15, Vector(0,0,80))]]
    
    for k, part in ipairs(ref:GetBodyParts()) do
        --if k ~= 1 and k ~= 2 and k ~= 4 then continue end
        --if k ~= 1 and k ~= 2 and k ~= 3 and k ~= 4 then print("SKIP: [" .. k .. "]: " .. part.name) continue end
        local newPart = studio:BodyPart(part.name)
        for i=1, #part.models do
            local model = part.models[i]
            local newModel = newPart:Model(model.name)
            for k, msh in ipairs(model.meshes) do
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

    local phys = studio:PhysBone( rootbone )
    phys:SetSurfaceProp("bloodyflesh")
    phys:BuildFromEntireModel()
    studio:Write()
    --studio:Mount()

    hook.Add("PostDrawOpaqueRenderables", "test_studio", function()
    
        if true then return end
        local mtx = Matrix()
        mtx:SetTranslation(Vector(70,0,0))
        --if true then return end
        cam.PushModelMatrix(mtx)
        studio:Render()
        cam.PopModelMatrix()

    end)
    

    local mdl_test = "models/Gibs/Fast_Zombie_Legs.mdl"
    mdl_test = "models/Gibs/HGIBS.mdl"
    --mdl_test = "models/Lamarr.mdl"
    --mdl_test = "models/vortigaunt.mdl"
    --mdl_test = "models/crow.mdl"
    mdl_test = "models/Police.mdl"
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
    --mdl_test = "models/props_c17/TrapPropeller_Blade.mdl"
    --mdl_test = "models/props_doors/door03_slotted_left.mdl"
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
        --utils.print_table(loaded.bodyparts, "", {"vertices"}, -1, 20)
    end

    --PrintTable(loaded.vvd.vertices)
    --PrintTable(loaded.vtx.materialReplacementList)

    --utils.print_table(loaded.phy.data, "", {}, 4)
    
    hook.Add("PostDrawOpaqueRenderables", "test_mdl", function()
    
        if true then return end
        if not loaded then return end
        loaded:Render()
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

        --local parts = loaded:GetBodyParts()
        --loaded:RenderModel( parts[1].models[1] )
    
    end)


    local lshift = bit.lshift
    local rshift = bit.rshift
    local abs = math.abs
    local frexp = math.frexp
    local ldexp = math.ldexp
    local floor = math.floor
    local strchar = string.char
    local __vunpack = FindMetaTable("Vector").Unpack
    local function float2str(v)
        local fr,exp = frexp(abs(v))
        fr = floor(ldexp(fr, 24))
        exp = exp + 126
        if v == 0.0 then fr,exp = 0,0 end
        return strchar(fr%256, rshift(fr,8)%256, (exp%2)*128+rshift(fr,16)%128, (v<0 and 128 or 0)+rshift(exp,1))
    end

    local function vec_hash(v)
        local x,y,z = __vunpack(v)
        local frx,expx = frexp(abs(x)) expx,frx = expx + 126, floor(ldexp(frx, 24))
        local fry,expy = frexp(abs(y)) expy,fry = expy + 126, floor(ldexp(fry, 24))
        local frz,expz = frexp(abs(z)) expz,frz = expz + 126, floor(ldexp(frz, 24))
        if x == 0.0 then frx,expx = 0,0 end
        if y == 0.0 then fry,expy = 0,0 end
        if z == 0.0 then frz,expz = 0,0 end
        return strchar(
            frx%256, rshift(frx,8)%256, (expx%2)*128+rshift(frx,16)%128, (x<0 and 128 or 0)+rshift(expx,1),
            fry%256, rshift(fry,8)%256, (expy%2)*128+rshift(fry,16)%128, (y<0 and 128 or 0)+rshift(expy,1),
            frz%256, rshift(frz,8)%256, (expz%2)*128+rshift(frz,16)%128, (z<0 and 128 or 0)+rshift(expz,1)
        )
    end

    local bor = bit.bor
    local band = bit.band
    local function sblsh(s, e, b) return lshift(s:byte(e), b) end
    function str2float(str, off)
        local b4, b3 = str:byte(off+4), str:byte(off+3)
        local fr = lshift(band(b3, 0x7F), 16) + sblsh(str, off+2, 8) + sblsh(str, off+1, 0)
        local exp = band(b4, 0x7F) * 2 + rshift(b3, 7)
        if exp == 0 then return 0 end
    
        local s = (b4 > 127) and -1 or 1
        local n = math.ldexp((math.ldexp(fr, -23) + 1) * s, exp - 127)
        return n
    end

    
    local function snap_float(f)
        local fr,exp = frexp(abs(f))
        local s = f<0 and -1 or 1
        local sn = floor(ldexp(fr, 24))
        local k = ldexp(ldexp(sn, -23) * s, exp-1)
        return k
    end

    local function round_float(f)
        local fr,exp = frexp(abs(f))
        local s = f<0 and -1 or 1
        local sn = floor(ldexp(fr, 24))
        local k = ldexp(ldexp(sn, -23) * s, exp-1)
        local k1 = ldexp(ldexp(sn+1, -23) * s, exp-1)
        local d0 = abs(f-k)
        local d1 = abs(f-k1)
        if d0 < d1 then return k else return k1 end
        --print(f,k,k1,sn)
        return k
    end


    hook.Add("HUDPaint", "paint_spans", function()
    
        --[[local pos = LocalPlayer():GetPos()
        local fl = float2str( pos.x )
        local vl = vec_hash(pos)
        local b64 = util.Base64Encode(vl)
        local rv = Vector( str2float(vl, 0), str2float(vl, 4), str2float(vl, 8) ))]]

        --[[local pos = LocalPlayer():GetPos() * 10000 + Vector(1.05288693,0,0)
        local x = pos.x
        local fl = float2str( x )
        local rfl = str2float(fl, 0)
        local sn = snap_float(x)

        print(x - rfl, rfl - sn)]]

        local o = math.sin(CurTime()/2) * 1
        local v = -10000000.0 + o
        local sn = round_float(v)

        --[[MsgC( Color(255,255,0), (sn - snap_float(sn)) .. "\n")
        MsgC( Color(255,255,255), v .. "\n")
        MsgC( Color(255,80,80), sn .. "\n") 
        MsgC( Color(100,255,100), (sn - v) .. "\n")
        MsgC( Color(100,40,255), o .. "\n" )]]

        --[[local t0 = SysTime()
        for i=1, 100000 do
            vec_hash( pos )
        end
        local timeTaken = SysTime() - t0
        print(timeTaken*1000)]]

        --assert(pos == rv)

        --draw.SimpleText(b64 .. " : " .. tostring(pos - rv), "DermaLarge", 10, 10, Color(255,200,255))

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