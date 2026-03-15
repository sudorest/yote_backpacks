-- server/stash.lua
-- Portable stash support for yote_backpacks.
-- Only loaded when fxmanifest includes server/**.lua (always true by default).
-- Active only when Config.PortableStashMode = true.

if not Config.PortableStashMode then return end

local ox_inventory = exports.ox_inventory

-- ─────────────────────────────────────────────────────────────
--  Stash registration helper
-- ─────────────────────────────────────────────────────────────

--- Return a deterministic stash ID for a given player + item slot.
--- Using the item's unique server ID (metadata.id) ensures the stash persists
--- across sessions and survives server restarts.
local function GetStashId(src, itemSlot)
    return ('yote_stash_%s_%s'):format(src, itemSlot)
end

--- Open (or register) a portable stash for the calling player.
RegisterNetEvent('yote_backpack:openStash', function(itemSlot)
    local src   = source
    local items = ox_inventory:GetInventoryItems(src)
    local item  = nil

    for _, i in pairs(items) do
        if i.slot == itemSlot then
            item = i
            break
        end
    end

    if not item then return end
    if not Config.Backpacks[item.name] then return end

    -- Only act as a stash for items listed in PortableStashBackpacks
    local isStashItem = false
    for _, stashName in ipairs(Config.PortableStashBackpacks) do
        if stashName == item.name then
            isStashItem = true
            break
        end
    end
    if not isStashItem then return end

    -- Use item metadata id if available; fall back to slot-based id
    local stashId = ('yote_stash_%s_%s'):format(
        src,
        (item.metadata and item.metadata.id) or itemSlot
    )

    ox_inventory:RegisterStash(stashId, item.name, 20, 100000)
    ox_inventory:openInventory(src, 'stash', stashId)
end)
