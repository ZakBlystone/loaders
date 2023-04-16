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
        alchemy.utils,
    }
})

alchemy.InstallDataWriter()

local gma_ext = ".dat"
local mounted_content_path = "temp/__mounted"

file.CreateDir(mounted_content_path)

local files = file.Find(mounted_content_path .. "/*.dat", "DATA")
for _, f in ipairs(files) do
    file.Delete( mounted_content_path .. "/" .. f )
end

local meta = {}
meta.__index = meta

function meta:AddData( virtualPath, data, size )

    size = size or #data

    self.files[#self.files+1] = {
        size = size,
        data = data,
        crc = util.CRC(data),
        virtualPath = virtualPath,
    }

end

function meta:AddFile( virtualPath, filename, path )

    local f = file.Open( filename, "rb", path or "DATA" )
    local size = f:Size()
    local data = f:Read(size)
    f:Close()

    self.files[#self.files+1] = {
        size = size,
        data = data,
        crc = util.CRC(data),
        virtualPath = virtualPath,
    }

end

function meta:Write( filename )

    local ok = open_data( filename )
    if not ok then print("Failed to open GMA, probably mounted") return false end

    uint32(0x44414D47)   -- ident
    uint8(3)             -- version
    uint32(0)            -- steamID
    uint32(0)            --
    uint32(0)            -- timestamp
    uint32(0)            --
    uint8(0)             -- required
    nullstr(self.title)  -- title
    
    -- description json
    local json = {
        description = self.desc,
        type = self.type,
        tags = self.tags,
    }
    nullstr(util.TableToJSON(json))
    nullstr("Author Name")
    
    -- addon version
    uint32(1)
    
    -- file index
    for k,v in ipairs(self.files) do
        uint32(k)                   -- file num
        nullstr(v.virtualPath)      -- filename (lower case)
        uint32(v.size)              -- uint64 lower bits
        uint32(0)                   -- uint64 upper bits
        uint32(v.crc)               -- crc
    end
    
    uint32(0) -- zero for end of files
    
    -- file data
    for k,v in ipairs(self.files) do
        raw_data(v.data)
    end
    
    end_data()
    
    -- read contents, create CRC
    print("Create CRC")
    local gma_crc_f = file.Open(filename, "rb", "DATA")
    local gma_crc = util.CRC( gma_crc_f:Read( gma_crc_f:Size() ) )
    gma_crc_f:Close()
    
    -- append CRC
    print("Write CRC: " .. gma_crc)
    local gma_crc_f = file.Open(filename, "ab", "DATA")
    gma_crc_f:WriteULong( gma_crc )
    gma_crc_f:Close()

    return true

end

function meta:Mount()

    local filename = "temp/__mounted/" .. self.unique_name .. gma_ext
    self:Write(filename)

    local b,files = game.MountGMA( "data/" .. filename )
    if b then
        PrintTable(files)
    else
        print("Error mounting GMA")
    end

end

function New( name )

    return setmetatable({
        files = {},
        title = name or "generated-gma",
        desc = "Generated GMA Data",
        type = "map",
        tags = { "build", "fun" },
        unique_name = guid_to_string( new_guid(), true ),
    }, meta)

end

return __lib