local helpTexts = {}
helpTexts["add"] = "usage: storageicons add [ITEM]...\
replace [ITEM]... with the name or id of each item to be added (separated by spaces, case-insensitive)\
example: storageicons add harpoongun \"auto-injector headset\"\
- adds Harpoon Gun and Auto-Injector Headset to whitelist"
helpTexts["remove"] = "usage: storageicons remove [ITEM]...\
replace [ITEM]... with the name or id of each item to be removed (separated by spaces, case-insensitive)\
example: storageicons remove explosivecrate \"secure metal crate\"\
- adds Explosive Crate and Secure Metal Crate to whitelist"
helpTexts["config"] = "usage: config [OPTION] [VALUE]\
sets the config [OPTION] to [VALUE]\
when used by itself, lists all config options, a description, the current value and default value\
example: storageicons config\
- list all config options\
example: storageicons config scale 0.5\
- sets the item scale to 0.5"
helpTexts["help"] = "usage: storageicons [COMMAND]\
- replace [COMMAND] with one of the following commands\
\
add/remove [ITEM]...\
- adds or removes ITEMs from the whitelist\
- replace [ITEM]... with the name or id of each item to be added/removed (separated by spaces, case-insensitive)\
\
config\
- list all config options\
\
config [OPTION] [VALUE]\
- sets the config [OPTION] to [VALUE]\
\
whitelist\
- lists all items in the whitelist\
\
reload\
- reloads the config file and manually resets cached data (use this if something is broken)\
\
reset\
- resets the config to defaults"

local configNameMap = {
    scale = "iconScale",
    background = "showBackgroundForContrast",
    showfour = "grid2x2",
    showplus = "showPlusSignForExtraItems"
}
local configDescriptions = {}
configDescriptions["scale"] = "changes the scale of icons (relative to the storage icon's scale), it is recommended to have this between 0.5 and 1"
configDescriptions["background"] = "when true, adds a transparent background to make items easier to see"
configDescriptions["showfour"] = "when true, displays up to four item types in a 2x2 grid"
configDescriptions["showplus"] = "when true, adds a plus sign when there are more item types than can be displayed"

local defaultConfig = dofile(StorageIcons.Path .. "/Lua/defaultconfig.lua")
local confirmReset = false


local function writeConfig(config)
    File.Write(StorageIcons.Path .. "/config.json", json.serialize(config))
end

local function readConfig()
    return json.parse(File.Read(StorageIcons.Path .. "/config.json"))
end


Game.AddCommand("storageicons", "configures storageicons", function (command)
    -- If the last command was "reset" but this command does not confirm, ask for confirmation again the next time the command is executed
    if command[1] ~= "reset" then
        confirmReset = false
    end

    if command[1] == "reload" then
        StorageIcons.Config = readConfig()
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
                    writeConfig(StorageIcons.Config)
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

    elseif command[1] == "reset" then
        if confirmReset then
            writeConfig(defaultConfig)
            StorageIcons.Config = readConfig()
            StorageIcons.resetCache()
            print("Config has been reset")
            confirmReset = false
        else
            print("This will reset your StorageIcons config, type this command again to confirm")
            confirmReset = true
        end

    elseif command[1] == "whitelist" then
        for k, v in pairs(StorageIcons.Config["whitelistItems"]) do
            -- there isn't a good way to remove a value from a table, so values that were once enabled will still appear in the config, but set to false
            if v then
                print(ItemPrefab.GetItemPrefab(k).Name, " | ", k)
            end
        end

    elseif command[1] == "config" then
        if not command[2] then
            for name, key in pairs(configNameMap) do
                local value = tostring(StorageIcons.Config[key])
                local default = tostring(defaultConfig[key])
                print(name .. " | " .. value .. " (default " .. default .. ")")
                print("- " .. configDescriptions[name] .. "\n")
            end
            print("you can change a config option by running `storageicons config [OPTION] [VALUE]`")
            return
        end

        local name = command[2]
        local key = configNameMap[command[2]]
        local unparsedValue = command[3]
        if not key then
            print(name .. " is not a valid option. Run `storageicons config` to list all options")
            return
        end

        if not unparsedValue then
            print("must provide a value")
            return
        end

        if type(defaultConfig[key]) == "number" then
            local value = tonumber(unparsedValue)
            if value == nil then
                print(unparsedValue .. " is not a valid number. " .. name .. " must be a number")
                return
            end
            StorageIcons.Config[key] = value
        end
        if type(defaultConfig[key]) == "boolean" then
            if unparsedValue == "true" then StorageIcons.Config[key] = true
            elseif unparsedValue == "false" then StorageIcons.Config[key] = false
            else
                print(name .. " must be `true` or `false` (without the quotes)")
                return
            end
        end
        writeConfig(StorageIcons.Config)
        StorageIcons.resetCache()

    else
        print(helpTexts["help"])
    end
end)
