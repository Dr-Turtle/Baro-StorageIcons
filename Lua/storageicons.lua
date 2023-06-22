local update, drawItems, mostAbundant

-- cached data pertaining to drawing an icon
---@class iconCache
---@field itemPrefabs table
---@field drawInfo table
---@field drawOffset Microsoft.Xna.Framework.Vector2
---@field hoverableParent boolean
---@field update boolean
---@field plusSign table
local cache = {}

local background = Sprite(StorageIcons.Path .. "/Assets/OuterGlow.png")
local backgroundColor = Color(128, 128, 128, 64)

local plus = Sprite(StorageIcons.Path .. "/Assets/Plus.png")

function StorageIcons.resetCache()
	cache = {}
end

local function inWhitelist(identifier)
	for k, v in pairs(StorageIcons.Config.whitelistItems) do
		if identifier == k then
			return v
		end
	end
	return false
end


-- called when any item is moved into an inventory, does not account for some cases
Hook.Add("inventoryPutItem", "moveItem", function(inventory, item, characterUser, index, removeItemBool)
	---@cast inventory Barotrauma.Inventory
	---@class Barotrauma.Item
	local targetInventory = inventory.Owner

	if inWhitelist(targetInventory.Prefab.Identifier) and cache[targetInventory.ID] then
		cache[targetInventory.ID].update = true
	end

	if inWhitelist(item.Prefab.Identifier) and cache[item.ID] then
		-- scale may need to be updated due to some inventories having different scale
		cache[item.ID].update = true
	end
end)


-- if an item is not placed into a new inventory (e.g. dropped on the ground) or in certain cases such as a fabricator pulling items from storage,
-- inventoryPutItem is not called, so this is used to update inventories items are taken from instead
-- RemoveItem(item)
Hook.Patch("Barotrauma.Inventory", "RemoveItem", function(instance, ptable)
	---@class Barotrauma.Inventory
	---@diagnostic disable-next-line: undefined-field
	local inventory = ptable["item"].ParentInventory

	if not inventory then return end

	---@class Barotrauma.Item
	local container = inventory.Owner

	if container and inWhitelist(container.Prefab.Identifier) and cache[container.ID] then
		cache[container.ID].update = true
	end
end, Hook.HookMethodType.Before)


-- firing weapons needs their magazine inventory updated, might be a better way to do this
-- public override bool Use(float deltaTime, Character character = null)
Hook.Patch("Barotrauma.Items.Components.RangedWeapon", "Use", function(instance, ptable)
	---@class Barotrauma.Character
	local character = ptable["character"]
	for item in character.HeldItems do
		if not item.OwnInventory then return end

		if cache[item.ID] then
			cache[item.ID].update = true
		end

		local itemList = item.OwnInventory.FindAllItems()
		if not itemList then return end

		for subItem in item.OwnInventory.FindAllItems() do
			if inWhitelist(subItem.Prefab.Identifier) and cache[subItem.ID] then
				cache[subItem.ID].update = true
			end
		end
	end
end)


-- public static void DrawSlot(SpriteBatch spriteBatch, Inventory inventory, VisualSlot slot, Item item, int slotIndex, bool drawItem = true, InvSlotType type = InvSlotType.Any)
Hook.Patch("Barotrauma.Inventory", "DrawSlot", function(instance, ptable)
	---@class Barotrauma.Item
	local item = ptable["item"]

	if not ptable["drawItem"] or not item or not item.OwnInventory or not inWhitelist(item.Prefab.Identifier) then return end

	local itemCache = cache[item.ID]

	---@class Microsoft.Xna.Framework.Graphics.SprtieBatch
	local spriteBatch = ptable["spriteBatch"]

	---@class Barotrauma.VisualSlot
	local slot = ptable["slot"]

	local rect = slot.Rect

	if itemCache then
		if not itemCache.update then
			if itemCache.hoverableParent then
				itemCache.drawOffset = slot.DrawOffset
			end

			drawItems(spriteBatch, rect, itemCache)
			return
		end
	end

	if not item.OwnInventory.IsEmpty() then
		update(item, slot, spriteBatch)
	end

end, Hook.HookMethodType.After)


function drawItems(spriteBatch, rect, cached)
	local prefabs = cached.itemPrefabs
	local rectCenter = Vector2.Add(rect.Center.ToVector2(), cached.drawOffset)
	local rotation = 0

	if #prefabs == 1 or not StorageIcons.Config.grid2x2 then
		-- if there's only one, draw it max size
		local sprite = cached.drawInfo[prefabs[1]].sprite
		local color = cached.drawInfo[prefabs[1]].color
		local scale = cached.drawInfo[prefabs[1]].scale * StorageIcons.Config.iconScale
		sprite.Draw(spriteBatch, rectCenter, color, rotation, scale)
	else
		-- otherwise, draw the four items in a 2x2 grid
		local offsetX = rect.Width / 4
		local offsetY = rect.Height / 4
		local positions = {
			Vector2.Add(rectCenter, Vector2(-offsetX, -offsetY)),
			Vector2.Add(rectCenter, Vector2(offsetX, -offsetY)),
			Vector2.Add(rectCenter, Vector2(-offsetX, offsetY)),
			Vector2.Add(rectCenter, Vector2(offsetX, offsetY)),
		}

		for i, prefab in ipairs(prefabs) do
			local itemPos = positions[i]
			local sprite = cached.drawInfo[prefab].sprite
			local color = cached.drawInfo[prefab].color
			local scale = cached.drawInfo[prefab].scale / 2
			sprite.Draw(spriteBatch, itemPos, color, rotation, scale)
		end
	end

	if cached.plusSign then
		local ps = cached.plusSign
		ps.sprite.Draw(spriteBatch, Vector2.Add(ps.position, cached.drawOffset), Color(255, 255, 255), rotation, ps.scale)
	end

	if StorageIcons.Config.showBackgroundForContrast then
		local backgroundScale = math.min(2.0, rect.Width / background.size.X, rect.Height / background.size.Y)
		background.Draw(spriteBatch, Vector2(rect.X, rect.Y), backgroundColor, 0, backgroundScale)
	end
end


-- updates or initializes an icon's cache
---@param item Barotrauma.Item
---@param slot Barotrauma.VisualSlot
function update(item, slot, spriteBatch)
	local itemCache = cache[item.ID]
	local rect = slot.Rect

	local prefabs, abundantItems, drawInfo = mostAbundant(item.OwnInventory.FindAllItems(), rect)

	-- determine if the the item is inside an inventory that is opened by hovering
	local hoverable = false
	if LuaUserData.IsTargetType(item.parentInventory.Owner, "Barotrauma.Item") then
		---@class Barotrauma.Item
		local container = item.parentInventory.Owner
		if container.parentInventory and LuaUserData.IsTargetType(container.parentInventory.Owner, "Barotrauma.Character")
				and container.parentInventory.IsInventoryHoverAvailable(container.parentInventory.Owner, container.GetComponentString("ItemContainer")) then
			hoverable = true
		end
	end

	-- store draw arguments to be used instead of recalculating if the inventory was not uppdated
	cache[item.ID] = {}
	itemCache = cache[item.ID]

	-- the most abundant item(s)
	itemCache.itemPrefabs = abundantItems
	-- sprite and related info about an item
	itemCache.drawInfo = drawInfo
	-- offset from slot position, mostly used in nested inventories
	itemCache.drawOffset = slot.DrawOffset
	-- if the parent container is viewable by hovering
	itemCache.hoverableParent = hoverable
	-- if cached values should be recalculated next tick
	itemCache.update = false

	local rectCenter = rect.Center.ToVector2()

	local overfilled = (not StorageIcons.Config.grid2x2 and #prefabs > 1) or #prefabs > 4
	if StorageIcons.Config.showPlusSignForExtraItems and overfilled then
		local scale = math.min(2.0, rect.Width / plus.size.X, rect.Height / plus.size.Y) / 4
		local position = Vector2.Add(rectCenter, Vector2(rect.Width / 4, -rect.Height / 8))
		itemCache.plusSign = { sprite = plus, scale = scale, position = position }
	else
		itemCache.plusSign = nil
	end

	drawItems(spriteBatch, rect, cache[item.ID])
end


---@param itemList table
---@param rect Microsoft.Xna.Framework.Rectangle
---@return table prefabs		each prefab in itemList
---@return table abundantItems	4 most abundant prefabs ordered most to least
---@return table drawInfo		sprite and related info for drawing an icon
function mostAbundant(itemList, rect)
	local itemCounts = {}
	local prefabs = {}
	local drawInfo = {}

	-- determine which item is the most abundant and set sprite and color accordingly
	for v in itemList do
		local prefab = v.Prefab
		if itemCounts[prefab] then
			itemCounts[prefab] = itemCounts[prefab] + 1
		else
			itemCounts[prefab] = 1
			table.insert(prefabs, prefab)
		end

		if not drawInfo[prefab] then
			drawInfo[prefab] = {}
			-- noticed a modded item didn't have an InventoryIcon, idk if it's supposed to be optional
			local sprite = prefab.InventoryIcon or prefab.Sprite
			drawInfo[prefab].sprite = sprite
			drawInfo[prefab].color = v.GetSpriteColor()
			drawInfo[prefab].scale = math.min(2.0, (rect.Width - 10) / sprite.size.X, (rect.Height - 10) / sprite.size.Y)
		end
	end

	table.sort(prefabs, function(a, b) return itemCounts[a] > itemCounts[b] end)
	local abundantItems = {table.unpack(prefabs, 1, math.min(4, #prefabs))}

	return prefabs, abundantItems, drawInfo
end


Hook.Add("roundStart", "clearCacheStart", function() StorageIcons.resetCache() end)
Hook.Add("roundEnd", "clearCacheEnd", function() StorageIcons.resetCache() end)
