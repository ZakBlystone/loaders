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
module("alchemy", package.seeall)

-- Common
AddCSLuaFile("alchemy/common/datareader.lua")
AddCSLuaFile("alchemy/common/datawriter.lua")
AddCSLuaFile("alchemy/common/keytable.lua")
AddCSLuaFile("alchemy/common/libdeflate.lua")
AddCSLuaFile("alchemy/common/qmath.lua")
AddCSLuaFile("alchemy/common/utils.lua")
AddCSLuaFile("alchemy/common/quickhull/face.lua")
AddCSLuaFile("alchemy/common/quickhull/halfedge.lua")
AddCSLuaFile("alchemy/common/quickhull/quickhull.lua")
AddCSLuaFile("alchemy/common/quickhull/vertex.lua")
AddCSLuaFile("alchemy/common/quickhull/vertexlist.lua")

-- Compilers
AddCSLuaFile("alchemy/compilers/gma/gma.lua")
AddCSLuaFile("alchemy/compilers/mdl/mdl.lua")
AddCSLuaFile("alchemy/compilers/mdl/studiomdl.lua")
AddCSLuaFile("alchemy/compilers/mdl/vtx.lua")
AddCSLuaFile("alchemy/compilers/mdl/vvd.lua")
AddCSLuaFile("alchemy/compilers/phy/ivp/compact_ledge_gen.lua")
AddCSLuaFile("alchemy/compilers/phy/ivp/object_polygon_tetra.lua")
AddCSLuaFile("alchemy/compilers/phy/ivp/point_hash.lua")
AddCSLuaFile("alchemy/compilers/phy/ivp/surbuild_ledge_soup.lua")
AddCSLuaFile("alchemy/compilers/phy/ivp/surbuild_pointsoup.lua")
AddCSLuaFile("alchemy/compilers/phy/ivp/surbuild_polygon_convex.lua")
AddCSLuaFile("alchemy/compilers/phy/ivp/templates.lua")
AddCSLuaFile("alchemy/compilers/phy/ivp/triangle_gen.lua")
AddCSLuaFile("alchemy/compilers/phy/ivp/types.lua")
AddCSLuaFile("alchemy/compilers/phy/phy.lua")

-- Loaders
AddCSLuaFile("alchemy/loaders/bsp/bsp3.lua")
AddCSLuaFile("alchemy/loaders/fbx/fbx.lua")
AddCSLuaFile("alchemy/loaders/mdl/mdl3.lua")
AddCSLuaFile("alchemy/loaders/mdl/vtx.lua")
AddCSLuaFile("alchemy/loaders/mdl/vvd.lua")
AddCSLuaFile("alchemy/loaders/phy/phy3.lua")

if not __alchemy then

    __alchemy = {}
    __alchemy.chunks = {}
    __alchemy.loaders = {}
    __alchemy.compilers = {}

end

function MakeLib( opts )

    local _lib = {}
    setmetatable(_lib, {__index = _G})

    for _, lib in ipairs((opts or {}).using or {}) do
        for k,v in pairs(lib) do _lib[k] = _lib[k] or v end
    end

    setfenv(2, _lib)
    return _lib

end

utils = include("alchemy/common/utils.lua")
qmath = include("alchemy/common/qmath.lua")
LibDeflate = include("alchemy/common/libdeflate.lua")
QuickHull = include("alchemy/common/quickhull/quickhull.lua")
keytable = include("alchemy/common/keytable.lua")

local function InstallChunk(filename, as_table, func_env)

    local chunk = __alchemy.chunks[filename] or CompileFile(filename, "chunk")
    __alchemy.chunks[filename] = chunk
    if as_table then
        local env = {}
        setmetatable(env, {__index = _G})
        setfenv(chunk, env)
        chunk()
        return env
    else
        setfenv(chunk, func_env)
        return chunk()
    end

end

function InstallDataReader(as_table, func_env) return InstallChunk("alchemy/common/datareader.lua", as_table, func_env) end
function InstallDataWriter(as_table, func_env) return InstallChunk("alchemy/common/datawriter.lua", as_table, func_env) end

function Init()

    __alchemy.chunks = {}
    __alchemy.loaders = {}
    __alchemy.compilers = {}

end

--[[__alchemy.loaders.bsp = include("alchemy/loaders/bsp/bsp3.lua")
__alchemy.loaders.mdl = include("alchemy/loaders/mdl/mdl3.lua")
__alchemy.loaders.fbx = include("alchemy/loaders/fbx/fbx.lua")
__alchemy.loaders.phy = include("alchemy/loaders/phy/phy3.lua")

__alchemy.compilers.mdl = include("alchemy/compilers/mdl/studiomdl.lua")
__alchemy.compilers.gma = include("alchemy/compilers/gma/gma.lua")
__alchemy.compilers.phy = include("alchemy/compilers/phy/phy.lua")]]

local loader_formats = {
    ["bsp"] = function()
        if not __alchemy.loaders.bsp then
            __alchemy.loaders.bsp = include("alchemy/loaders/bsp/bsp3.lua")
        end
        return __alchemy.loaders.bsp
    end,
    ["mdl"] = function()
        if not __alchemy.loaders.mdl then
            __alchemy.loaders.mdl = include("alchemy/loaders/mdl/mdl3.lua")
        end
        return __alchemy.loaders.mdl
    end,
    ["fbx"] = function()
        if not __alchemy.loaders.fbx then
            __alchemy.loaders.fbx = include("alchemy/loaders/fbx/fbx.lua")
        end
        return __alchemy.loaders.fbx
    end,
    ["phy"] = function()
        if not __alchemy.loaders.phy then
            __alchemy.loaders.phy = include("alchemy/loaders/phy/phy3.lua")
        end
        return __alchemy.loaders.phy
    end,
}

local compiler_formats = {
    ["mdl"] = function()
        if not __alchemy.compilers.mdl then
            __alchemy.compilers.mdl = include("alchemy/compilers/mdl/studiomdl.lua")
        end
        return __alchemy.compilers.mdl
    end,
    ["gma"] = function()
        if not __alchemy.compilers.gma then
            __alchemy.compilers.gma = include("alchemy/compilers/gma/gma.lua")
        end
        return __alchemy.compilers.gma
    end,
    ["phy"] = function()
        if not __alchemy.compilers.phy then
            __alchemy.compilers.phy = include("alchemy/compilers/phy/phy.lua")
        end
        return __alchemy.compilers.phy
    end,
}

function Loader( x )

    assert(type(x) == "string", "Format type must be a string")
    x = string.lower(x)
    assert(loader_formats[x], "No loader exists for format '" .. x .. "'")
    return loader_formats[x]()

end

function Compiler( x )

    assert(type(x) == "string", "Format type must be a string")
    x = string.lower(x)
    assert(compiler_formats[x], "No compiler exists for format '" .. x .. "'")
    return compiler_formats[x]()

end