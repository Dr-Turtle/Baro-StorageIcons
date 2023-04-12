local helpTexts = {}
helpTexts["add"] = "usage: storageicons add [ITEM]...\
replace [ITEM]... with the name or id of each item to be added (separated by spaces, case-insensitive)\
example: storageicons add harpoongun \"auto-injector headset\"\
- adds Harpoon Gun and Auto-Injector Headset to whitelist"
helpTexts["remove"] = "usage: storageicons remove [ITEM]...\
replace [ITEM]... with the name or id of each item to be removed (separated by spaces, case-insensitive)\
example: storageicons remove explosivecrate \"secure metal crate\"\
- adds Explosive Crate and Secure Metal Crate to whitelist"
helpTexts["scale"] = "usage: scale [SCALE]\
changes the scale of icons (relative to the storage icon's scale), it is recommended to have this between 0.5 and 1\
example: storageicons scale 0.5\
- sets the scale to 0.5"
helpTexts["help"] = "usage: storageicons [COMMAND]\
- replace [COMMAND] with one of the following commands\n\
add/remove [ITEM]...\
- adds or removes ITEMs from the whitelist\
- replace [ITEM]... with the name or id of each item to be added/removed (separated by spaces, case-insensitive)\n\
scale [SCALE]\
- changes the scale of icons (relative to the storage icon's scale), it is recommeneded to have this between 0.5 and 1\
whitelist\
- lists all items in the whitelist\n\
reload\
- reloads the config file and manually resets cached data (use this if something is broken)\n\
reset\
- resets the config to defaults"

local confirmReset = false


local function writeConfig()
    local newConfig = {}
    for k, v in pairs(StorageIcons.Config["whitelistItems"]) do
        if v then
            newConfig[k] = v
        end
    end
    StorageIcons.Config["whitelistItems"] = newConfig
    File.Write(StorageIcons.Path .. "/config.json", json.serialize(StorageIcons.Config))
end


Game.AddCommand("storageicons", "configures storageicons", function (command)
    -- If the last command was "reset" but this command does not confirm, ask for confirmation again the next time the command is executed
    if command[1] ~= "reset" then
        confirmReset = false
    end

    if command[1] == "reload" then
        StorageIcons.Config = json.parse(File.Read(StorageIcons.Path .. "/config.json"))
        StorageIcons.resetCache()
        print("config has been reloaded and cache has been cleared")

    elseif command[1] == "add" or command[1] == "remove" then
        local itemsInvalid = false
        local identifiers = {}
        for k, arg in pairs(command) do
            if k ~= 1 then
                local prefab = ItemPrefab.GetItemPrefab(arg)
                if prefab == nil then
                    print("could not find item with the id/name \"", arg, "\"")
                    itemsInvalid = true
                else
                    table.insert(identifiers, tostring(prefab.Identifier))
                end
            end
        end

        if command[2] then
            if not itemsInvalid then
                -- validate that the command will succeed before changing the config
                local failed
                for identifier in identifiers do
                    if command[1] == "add" then
                        if StorageIcons.Config["whitelistItems"][identifier] then
                            print("\"", ItemPrefab.GetItemPrefab(identifier), "\" is already in the whitelist")
                            failed = true
                        end
                    else
                        if not StorageIcons.Config["whitelistItems"][identifier] then
                            print("failed to remove \"", ItemPrefab.GetItemPrefab(identifier), "\", not in the whitelist")
                            failed = true
                        end
                    end
                end
                if not failed then
                    for identifier in identifiers do
                        if command[1] == "add" then
                            StorageIcons.Config["whitelistItems"][identifier] = true
                        else
                            StorageIcons.Config["whitelistItems"][identifier] = false
                        end
                    end
                    writeConfig()
                    if command[1] == "add" then
                        print(#command - 1, " item(s) have been added to the whitelist")
                    else
                        print(#command - 1, " item(s) have been removed from the whitelist")
                    end
                else
                    if command[1] == "add" then
                        print("one or more items were already in the whitelist, config was not modified")
                    else
                        print("one or more items were not in the whitelist, config was not modified")
                    end
                end
            else
                print("one or more items could not be found, config was not changed")
            end
        else
            print(helpTexts["add"])
        end

    elseif command[1] == "remove" then
        if command[2] then
            local prefab = ItemPrefab.GetItemPrefab(command[2])
            local identifier = tostring(prefab.Identifier)
            StorageIcons.Config["whitelistItems"][identifier] = nil
            writeConfig()
        else
            print(helpTexts["remove"])
        end

    elseif command[1] == "reset" then
        if confirmReset then
            File.Write(StorageIcons.Path .. "/config.json", json.serialize(dofile(StorageIcons.Path .. "/Lua/defaultconfig.lua")))
            StorageIcons.Config = json.parse(File.Read(StorageIcons.Path .. "/config.json"))
            StorageIcons.resetCache()
            print("Config has been reset")
            confirmReset = false
        else
            print("This will reset your StorageIcons config, type this command again to confirm")
            confirmReset = true
        end

    elseif command[1] == "whitelist" then
        for v in pairs(StorageIcons.Config["whitelistItems"]) do
            print(ItemPrefab.GetItemPrefab(v).Name, " | ", v)
        end

    elseif command[1] == "scale" then
        local scale
        if command[2] then
            local success = pcall(function()
                scale = tonumber(command[2])
            end)
            if success then
                StorageIcons.Config["iconScale"] = scale
                writeConfig()
                StorageIcons.resetCache()
            else
                print("Could not convert \"", command[2], "\" to a number")
            end
        else
            print(helpTexts["scale"])
            print("Current scale is ", StorageIcons.Config["iconScale"])
        end
    else
        print(helpTexts["help"])
    end
end)
