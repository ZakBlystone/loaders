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
local __lib = alchemy.MakeLib()

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
local m_studio = createMeta()

-- STRIP
function m_strip:Init()

    self.vertices = {}
    self.indices = {}
    return self

end

function m_strip:Vertex( position, normal, u, v, tx, ty, tz, tw, weights )

    local vertex = {
        position = position,
        normal = normal,
        u = u,
        v = v,
        tangent = {x=tx, y=ty, z=tz, w=tw},
        weights = weights,
    }
    self.vertices[#self.vertices+1] = vertex

end

function m_strip:Triangle( i0, i1, i2 )

    local indices = self.indices
    local base = #indices
    local vertoff = #self.vertices
    indices[base+1] = i0 > 0 and i0 or vertoff + i0 + 1
    indices[base+2] = i1 > 0 and i1 or vertoff + i1 + 1
    indices[base+3] = i2 > 0 and i2 or vertoff + i2 + 1

end

function m_strip:Render()

    local indices = self.indices
    local vertices = self.vertices

    mesh.Begin( MATERIAL_TRIANGLES, #indices / 3 )

    for i=1, #indices, 3 do
        local i0 = indices[i]
        local i1 = indices[i+1]
        local i2 = indices[i+2]

        local v0 = vertices[i0]
        local v1 = vertices[i1]
        local v2 = vertices[i2]

        if v0 and v1 and v2 then

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
    end

    mesh.End()

end

-- MESH
function m_mesh:Init( material )

    self.strips = {}
    self.material = material
    return self

end

function m_mesh:Strip()

    local strip = m_strip.New()
    self.strips[#self.strips+1] = strip
    return strip

end

function m_mesh:Render()

    render.SetMaterial(self.material)
    for _, strip in ipairs(self.strips) do
        strip:Render()
    end

end

-- MODEL
function m_model:Init( name )

    self.meshes = {}
    self.name = name
    return self

end

function m_model:Mesh( material )

    local m = m_mesh.New( material )
    self.meshes[#self.meshes+1] = m
    return m

end

function m_model:Render()

    for _, msh in ipairs(self.meshes) do
        msh:Render()
    end

end

-- BODY PART
function m_bodypart:Init( name )

    self.models = {}
    self.name = name
    return self

end

function m_bodypart:Model( name )

    if name == nil then name = "model_" .. #self.models end
    local model = m_model.New( name )
    self.models[#self.models+1] = model
    return model

end

-- STUDIO
function m_studio:Init()

    self.bodyparts = {}
    return self

end

function m_studio:BodyPart( name )

    if name == nil then name = "body_" .. #self.bodyparts end
    local bp = m_bodypart.New( name )
    self.bodyparts[#self.bodyparts+1] = bp
    return bp

end

function m_studio:Write()

end

function New()

    return m_studio.New()

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

    local studio = studiomdl.New()
    local model = studio:BodyPart():Model()
    local msh = model:Mesh( Material("models/flesh") )
    local strip = msh:Strip()

    make_cube(strip, 30, Vector(0,0,50))

    hook.Add("PostDrawOpaqueRenderables", "test_studio", function()
    
        model:Render()

    end)

end

return __lib