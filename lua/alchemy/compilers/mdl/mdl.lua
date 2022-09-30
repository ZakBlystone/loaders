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

AddCSLuaFile()
local __lib = alchemy.MakeLib({
    using = {
        include("alchemy/common/datawriter.lua"),
        include("vtx.lua"),
        include("vvd.lua"),
    },
})

STUDIO_IDENT = "IDST"
STUDIO_VERSION = 48

local function mdl_bone(v)
    
    local base = tell_data()
    local bone = {
        name = indirect_name(v.name, base),
        parent = int32(v.parent),
        bonecontroller = array_of(int32, {-1, -1, -1, -1, -1, -1}),
        pos = vector32(v:GetPos()),
        quat = quat128(v:GetAnglesQuat()),
        rot = angle32(v:GetAngles()),
        posscale = vector32(Vector(0.003906, 0.003906, 0.003906)),
        rotscale = vector32(Vector(0.000012, 0.000012, 0.000048)),
        poseToBone = matrix3x4(v:GetBindMatrix()),
        qAlignment = quat128(v:GetQuatAlignment()),
        flags = v:GetFlags(),
        proctype = int32(0),
        procindex = int32(0),
        physicsbone = int32(0),
        surfaceprop = indirect_name(v:GetSurfaceProp(), base),
        contents = v:GetContents(),
        unused = array_of(int32, {0,0,0,0,0,0,0,0}),
    }

    return bone

end

local function mdl_bonecontroller(v)
    error("mdl_bonecontroller Not yet implemented")
end

local function mdl_hitbox(v)

    local base = tell_data()
    local bbox = {
        name = "",
        bone = int32(v.boneid),
        group = int32(0), -- figure out
        bbmin = vector32(v.bbmins),
        bbmax = vector32(v.bbmaxs),
        nameidx = indirect_name(v.name, base),
        unused = array_of(int32, {0,0,0,0,0,0,0,0}),
    }

    return bbox

end

local function mdl_hitboxset(v)

    local base = tell_data()
    local set = {
        nameidx = indirect_name(v.name, base),
        hitboxes = indirect_array( mdl_hitbox, v.hitboxes ),
    }

    write_indirect_array( set, base, "hitboxes" )

    return set

end

local function mdl_animdesc(v)
    error("mdl_animdesc Not yet implemented")
end

local function mdl_seqdesc(v)
    error("mdl_seqdesc Not yet implemented")
end

local function mdl_texture(v)

    local base = tell_data()
    local tex = {
        name = indirect_name(v.name, base),
        flags = v.flags,
        used = v.used,
        unused1 = int32(0),
    }

    charstr("", 12*4)

    return tex

end

local function mdl_cdtexture(v)
    
    local name = indirect_name(v)

end

local function mdl_eyeball(v)
    error("mdl_eyeball Not yet implemented")
end

local function mdl_flex(v)
    error("mdl_eyeball Not yet implemented")
end

local function mdl_mesh(v)

    local base = tell_data()
    local mesh = {
        base = base,
        material = int32(v.materialidx),
        modelindex = int32(0),
        numvertices = int32(0), -- cache
        vertexoffset = int32(0), -- cache
        flexes = indirect_array( mdl_flex, v.flexes ),
        materialtype = int32(0), -- figure out
        materialparam = int32(0), -- figure out
        meshid = int32(v.meshid),
        center = vector32(v:GetCenter()),
    }

    write_indirect_array( mesh, base, "flexes" )

    return mesh

end

local function mdl_model(v)

    assert(v, "expect model")

    local base = tell_data()
    local model = {
        ptr = base,
        name = charstr( v.name, 64 ),
        type = int32(0), -- figure out
        boundingradius = float32(0), -- figure out
        meshes = indirect_array( mdl_mesh, v.meshes ),
        numvertices = int32(0), -- cache
        vertexindex = int32(0), -- cache
        tangentsindex = int32(0), -- cache
        numattachments = int32(0), -- figure out
        attachmentindex = int32(0), -- figure out
        eyeballs = indirect_array( mdl_eyeball, v.eyeballs ),
        unused8 = array_of(int32, {0,0,0,0,0,0,0,0,0,0}),
    }

    write_indirect_array( model, base, "meshes" )
    write_indirect_array( model, base, "eyeballs" )

    for _, mesh in ipairs( model.meshes ) do
        local offset = tell_data() - mesh.base
        push_data( mesh.modelindex )
        int32(base)
        pop_data()
    end

    return model

end

local function mdl_bodypart(v)

    local base = tell_data()
    local part = {
        name = indirect_name( v.name, base ),
        nummodels = int32( #v.models ),
        base = int32(1), -- not sure what this is
        modelindex = int32(0),
    }

    local models = {
        values = v.models,
        num = #v.models,
        offset = part.modelindex,
        dtype = mdl_model,
    }

    write_indirect_array( part, base, models )

    return part

end

local function mdl_attachment(v)
    error("mdl_attachment Not yet implemented")
end

local function mdl_flexdesc(v)
    error("mdl_flexdesc Not yet implemented")
end

local function mdl_flexcontroller(v)
    error("mdl_flexcontroller Not yet implemented")
end

local function mdl_flexrule(v)
    error("mdl_flexrule Not yet implemented")
end

local function mdl_ikchain(v)
    error("mdl_ikchain Not yet implemented")
end

local function mdl_mouth(v)
    error("mdl_mouth Not yet implemented")
end

local function mdl_poseparamdesc(v)
    error("mdl_poseparamdesc Not yet implemented")
end

local function mdl_iklock(v)
    error("mdl_iklock Not yet implemented")
end

local function mdl_modelgroup(v)
    error("mdl_modelgroup Not yet implemented")
end

local function mdl_animblock(v)
    error("mdl_animblock Not yet implemented")
end

local function mdl_flexcontrollerui(v)
    error("mdl_flexcontrollerui Not yet implemented")
end

local function mdl_header(v)

    local base = tell_data()
    local header = {
        id = charstr(STUDIO_IDENT,4),
        version = int32(STUDIO_VERSION),
        checksum = int32(v:GetChecksum()),
        name = charstr(v:GetName(), 64),
        length = int32(0),
        eyeposition = vector32(v:GetEyePos()),
        illumposition = vector32(v:GetIllumPos()),
        hull_min = vector32(v:GetHullMin()),
        hull_max = vector32(v:GetHullMax()),
        view_bbmin = vector32(v:GetViewBBMin()),
        view_bbmax = vector32(v:GetViewBBMax()),
        flags = int32(v:GetFlags()),
        bones = indirect_array( mdl_bone, v.bones ),
        bone_controllers = indirect_array( mdl_bonecontroller, v.bonecontrollers ),
        hitbox_sets = indirect_array( mdl_hitboxset, v.hitboxsets ),
        local_anims = indirect_array( mdl_animdesc, v.localanims ),
        local_sequences = indirect_array( mdl_seqdesc, v.localsequences ),
        activitylistversion = int32(0), -- figure out (OK)
        eventsindexed = int32(0), -- figure out (OK)
        textures = indirect_array( mdl_texture, v.textures ),
        cdtextures = indirect_array( mdl_cdtexture, v.cdtextures ),
        numskinref = int32( #v.textures ),
        numskinfamilies = int32( 1+#v.skins ),
        skinindex = int32(0),
        bodyparts = indirect_array( mdl_bodypart, v.bodyparts ),
        attachments = indirect_array( mdl_attachment, v.attachments ),
        numlocalnodes = int32(0), -- figure out (OK)
        localnodeindex = int32(0), -- figure out (OK)
        localnodenameindex = int32(0), -- figure out (OK)
        flexes = indirect_array( mdl_flexdesc, v.flexdescriptors ),
        flexcontrollers = indirect_array( mdl_flexcontroller, v.flexcontrollers ),
        flexrules = indirect_array( mdl_flexrule, v.flexrules ),
        ikchains = indirect_array( mdl_ikchain, v.ikchains ),
        mouths = indirect_array( mdl_mouth, v.mouths ),
        poseparams = indirect_array( mdl_poseparamdesc, v.poseparams ),
        surfacepropidx = indirect_name("solidmetal", base),
        keyvalues = indirect_name(v:GetKeyValuesString(), base, true),
        localikautoplaylocks = indirect_array( mdl_iklock, v.iklocks ),
        mass = float32(v:GetMass()),
        contents = int32(v:GetContents()),
        includemodels = indirect_array( mdl_modelgroup, v.modelgroups ),
        virtualModel = int32(0), -- figure out (OK)
        animblocknameidx = int32(0), -- figure out
        animblocks = indirect_array( mdl_animblock, v.animblocks ),
        animblockModel = int32(0), -- figure out (OK)
        bonetablebynameindex = int32(0), -- figure out
        pVertexBase = int32(0),
        pIndexBase = int32(0),
        constdirectionallightdot = uint8(0), -- figure out (OK)
        rootLOD = uint8(0), -- figure out
        numAllowedRootLODs = uint8(0), -- figure out
        unused = uint8(0),
        unused4 = uint32(0),
        flexcontrollerui = indirect_array( mdl_flexcontrollerui, v.flexcontrollerui ),
        flVertAnimFixedPointScale = float32(0), -- figure out (OK)
        unused3 = int32(0),
        studiohdr2index = int32(0), -- figure out (OK)
        unused2 = int32(0),
    }

    -- header 2
    local hdr2_base = tell_data()
    local hdr2 = {
        numsrcbonetransform = int32(0),
        srcbonetransformindex = int32(0),
        illumpositionattachmentindex = int32(0),
        flMaxEyeDeflection = float32(0),
        linearboneindex = int32(0),
        reserved = charstr("", 4*59),
    }

    align4()

    -- Write header2
    push_data( header.studiohdr2index )
    int32(hdr2_base - base)
    pop_data()

    align4() write_indirect_array( header, base, "bones" )
    align4() write_indirect_array( header, base, "bone_controllers" )
    align4() write_indirect_array( header, base, "hitbox_sets" )
    align4() write_indirect_array( header, base, "local_anims" )
    align4() write_indirect_array( header, base, "local_sequences" )
    align4() write_indirect_array( header, base, "textures" )
    align4() write_indirect_array( header, base, "cdtextures" )
    align4() write_indirect_array( header, base, "bodyparts" )
    align4() write_indirect_array( header, base, "attachments" )
    align4() write_indirect_array( header, base, "flexes" )
    align4() write_indirect_array( header, base, "flexcontrollers" )
    align4() write_indirect_array( header, base, "flexrules" )
    align4() write_indirect_array( header, base, "ikchains" )
    align4() write_indirect_array( header, base, "mouths" )
    align4() write_indirect_array( header, base, "poseparams" )
    align4() write_indirect_array( header, base, "localikautoplaylocks" )
    align4() write_indirect_array( header, base, "includemodels" )
    align4() write_indirect_array( header, base, "animblocks" )
    align4() write_indirect_array( header, base, "flexcontrollerui" )

    -- Write skins
    local skins_offset = tell_data() - base
    push_data( header.skinindex )
    int32(skins_offset)
    pop_data()

    local skins = v.skins
    for i=1, 1+#skins do
        for j=1, #v.textures do
            local remap = (skins[i-1] or {})[j] or j
            uint16(remap)
        end
    end

    write_all_names()

    -- Write bone index
    local bone_index_offset = tell_data() - base
    push_data( header.bonetablebynameindex )
    int32( bone_index_offset )
    pop_data()

    for i=1, #v.bones do
        uint8(i-1)
    end

end

function WriteStudioMDL( studio )

    open_data("studio/mdl.dat")
    mdl_header( studio )
    end_data()

end

return __lib