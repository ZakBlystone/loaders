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
local m_strip = createMeta()
local m_bone = createMeta()
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
    return self

end

function m_strip:Vertex( position, normal, u, v, tx, ty, tz, tw, weights )

    local vertices = self.mesh.model.part.studio.vertices
    local tangents = self.mesh.model.part.studio.tangents

    vmin_into(position, self.bbmins)
    vmax_into(position, self.bbmaxs)
    vmin_into(position, self.mesh.bbmins)
    vmax_into(position, self.mesh.bbmaxs)
    self.mesh.model.numvertices = self.mesh.model.numvertices + 1

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

function m_strip:Triangle( i0, i1, i2 )

    local vertices = self.mesh.model.part.studio.vertices
    local indices = self.indices
    local base = #indices
    local vertoff = #vertices
    indices[base+1] = i0 > 0 and i0 or vertoff + i0 + 1
    indices[base+2] = i1 > 0 and i1 or vertoff + i1 + 1
    indices[base+3] = i2 > 0 and i2 or vertoff + i2 + 1

end

function m_strip:Render()

    local indices = self.indices
    local vertices = self.mesh.model.part.studio.vertices
    local tangents = self.mesh.model.part.studio.tangents

    mesh.Begin( MATERIAL_TRIANGLES, #indices / 3 )

    for i=1, #indices, 3 do
        local i0 = indices[i]
        local i1 = indices[i+1]
        local i2 = indices[i+2]

        local v0 = vertices[i0]
        local v1 = vertices[i1]
        local v2 = vertices[i2]

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

-- MESH
function m_mesh:Init( material )

    self.strips = {}
    self.material = material
    self.flexes = {}
    self.materialidx = 0
    self.meshid = 0
    self.bbmins = Vector(math.huge, math.huge, math.huge)
    self.bbmaxs = Vector(-math.huge, -math.huge, -math.huge)
    return self

end

function m_mesh:Strip()

    local strip = m_strip.New()
    strip.mesh = self
    self.strips[#self.strips+1] = strip
    return strip

end

function m_mesh:GetCenter() return (self.bbmins + self.bbmaxs) / 2 end

function m_mesh:Render()

    render.SetMaterial(self.material)
    for _, strip in ipairs(self.strips) do
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

    local m = m_mesh.New( material )
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
    return self

end

function m_bone:GetPos() return self.matrix:GetTranslation() end
function m_bone:GetAnglesQuat()

    -- todo: implement
    return quat()

end

function m_bone:GetQuatAlignment()

    -- todo: implement
    return quat()

end

function m_bone:GetAngles() return self.matrix:GetAngles() end
function m_bone:GetBindMatrix() return self.bindmatrix end
function m_bone:GetFlags() return self.flags end
function m_bone:GetContents() return CONTENTS_SOLID end
function m_bone:GetSurfaceProp() return "solidmetal" end
function m_bone:GetName() return self.name end

-- HITBOX SET
function m_hitboxset:Init( name )

    self.hitboxes = {}
    self.name = name
    return self

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
    self.keyvalues = [[
{
    prop_data {
    "base" "Metal.Large"  }
}
    ]]

    self.bones_byname = {}
    self.hitboxsets_byname = {}

    self:Bone("rootbone")
    self:HitboxSet("default")

    return self

end

-- todo: implement
function m_studio:GetChecksum() return 8888 end
function m_studio:GetName() return "generated-model" end
function m_studio:GetEyePos() return Vector(0,0,0) end
function m_studio:GetIllumPos() return Vector(0,0,0) end
function m_studio:GetHullMin() return self.bbmins end
function m_studio:GetHullMax() return self.bbmaxs end
function m_studio:GetViewBBMin() return Vector(0,0,0) end
function m_studio:GetViewBBMax() return Vector(0,0,0) end
function m_studio:GetFlags() return 0 end
function m_studio:GetMass() return 0 end
function m_studio:GetContents() return CONTENTS_SOLID end
function m_studio:GetKeyValuesString() return self.keyvalues end

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

function m_studio:Write( filename )

    self:AssignMeshIDs()
    self:ComputeBounds()

    local b,e = xpcall(WriteStudioMDL, function( err )
        print("Error writing mdl: " .. tostring(err))
        debug.Trace()
    end, self)

    local b,e = xpcall(WriteStudioVVD, function( err )
        print("Error writing vvd: " .. tostring(err))
        debug.Trace()
    end, self)

end

function New()

    return m_studio.New()

end

return __lib