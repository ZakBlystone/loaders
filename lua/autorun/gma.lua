if true then return end

if SERVER then AddCSLuaFile() end

module("gma", package.seeall)

local gma_ext = ".dat"

function GMA_DiskFile( filename, path )

    local tab = { 
        size = function()
            local f = file.Open( filename, "rb", path or "DATA" )
            local size = f:Size()
            f:Close()
            return size
        end,
        data = function()
            local f = file.Open( filename, "rb", path or "DATA" )
            local data = f:Read(f:Size())
            f:Close()
            return data
        end,
    }
    return tab

end

function GMA_BufferFile( data, data_size )

    local tab = { 
        size = function() return data_size end,
        data = function() return data end,
    }
    return tab

end

function GMA_StringFile( data )

    local tab = { 
        size = function() return #data end,
        data = function() return data end,
    }
    return tab

end

function GMA_Write( name, 
    package_files, 
    package_title, 
    package_desc, 
    package_type, 
    package_tags )

    local file_listing = {}
    for k,v in pairs(package_files) do
        if type(k) ~= "string" then
            error("Package file-keys must be strings")
        end
    
        if type(v) ~= "table" then 
            error("Invalid file entry, expected table") 
        end

        if not v.size or not v.data then
            error("File entry is not valid")
        end

        --print("Add File: " .. k)

        file_listing[#file_listing+1] = {
            name = string.lower(k), 
            size = v.size(),
            data = v.data(),
        }
    end

    local gma = file.Open(name .. gma_ext, "wb", "DATA")
    if not gma then print("Failed to open GMA, probably mounted") return false end
    
    -- ident / ver
    gma:WriteULong(0x44414D47)
    gma:WriteByte(3)
    
    -- steamid
    gma:WriteULong(0)
    gma:WriteULong(0)
    
    -- timestamp
    gma:WriteULong(0)
    gma:WriteULong(0)
    
    -- required
    gma:WriteByte(0)
    
    -- title
    gma:Write(package_title or "generated-gma") gma:WriteByte(0)
    
    -- description
    local json = {
        description = package_desc or "A generated gma file from Lua",
        type = package_type or "map",
        tags = package_tags or { "build", "fun" },
    }
    gma:Write(util.TableToJSON(json)) gma:WriteByte(0)
    gma:Write("Author Name") gma:WriteByte(0)
    
    -- addon version
    gma:WriteULong(1)
    
    -- file index
    for k,v in ipairs(file_listing) do
        gma:WriteULong(k)                   -- file num
        gma:Write(v.name) gma:WriteByte(0)  -- filename (lower case)
        gma:WriteULong( v.size )            -- uint64 lower bits
        gma:WriteULong(0)                   -- uint64 upper bits
        gma:WriteULong( util.CRC(v.data) )  -- crc
    end
    
    gma:WriteULong(0) -- zero for end of files
    
    -- file data
    for k,v in ipairs(file_listing) do
        local before = gma:Tell()
        gma:Write( v.data )
        local diff = gma:Tell() - before
        --print("Write File: " .. v.name .. " : " .. diff .. " bytes")
    end
    
    gma:Close()
    
    -- read contents, create CRC
    print("Create CRC")
    local gma_crc_f = file.Open(name .. gma_ext, "rb", "DATA")
    local gma_crc = util.CRC( gma_crc_f:Read( gma_crc_f:Size() ) )
    gma_crc_f:Close()
    
    -- append CRC
    print("Write CRC: " .. gma_crc)
    local gma_crc_f = file.Open(name .. gma_ext, "ab", "DATA")
    gma_crc_f:WriteULong( gma_crc )
    gma_crc_f:Close()

    return true

end

function GMA_Mount( name )

    local b,files = game.MountGMA( "data/" .. name .. gma_ext )
    if b then
        PrintTable(files)
    else
        print("Error mounting GMA")
    end

end

if SERVER then

    --[[util.PrecacheModel("models/avatar_frame.mdl")

    local prop = ents.Create("prop_physics")
    prop:SetPos(Vector(0,0,150))
    prop:SetModel("models/avatar_frame.mdl")
    prop:Spawn()]]

end

if CLIENT then

    --print("GMA TEST")

    --[[GMA_Write("modeltest",
        {
            --["models/avatar_frame.dx80.vtx"] = GMA_DiskFile( "mdl_input/avatar_frame.dx80.vtx" ),
            ["models/avatar_frame.dx90.vtx"] = GMA_DiskFile( "mdl_input/avatar_frame.dx90.vtx" ),
            ["models/avatar_frame.mdl"] = GMA_DiskFile( "mdl_input/avatar_frame.mdl" ),
            ["models/avatar_frame.phy"] = GMA_DiskFile( "mdl_input/avatar_frame.phy" ),
            --["models/avatar_frame.sw.vtx"] = GMA_DiskFile( "mdl_input/avatar_frame.sw.vtx" ),
            ["models/avatar_frame.vvd"] = GMA_DiskFile( "mdl_input/avatar_frame.vvd" ),
        })

    GMA_Mount("modeltest")]]

    --G_TEST_MODEL = nil
    --G_TEST_MODEL = G_TEST_MODEL or ents.CreateClientProp("models/avatar_frame.mdl")
    --G_TEST_MODEL:SetPos(Vector(0,0,100))
    --G_TEST_MODEL:Spawn()
    --G_TEST_MODEL:Remove()

end