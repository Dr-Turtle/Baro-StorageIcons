LuaUserData.RegisterType("Barotrauma.Sprite")
LuaUserData.RegisterType("Barotrauma.VisualSlot")

local cache = {}


function StorageIcons.resetCache()
    cache = {}
end


local function inWhitelist(identifier)
    for k in pairs(StorageIcons.Config["whitelistItems"]) do
        if identifier == k then
            return true
        end
    end
    return false
end


-- called when any item is moved into an inventory, does not account for some cases
Hook.Add("inventoryPutItem", "moveItem", function(inventory, item, characterUser, index, removeItemBool)
    local targetInventory = inventory.Owner
    if inWhitelist(targetInventory.Prefab.Identifier) and cache[targetInventory.ID] then
        cache[targetInventory.ID]["update"] = true
    -- scale may need to be updated due to some inventories having different scale
    elseif inWhitelist(item.Prefab.Identifier) and cache[item.ID] then
        cache[item.ID]["update"] = true
    end
end)


-- if an item is not placed into a new inventory (e.g. dropped on the ground) or in certain cases such as a fabricator pulling items from storage,
-- inventoryPutItem is not called, so this is used to update inventories items are taken from instead
-- RemoveItem(item)
Hook.Patch("Barotrauma.Inventory", "RemoveItem", function(instance, ptable)
    local inventory = ptable["item"].ParentInventory
    if not inventory then return end
    local item = inventory.Owner
    if item then
        if inWhitelist(item.Prefab.Identifier) and cache[item.ID] then
            cache[item.ID]["update"] = true
        end
    end
end, Hook.HookMethodType.Before)


-- firing weapons needs their magazine inventory updated, might be a better way to do this
-- public override bool Use(float deltaTime, Character character = null)
Hook.Patch("Barotrauma.Items.Components.RangedWeapon", "Use", function(instance, ptable)
    local character = ptable["character"]
    for item in character.heldItems do
        if item.OwnInventory then
            if cache[item.ID] then
                cache[item.ID]["update"] = true
            end
            local itemList = item.OwnInventory.FindAllItems()
            if itemList then
                for subItem in item.OwnInventory.FindAllItems() do
                    if inWhitelist(subItem.Prefab.Identifier) then
                        if cache[subItem.ID] then
                            cache[subItem.ID]["update"] = true
                        end
                    end
                end
            end
        end
    end
end)


Hook.Patch("Barotrauma.Inventory", "DrawSlot", function(instance, ptable)
    if not ptable["drawItem"] then return end
    local item = ptable["item"]
    if not item then return end

    local slot = ptable["slot"]
    if not item.OwnInventory then return end
    if not inWhitelist(item.Prefab.Identifier) then return end
    local itemCache = cache[item.ID]
    if itemCache then
        if not itemCache["update"] then
            itemCache["sprite"].Draw(itemCache["spriteBatch"], slot.Rect.Center.ToVector2(), itemCache["color"], itemCache["rotation"], itemCache["scale"])
            return
        end
    end
    local spriteBatch = ptable["spriteBatch"]
    local rect = ptable["slot"].Rect

    if item.OwnInventory.IsEmpty() then return end

    local itemList = item.OwnInventory.FindAllItems()

    local itemCounts = {}
    local maxCount = 0
    local sprite
    local color

    -- Determine which item is the most abundant and set sprite and color accordingly
    for v in itemList do
        local id = v.Prefab.Identifier
        if itemCounts[id] then
            itemCounts[id] = itemCounts[id] + 1
        else
            itemCounts[id] = 1
        end
        if itemCounts[id] > maxCount then
            sprite = v.Prefab.InventoryIcon
            -- noticed a modded item didn't have an InventoryIcon, idk if it's supposed to be optional
            if not sprite then
                sprite = v.Prefab.Sprite
            end
            color = v.GetSpriteColor()
            maxCount = itemCounts[id]
        end
    end
    local scale = math.min(math.min((rect.Width - 10) / sprite.size.X, (rect.Height - 10) / sprite.size.Y), 2.0) * StorageIcons.Config["iconScale"]
    local itemPos = rect.Center.ToVector2()
    local rotation = 0
    sprite.Draw(spriteBatch, itemPos, color, rotation, scale)
    -- store draw arguments to be used instead of recalculating if the inventory was not uppdated
    cache[item.ID] = {}
    cache[item.ID]["sprite"] = sprite
    cache[item.ID]["spriteBatch"] = spriteBatch
    cache[item.ID]["color"] = color
    cache[item.ID]["rotation"] = rotation
    cache[item.ID]["scale"] = scale
    cache[item.ID]["update"] = false
end, Hook.HookMethodType.After)


Hook.Add("roundStart", "clearCacheStart", function() StorageIcons.resetCache() end)
Hook.Add("roundEnd", "clearCacheEnd", function() StorageIcons.resetCache() end)
