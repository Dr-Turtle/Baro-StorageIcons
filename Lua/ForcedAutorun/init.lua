if SERVER then return end

StorageIcons = {}
StorageIcons.Path = table.pack(...)[1]

if not File.Exists(StorageIcons.Path .. "/config.json") then
    File.Write(StorageIcons.Path .. "/config.json", json.serialize(dofile(StorageIcons.Path .. "/Lua/defaultconfig.lua")))
end

StorageIcons.Config = json.parse(File.Read(StorageIcons.Path .. "/config.json"))

dofile(StorageIcons.Path .. "/Lua/storageicons.lua")
dofile(StorageIcons.Path .. "/Lua/commands.lua")
