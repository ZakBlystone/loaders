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
        include("alchemy/common/datareader.lua"),
        include("vtx.lua"),
        include("vvd.lua"),
    },
})

local lshift, rshift, band, bor, bnot = bit.lshift, bit.rshift, bit.band, bit.bor, bit.bnot

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

local m_version = 0

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
        triggers = indirect_array(mdl_quatinterpinfo),
    }

    load_indirect_array(quatinterp, base, "triggers")

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
        physicsbone = int32(),
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
    indirect_name(bone, base)
    indirect_name(bone, base, "surfacepropidx")

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
        indirect_name(bbox, base)
    end

    return bbox

end

local function mdl_hitboxset()

    local base = tell_data()
    local set = {
        nameidx = int32(),
        hitboxes = indirect_array(mdl_hitbox),
    }

    indirect_name(set, base)
    load_indirect_array(set, base, "hitboxes")

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
        movements = indirect_array(mdl_movement),
        _unused1 = array_of(int32, 6),
        animblock = int32(),
        animindex = int32(),
        numikrules = int32(),
        ikruleindex = int32(),
        animblockikruleindex = int32(),
        localhierarchy = indirect_array(mdl_localhierarchy),
        sectionindex = int32(),
        sectionframes = int32(),
        zeroframespan = int16(),
        zeroframecount = int16(),
        zeroframeindex = int32(),
        zeroframestalltime = float32(),
    }

    indirect_name(anim, base)

    load_indirect_array(anim, base, "movements")
    load_indirect_array(anim, base, "localhierarchy")

    if anim.sectionframes ~= 0 then
        local sections = {}
        local num = math.floor(anim.numframes / anim.sectionframes) + 2
        push_data(base + anim.sectionindex)
        local span = span_data("section")
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

    indirect_name(event, base)

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

    indirect_name(actmod, base)

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
        events = indirect_array(mdl_event),
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
        autolayers = indirect_array(mdl_autolayer),
        weightlistindex = int32(),
        posekeyindex = int32(),
        iklocks = indirect_array(mdl_iklock),
        keyvalueindex = int32(),
        keyvaluesize = int32(),
        cycleposeindex = int32(),
        activitymodifiers = indirect_array(mdl_activitymodifier, true),
    }

    array_of(int32, 5) -- unused

    indirect_name(seq, base, "labelidx")
    indirect_name(seq, base, "actnameidx")

    load_indirect_array(seq, base, "events")
    load_indirect_array(seq, base, "autolayers")
    load_indirect_array(seq, base, "iklocks")

    if m_version >= 49 then
        load_indirect_array(seq, base, "activitymodifiers")
    end

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

    indirect_name(tex, base)

    return tex

end

local function mdl_cdtexture()

    local base = tell_data()
    local cdtex = { nameidx = int32(), }

    indirect_name(cdtex, 0)

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
        flexes = indirect_array(mdl_flex),
        materialtype = int32(),
        materialparam = int32(),
        meshid = int32(),
        center = vector32(),
        modelvertexdata = int32(),
        numLODVertexes = array_of(int32, 8),
    }

    array_of(int32, 8) -- unused

    mesh.modelindex = mesh.modelindex + base
    load_indirect_array(mesh, base, "flexes")

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
        meshes = indirect_array(mdl_mesh),
        numvertices = int32(),
        vertexindex = int32(),
        tangentsindex = int32(),
        numattachments = int32(),
        attachmentindex = int32() + base,
        eyeballs = indirect_array(mdl_eyeball),
        pVertexData = int32(),
        pTangentData = int32(),
    }

    array_of(int32, 8) -- unused

    load_indirect_array(model, base, "meshes")
    load_indirect_array(model, base, "eyeballs")

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

    print("BP BASE: " .. part.base .. " : " .. base)

    indirect_name(part, base)

    local models = { 
        num = part.nummodels, 
        offset = part.modelindex, 
        dtype = mdl_model, 
    }
    load_indirect_array(part, base, "models", models)

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

    indirect_name(attach, base)

    return attach

end

local function mdl_flexdesc()

    local base = tell_data()
    local flexdesc = {
        facsidx = int32(),
    }

    indirect_name(flexdesc, base, "facsidx")

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

    indirect_name(flexctrl, base, "typeidx")
    indirect_name(flexctrl, base, "nameidx")

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
        flexops = indirect_array(mdl_flexop),
    }

    load_indirect_array(flexrule, base, "flexops")

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
        links = indirect_array(mdl_ikchainlink),
    }

    indirect_name(chain, base)
    load_indirect_array(chain, base, "links")

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

    indirect_name(poseparam, base)

    return poseparam

end

local function mdl_modelgroup()

    local base = tell_data()
    local group = {
        labelidx = int32(),
        nameidx = int32(),
    }

    indirect_name(group, base, "labelidx")
    indirect_name(group, base, "nameidx")

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

    indirect_name(ctrlui, base)

    return ctrlui

end

local function mdl_studiohdr2()

    local span = span_data("header_2")
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
        bones = indirect_array(mdl_bone),
        bone_controllers = indirect_array(mdl_bonecontroller),
        hitbox_sets = indirect_array(mdl_hitboxset),
        local_anims = indirect_array(mdl_animdesc),
        local_sequences = indirect_array(mdl_seqdesc),
        activitylistversion = int32(),
        eventsindexed = int32(),
        textures = indirect_array(mdl_texture),
        cdtextures = indirect_array(mdl_cdtexture),
        numskinref = int32(),
        numskinfamilies = int32(),
        skinindex = int32(),
        bodyparts = indirect_array(mdl_bodypart),
        attachments = indirect_array(mdl_attachment),
        numlocalnodes = int32(),
        localnodeindex = int32(),
        localnodenameindex = int32(),
        flexes = indirect_array(mdl_flexdesc),
        flexcontrollers = indirect_array(mdl_flexcontroller),
        flexrules = indirect_array(mdl_flexrule),
        ikchains = indirect_array(mdl_ikchain),
        mouths = indirect_array(mdl_mouth),
        poseparams = indirect_array(mdl_poseparamdesc),
        surfacepropidx = int32(),
        keyvaluesidx = int32(),
        keyvaluessize = int32(),
        localikautoplaylocks = indirect_array(mdl_iklock),
        mass = float32(),
        contents = int32(),
        includemodels = indirect_array(mdl_modelgroup),
        virtualModel = int32(),
        animblocknameidx = int32(),
        animblocks = indirect_array(mdl_animblock),
        animblockModel = int32(),
        bonetablebynameindex = int32(),
        pVertexBase = int32(),
        pIndexBase = int32(),
        constdirectionallightdot = uint8(),
        rootLOD = uint8(),
        numAllowedRootLODs = uint8(),
        unused = uint8(),
        unused4 = uint32(),
        flexcontrollerui = indirect_array(mdl_flexcontrollerui),
        flVertAnimFixedPointScale = float32(),
        unused3 = int32(),
        studiohdr2index = int32(),
        unused2 = int32(),
    }

    m_version = header.version

    push_data(base + header.bonetablebynameindex)
    local t = {}
    for i=1, header.bones.num do
        t[#t+1] = uint8()
    end
    header.bonetablebynameindex = t
    pop_data()

    if header.numskinfamilies ~= 0 then
        header.skins = {}
        push_data(base + header.skinindex)
        for i=1, header.numskinfamilies do
            local skin = {}
            for j=1, header.numskinref do
                skin[j] = int16()
            end
            header.skins[i] = skin
        end
        pop_data()
    end

    if header.studiohdr2index ~= 0 then
        push_data(base + header.studiohdr2index)
        header.hdr2 = mdl_studiohdr2()
        pop_data()
    end

    indirect_name(header, base, "surfacepropidx")
    indirect_name(header, base, "animblocknameidx")
    indirect_name(header, base, "keyvaluesidx", "keyvaluessize")

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
            local span = span_data("__")
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
        print("***ANIM FRAMEDATA")
        print(bone, flags, nextoffset)
        if rawpos or true then PrintTable(posrot) end
        if nextoffset == 0 then break end
        seek_data(base + nextoffset)
    end

end

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

local function AppendTri(v0,v1,v2)

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

function mdl_meta:RenderStrip( group, strip )

    if not strip then return end

    local vertices = self:GetVertices()

    local num = strip.numIndices / 3
    local i = 1 + strip.indexOffset
    while num > 0 do

        local sec = math.min(10922, num)
        mesh.Begin( MATERIAL_TRIANGLES, sec )

        for j=1, sec do

            local i0 = group.indices[i]
            local i1 = group.indices[i+1]
            local i2 = group.indices[i+2]

            local v0 = vertices[i0]
            local v1 = vertices[i1]
            local v2 = vertices[i2]

            local b,e = pcall(AppendTri,v0,v1,v2)
            if not b then print(e) break end
            i = i + 3

        end

        mesh.End()
        num = num - sec

    end

end

function mdl_meta:RenderStripGroup( group )

    for i=1, #group.strips do
        self:RenderStrip( group, group.strips[i] )
    end

end

function mdl_meta:RenderMesh( msh )

    local mat = self:GetMeshMaterial(msh)
    if not mat then mat = Material("hunter/myplastic") end

    render.SetMaterial(mat)

    for _, group in ipairs(msh.stripgroups) do

        self:RenderStripGroup( group )

    end

end

function mdl_meta:RenderBodyPart( part )

    if not part then return end
    for _, m in ipairs(part.models) do

        for _, msh in ipairs(m.meshes) do

            self:RenderMesh(msh)

        end

    end

end

function mdl_meta:Render()

    for _, p in ipairs(self:GetBodyParts()) do

        self:RenderBodyPart(p)

    end

end

local function LoadMDL( filename, path )

    open_data(filename, path)

    local span = span_data("header")
    local header = mdl_header()
    span:Stop()

    print("LOADED HEADER OK... VERSION: " .. header.version)

    setmetatable(header, mdl_meta)

    load_indirect_array(header, 0, "bones")
    load_indirect_array(header, 0, "bone_controllers")
    load_indirect_array(header, 0, "hitbox_sets")
    load_indirect_array(header, 0, "local_anims")
    load_indirect_array(header, 0, "local_sequences")
    load_indirect_array(header, 0, "textures")
    load_indirect_array(header, 0, "cdtextures")
    load_indirect_array(header, 0, "bodyparts")
    load_indirect_array(header, 0, "attachments")
    load_indirect_array(header, 0, "flexrules")
    load_indirect_array(header, 0, "ikchains")
    load_indirect_array(header, 0, "mouths")
    load_indirect_array(header, 0, "poseparams")
    load_indirect_array(header, 0, "localikautoplaylocks")
    load_indirect_array(header, 0, "includemodels")
    load_indirect_array(header, 0, "animblocks")
    load_indirect_array(header, 0, "flexcontrollerui")
    load_indirect_array(header, 0, "flexcontrollers")
    load_indirect_array(header, 0, "flexes")

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

    --PrintTable(header.bones)


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
            print("Anim: " .. anim.name .. " : " .. anim.numframes .. "@" .. anim.fps)
            local base = anim.baseptr
            local ptr = base + anim.animindex
            push_data(ptr)
            local span = span_data("Anim: " .. anim.name)
            LoadAnimBlock(anim.numframes, header.bones)
            span:Stop()
            pop_data()
        end

    end

    local bone_count = #header.bones
    for _, seq in ipairs(header.local_sequences) do

        local weights = {}
        push_data(seq.baseptr + seq.weightlistindex)
        for i=1, bone_count do
            weights[#weights+1] = float32()
        end
        pop_data()
        seq.weightlist = weights
        seq.weightlistindex = nil

    end

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

    local mdl_filename = filename
    local vvd_filename = filename:sub(1, -4) .. "vvd"
    local vtx_filename = filename:sub(1, -4) .. "dx90.vtx"

    if mdl_filename:sub(-3,-1) == "dat" then
        local base = string.GetPathFromFilename(filename)
        mdl_filename = base .. "mdl.dat"
        vvd_filename = base .. "vvd.dat"
        vtx_filename = base .. "vtx.dat"
        path = "DATA"
    end

    local mdl = LoadMDL( mdl_filename, path )
    local vvd = LoadVVD( vvd_filename, path, 1, true )
    local vtx = LoadVTX( vtx_filename, path )
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

return __lib