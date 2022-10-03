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

__alchemy = __alchemy or {}

function Init()
    __alchemy = {}
end

function MakeLib( opts )

    local _lib = {}
    setmetatable(_lib, {__index = _G})

    if opts then
        for _, lib in ipairs(opts.using or {}) do
            for k,v in pairs(lib) do
                _lib[k] = _lib[k] or v
            end
        end
    end

    setfenv(2, _lib)
    return _lib

end

utils = include("alchemy/common/utils.lua")

local loader_formats = {
    ["bsp"] = function()
        if not __alchemy.bsp_loader then
            __alchemy.bsp_loader = include("alchemy/loaders/bsp/bsp3.lua")
        end
        return __alchemy.bsp_loader
    end,
    ["mdl"] = function()
        if not __alchemy.mdl_loader then
            __alchemy.mdl_loader = include("alchemy/loaders/mdl/mdl3.lua")
        end
        return __alchemy.mdl_loader
    end,
}

local compiler_formats = {
    ["mdl"] = function()
        if not __alchemy.mdl_compiler then
            __alchemy.mdl_compiler = include("alchemy/compilers/mdl/studiomdl.lua")
        end
        return __alchemy.mdl_compiler
    end,
    ["gma"] = function()
        if not __alchemy.gma_compiler then
            __alchemy.gma_compiler = include("alchemy/compilers/gma/gma.lua")
        end
        return __alchemy.gma_compiler
    end,
    ["phy"] = function()
        if not __alchemy.phy_compiler then
            __alchemy.phy_compiler = include("alchemy/compilers/phy/phy.lua")
        end
        return __alchemy.phy_compiler
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