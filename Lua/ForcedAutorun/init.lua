if SERVER then return end

StorageIcons = {}
StorageIcons.Path = table.pack(...)[1]
local configPath = StorageIcons.Path .. "/config.json"
local config = dofile(StorageIcons.Path .. "/Lua/defaultconfig.lua")

if File.Exists(configPath) then
    local overrides = json.parse(File.Read(configPath))
    for i, _ in pairs(config) do
        if overrides[i] ~= nil then
            config[i] = overrides[i]
        end
    end
end
StorageIcons.Config = config

-- write the config back to disk to ensure it lists any new options
File.Write(configPath, json.serialize(config))

dofile(StorageIcons.Path .. "/Lua/storageicons.lua")
dofile(StorageIcons.Path .. "/Lua/commands.lua")
