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
local __lib = alchemy.MakeLib({
    using = {
        include("mdl.lua"),
        include("../../common/keytable.lua")
    },
})

BONE_CALCULATE_MASK			= 0x1F
BONE_PHYSICALLY_SIMULATED	= 0x01	// bone is physically simulated when physics are active
BONE_PHYSICS_PROCEDURAL		= 0x02	// procedural when physics is active
BONE_ALWAYS_PROCEDURAL		= 0x04	// bone is always procedurally animated
BONE_SCREEN_ALIGN_SPHERE	= 0x08	// bone aligns to the screen, not constrained in motion.
BONE_SCREEN_ALIGN_CYLINDER	= 0x10	// bone aligns to the screen, constrained by it's own axis.

BONE_USED_MASK				= 0x0007FF00
BONE_USED_BY_ANYTHING		= 0x0007FF00
BONE_USED_BY_HITBOX			= 0x00000100	// bone (or child) is used by a hit box
BONE_USED_BY_ATTACHMENT		= 0x00000200	// bone (or child) is used by an attachment point
BONE_USED_BY_VERTEX_MASK	= 0x0003FC00
BONE_USED_BY_VERTEX_LOD0	= 0x00000400	// bone (or child) is used by the toplevel model via skinned vertex
BONE_USED_BY_VERTEX_LOD1	= 0x00000800	
BONE_USED_BY_VERTEX_LOD2	= 0x00001000  
BONE_USED_BY_VERTEX_LOD3	= 0x00002000
BONE_USED_BY_VERTEX_LOD4	= 0x00004000
BONE_USED_BY_VERTEX_LOD5	= 0x00008000
BONE_USED_BY_VERTEX_LOD6	= 0x00010000
BONE_USED_BY_VERTEX_LOD7	= 0x00020000
BONE_USED_BY_BONE_MERGE		= 0x00040000	// bone is available for bone merge to occur against it

local function createMeta()
    local t = {}
    t.__index = t
    t.New = function(...) return setmetatable({}, t):Init(...) end
    return t
end

local m_bodypart = createMeta()
local m_model = createMeta()
local m_mesh = createMeta()
local m_stripgroup = createMeta()
local m_strip = createMeta()
local m_bone = createMeta()
local m_physbone = createMeta()
local m_physconstraint = createMeta()
local m_hitboxset = createMeta()
local m_hitbox = createMeta()
local m_studio = createMeta()

local function vmin_into(a,b)

    local x0,y0,z0 = a:Unpack()
    local x1,y1,z1 = b:Unpack()
    b:SetUnpacked( math.min(x0,x1), math.min(y0,y1), math.min(z0,z1) )

end

local function vmax_into(a,b)

    local x0,y0,z0 = a:Unpack()
    local x1,y1,z1 = b:Unpack()
    b:SetUnpacked( math.max(x0,x1), math.max(y0,y1), math.max(z0,z1) )

end

-- STRIP
function m_strip:Init()

    self.indices = {}
    self.bbmins = Vector(math.huge, math.huge, math.huge)
    self.bbmaxs = Vector(-math.huge, -math.huge, -math.huge)
    self.boneStateChanges = {}
    self.numBones = 0
    return self

end

function m_strip:Vertex( position, normal, u, v, tx, ty, tz, tw, weights )

    local vertices = self.group.mesh.model.part.studio.vertices
    local tangents = self.group.mesh.model.part.studio.tangents

    self.group.vertices[#self.group.vertices+1] = {
        origMeshVertID = #vertices,
        numBones = 1,
        boneWeightIndex = {0,1,2},
        boneID = {0,0,0},
    }

    vmin_into(position, self.bbmins)
    vmax_into(position, self.bbmaxs)
    vmin_into(position, self.group.mesh.bbmins)
    vmax_into(position, self.group.mesh.bbmaxs)
    self.group.mesh.model.numvertices = self.group.mesh.model.numvertices + 1
    self.group.mesh.numvertices = self.group.mesh.numvertices + 1
    self.numVerts = self.numVerts + 1

    local vertex = {
        position = position,
        normal = normal,
        u = u,
        v = v,
        weights = weights or {},
    }
    vertices[#vertices+1] = vertex
    tangents[#tangents+1] = {x=tx, y=ty, z=tz, w=tw}

end

-- Regarding strips and stripgroups
-- Stripgroups contain vtx indices and vertices
-- Each strip within the group window's into the stripgroup's arrays via
-- indexOffset, numIndices, vertOffset, numVerts

-- The strip group contains all the indices for all strips
-- Each index is local to the group (0 - n) mapping to the vtx vertex array
-- The group's vtx vertex array maps origMeshVertID to the actual vertices
function m_strip:Triangle( i0, i1, i2 )

    local vertices = self.group.vertices
    local indices = self.group.indices
    local base = self.numIndices + self.indexOffset
    local vertoff = #vertices
    indices[base+1] = (i0 > 0 and i0 or vertoff + i0 + 1) - 1
    indices[base+2] = (i1 > 0 and i1 or vertoff + i1 + 1) - 1
    indices[base+3] = (i2 > 0 and i2 or vertoff + i2 + 1) - 1

    self.numIndices = self.numIndices + 3

end

function m_strip:Render()

    local indices = self.group.indices
    local vverts = self.group.vertices
    local vertices = self.group.mesh.model.part.studio.vertices
    local tangents = self.group.mesh.model.part.studio.tangents

    assert(vertices and tangents)

    mesh.Begin( MATERIAL_TRIANGLES, #indices / 3 )

    for i=1, self.numIndices, 3 do
        local i0 = indices[self.indexOffset + i] + 1
        local i1 = indices[self.indexOffset + i+1] + 1
        local i2 = indices[self.indexOffset + i+2] + 1

        local v0 = vertices[vverts[i0].origMeshVertID+1]
        local v1 = vertices[vverts[i1].origMeshVertID+1]
        local v2 = vertices[vverts[i2].origMeshVertID+1]

        if v0 and v1 and v2 then

            local t0 = tangents[i0]
            local t1 = tangents[i1]
            local t2 = tangents[i2]

            mesh.Position(v0.position)
            mesh.Normal(v0.normal)
            mesh.TexCoord(0, v0.u, v0.v)
            mesh.UserData(t0.x, t0.y, t0.z, t0.w)
            mesh.AdvanceVertex()

            mesh.Position(v1.position)
            mesh.Normal(v1.normal)
            mesh.TexCoord(0, v1.u, v1.v)
            mesh.UserData(t1.x, t1.y, t1.z, t1.w)
            mesh.AdvanceVertex()

            mesh.Position(v2.position)
            mesh.Normal(v2.normal)
            mesh.TexCoord(0, v2.u, v2.v)
            mesh.UserData(t2.x, t2.y, t2.z, t2.w)
            mesh.AdvanceVertex()

        end
    end

    mesh.End()

end

-- STRIPGROUP
function m_stripgroup:Init()

    self.strips = {}
    self.indices = {}
    self.vertices = {}
    return self

end

function m_stripgroup:Strip()

    local strip = m_strip.New()
    strip.group = self
    strip.indexOffset = #self.indices
    strip.vertOffset = 0
    strip.numIndices = 0
    strip.numVerts = 0
    self.strips[#self.strips+1] = strip
    return strip

end

function m_stripgroup:GetFlags()

    return STRIPGROUP_IS_HWSKINNED

end

function m_stripgroup:Render()

    for _, strip in ipairs(self.strips) do
        strip:Render()
    end

end


-- MESH
function m_mesh:Init( matid, material )

    self.stripgroups = {}
    self.material = Material(material)
    self.flexes = {}
    self.materialidx = 0
    self.meshid = 0
    self.numvertices = 0
    self.bbmins = Vector(math.huge, math.huge, math.huge)
    self.bbmaxs = Vector(-math.huge, -math.huge, -math.huge)
    return self

end

function m_mesh:StripGroup()

    local stripgroup = m_stripgroup.New()
    stripgroup.mesh = self
    self.stripgroups[#self.stripgroups+1] = stripgroup
    return stripgroup

end

function m_mesh:GetCenter() return (self.bbmins + self.bbmaxs) / 2 end

function m_mesh:Render()

    render.SetMaterial(self.material)
    for _, strip in ipairs(self.stripgroups) do
        strip:Render()
    end

end

-- MODEL
function m_model:Init( name )

    self.meshes = {}
    self.eyeballs = {}
    self.name = name
    self.radius = 0
    self.numvertices = 0
    return self

end

function m_model:Mesh( material )

    local materials = self.part.studio.materials
    local matID = 0
    for i=1, #materials do
        if materials[i] == material then
            matID = i
        end
    end

    if matID == 0 then
        matID = #materials + 1
        materials[#materials+1] = material
    end

    local m = m_mesh.New( matID, material )
    m.model = self
    self.meshes[#self.meshes+1] = m
    return m

end

function m_model:Render()

    for _, msh in ipairs(self.meshes) do
        msh:Render()
    end

end

-- todo: implement
function m_model:GetBoundingRadius() return self.radius end
function m_model:GetNumVertices() return self.numvertices end

-- BODY PART
function m_bodypart:Init( name )

    self.models = {}
    self.name = name
    return self

end

function m_bodypart:Model( name )

    if name == nil then name = "model_" .. #self.models end
    local model = m_model.New( name )
    model.part = self
    self.models[#self.models+1] = model
    return model

end

-- BONE
function m_bone:Init( name )

    self.name = name
    self.parent = -1
    self.matrix = Matrix()
    self.bindmatrix = Matrix()
    self.flags = BONE_USED_BY_VERTEX_LOD0
    self.physboneid = 0
    self.physprop = "metal"
    return self

end

function m_bone:GetPos() return self.matrix:GetTranslation() end
function m_bone:GetAnglesQuat()

    -- todo: implement
    return quat(0,0,0,1)

end

function m_bone:GetQuatAlignment()

    -- todo: implement
    return quat(0,0,0,1)

end

function m_bone:GetAngles() return self.matrix:GetAngles() end
function m_bone:GetBindMatrix() return self.bindmatrix end
function m_bone:GetFlags() return self.flags end
function m_bone:GetContents() return CONTENTS_SOLID end
function m_bone:GetSurfaceProp()
 
    local phys = self.studio.physbones[self.physboneid+1]
    if phys then return phys.surfaceprop end
    return "bloodyflesh"

end
function m_bone:GetName() return self.name end
function m_bone:GetPhysBoneID() return self.physboneid end

function m_bone:SetSurfaceProp( prop ) self.physprop = prop end
function m_bone:SetPhysBone( physbone )

    self.physboneid = physbone.id
    return self

end

-- PHYSBONE
function m_physbone:Init( name )

    self.name = name
    self.mass = 10
    self.surfaceprop = "metal"
    self.damping = 0
    self.rotdamping = 0
    self.inertia = 1
    self.volume = 1000
    return self

end

function m_physbone:SetMass( mass ) self.mass = mass end
function m_physbone:SetSurfaceProp( prop ) self.surfaceprop = prop end
function m_physbone:SetDamping( linear, angular ) self.damping, self.rotdamping = (linear or 0), (angular or 0) end
function m_physbone:SetInertia( inertia ) self.inertia = inertia end

function m_physbone:GetName() return self.name end
function m_physbone:GetMass() return self.mass end
function m_physbone:GetSurfaceProp() return self.surfaceprop end
function m_physbone:GetDamping() return self.damping end
function m_physbone:GetRotationDamping() return self.rotdamping end
function m_physbone:GetInertia() return self.inertia end
function m_physbone:GetVolume() return self.volume end -- compute

local function v_round(v)

    local x,y,z = v:Unpack()
    local factor = 100000
    x = math.Round(x * factor) / factor
    y = math.Round(y * factor) / factor
    z = math.Round(z * factor) / factor
    return Vector(x,y,z)

end

function m_physbone:BuildFromPoints( points )

    local cpoint = {}
    for _,v in ipairs(points) do
        cpoint[#cpoint+1] = v_round( v )
    end

    local ledge = BuildLedgeFromPoints(points)
    local surf = BuildSurface( {ledge} )

    self.physics = surf
    return self

end

function m_physbone:BuildFromEntireModel()

    local points = {}
    for _,v in ipairs(self.studio.vertices) do
        points[#points+1] = v_round( v.position )
    end

    local ledge = BuildLedgeFromPoints(points)
    local surf = BuildSurface( {ledge} )

    self.physics = surf
    return self

end

-- PHYS CONSTRAINT
function m_physconstraint:Init()

    return self

end

-- HITBOX
function m_hitbox:Init( name, mins, maxs )

    self.name = name
    self.bone = 0
    self.bbmins = mins or Vector(-8,-8,-8)
    self.bbmaxs = maxs or Vector(8,8,8)

    return self

end

function m_hitbox:SetBounds( mins, maxs )

    self.bbmins:Set( mins )
    self.bbmaxs:Set( maxs )

end

-- HITBOX SET
function m_hitboxset:Init( name )

    self.hitboxes = {}
    self.name = name
    return self

end

function m_hitboxset:Hitbox( name )

    local box = m_hitbox.New( name )
    self.hitboxes[#self.hitboxes+1] = box
    return box

end

-- STUDIO
function m_studio:Init()

    self.attachments = {}
    self.bones = {}
    self.bonecontrollers = {}
    self.bodyparts = {}
    self.hitboxsets = {}
    self.localanims = {}
    self.localsequences = {}
    self.textures = {}
    self.cdtextures = {}
    self.flexdescriptors = {}
    self.flexcontrollers = {}
    self.flexcontrollerui = {}
    self.flexrules = {}
    self.ikchains = {}
    self.iklocks = {}
    self.mouths = {}
    self.poseparams = {}
    self.modelgroups = {}
    self.animblocks = {}
    self.skins = {}
    self.bbmins = Vector()
    self.bbmaxs = Vector()
    self.vertices = {}
    self.tangents = {}
    self.keyvalues = new_keytable()
    self.surfaceprop = "metal"
    
    local mdl = self.keyvalues:AddSection("mdlkeyvalue")
    local prop_data = mdl:AddSection("prop_data")
    prop_data["base"] = "Flesh.Tiny"

    self.bones_byname = {}
    self.hitboxsets_byname = {}
    self.materials = {}
    self.physbones = {}

    self:Bone("rootbone")

    return self

end

-- todo: implement
function m_studio:GetChecksum() return 8888 end
function m_studio:GetName() return "generated.mdl" end
function m_studio:GetEyePos() return Vector(0,0,0) end
function m_studio:GetIllumPos() return Vector(0,0,0) end
function m_studio:GetHullMin() return self.bbmins end
function m_studio:GetHullMax() return self.bbmaxs end
function m_studio:GetViewBBMin() return Vector(0,0,0) end
function m_studio:GetViewBBMax() return Vector(0,0,0) end
function m_studio:GetFlags() return 0 end
function m_studio:GetMass() return 0 end
function m_studio:GetContents() return CONTENTS_SOLID end
function m_studio:GetKeyValuesString() return self.keyvalues:ToString() end
function m_studio:GetSurfaceProp() 
    
    local test = nil
    for _, v in ipairs(self.physbones) do
        local prop = v:GetSurfaceProp()
        if test == nil then
            test = prop
        elseif test ~= prop then
            test = nil
            break
        end
    end

    return test or self.surfaceprop
end

function m_studio:Bone( name )

    if name == nil then name = "bone_" .. #self.bones end
    if self.bones_byname[name] then return self.bones_byname[name] end
    local bone = m_bone.New( name )
    bone.studio = self
    bone.id = #self.bones
    self.bones[#self.bones+1] = bone
    self.bones_byname[name] = bone
    return bone

end

function m_studio:PhysBone( name )

    if name == nil then name = "physbone_" .. #self.physbones end
    local phys = m_physbone.New( name )
    phys.studio = self
    phys.id = #self.physbones
    self.physbones[#self.physbones+1] = phys
    return phys

end

function m_studio:HitboxSet( name )

    if name == nil then name = "hitboxset_" .. #self.hitboxsets end
    if self.hitboxsets_byname[name] then return self.hitboxsets_byname[name] end
    local set = m_hitboxset.New( name )
    set.studio = self
    self.hitboxsets[#self.hitboxsets+1] = set
    self.hitboxsets_byname[name] = set
    return set

end

function m_studio:BodyPart( name )

    if name == nil then name = "body_" .. #self.bodyparts end
    local part = m_bodypart.New( name )
    part.studio = self
    self.bodyparts[#self.bodyparts+1] = part
    return part

end

function m_studio:AssignMeshIDs()

    local num = 0
    for _, part in ipairs( self.bodyparts ) do
        for _, model in ipairs(part.models) do
            for k, mesh in ipairs(model.meshes) do
                mesh.meshid = num
                num = num + 1
            end
        end
    end

end

function m_studio:ComputeBounds()

    self.bbmins = Vector(math.huge, math.huge, math.huge)
    self.bbmaxs = Vector(-math.huge, -math.huge, -math.huge)

    for _, part in ipairs( self.bodyparts ) do
        for _, model in ipairs(part.models) do
            for k, mesh in ipairs(model.meshes) do
                vmin_into(mesh.bbmins, self.bbmins)
                vmin_into(mesh.bbmaxs, self.bbmins)
                vmax_into(mesh.bbmins, self.bbmaxs)
                vmax_into(mesh.bbmaxs, self.bbmaxs)
            end
        end
    end

end

function m_studio:EnsureHitBoxes()

    if #self.hitboxsets > 0 then return end
    local box = self:HitboxSet("default"):Hitbox("hb0")
    box:SetBounds( self.bbmins, self.bbmaxs )

end

function m_studio:ComputeMaterialList()

    local cd_hash = {}
    local m_hash = {}

    for _, mat in ipairs(self.materials) do

        local filename = tostring(mat)
        local path = string.GetPathFromFilename(filename)
        local file = string.GetFileFromFilename(filename)

        if not cd_hash[path] then
            cd_hash[path] = true
            self.cdtextures[#self.cdtextures+1] = path
        end

        if not m_hash[file] then
            m_hash[file] = true
            self.textures[#self.textures+1] = {
                name = file,
                flags = 0,
                used = 0,
            }
        end

    end

    print("CDTEXTURES:")
    PrintTable(self.cdtextures)

    print("TEXTURES:")
    PrintTable(self.textures)

end

function m_studio:Write( filename )

    self:AssignMeshIDs()
    self:ComputeBounds()
    self:EnsureHitBoxes()
    self:ComputeMaterialList()

    if #self.localsequences == 0 then
        self.localsequences[#self.localsequences+1] = {
            name = "idle",
            bbmins = self.bbmins,
            bbmaxs = self.bbmaxs,
            events = {},
            autolayers = {},
            iklocks = {},
            activitymodifiers = {},
        }

        self.localanims[#self.localanims+1] = {
            name = "@idle",
            fps = 30,
            numframes = 1,
            movements = {},
            localhierarchy = {},
        }
    end

    local b,e = xpcall(WriteStudioMDL, function( err )
        print("Error writing mdl: " .. tostring(err))
        debug.Trace()
    end, self)

    local b,e = xpcall(WriteStudioVVD, function( err )
        print("Error writing vvd: " .. tostring(err))
        debug.Trace()
    end, self)

    local b,e = xpcall(WriteStudioVTX, function( err )
        print("Error writing vtx: " .. tostring(err))
        debug.Trace()
    end, self)

    local b,e = xpcall(WriteStudioPHY, function( err )
        print("Error writing phy: " .. tostring(err))
        debug.Trace()
    end, self)


end

function New()

    return m_studio.New()

end

return __lib