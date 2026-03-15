local ox_inventory = exports.ox_inventory

-- ─────────────────────────────────────────────────────────────
--  Per-player capacity-grant tracking (dual-mode safe)
--  Keys: source  →  { inventoryBag = itemName|nil, clothingBag = bool }
-- ─────────────────────────────────────────────────────────────
local playerState = {}

local function GetPlayerState(src)
    if not playerState[src] then
        playerState[src] = { inventoryBag = nil, clothingBag = false }
    end
    return playerState[src]
end

-- ─────────────────────────────────────────────────────────────
--  Helpers
-- ─────────────────────────────────────────────────────────────

--- Return the base (without-bag) weight and slot counts for a player.
--- Reads current inventory values and subtracts active grants.
local function GetBaseCapacity(src)
    local inventory = ox_inventory:GetInventory(src)
    if not inventory then return nil end

    local state = GetPlayerState(src)
    local baseWeight = inventory.maxWeight
    local baseSlots  = inventory.slots

    if state.inventoryBag then
        local bc = Config.Backpacks[state.inventoryBag]
        if bc then
            baseWeight = baseWeight - (bc.weightIncrease or 0)
            baseSlots  = baseSlots  - (bc.slotIncrease  or 0)
        end
    end

    if state.clothingBag then
        baseWeight = baseWeight - Config.ClothingBagWeightIncrease
        baseSlots  = baseSlots  - Config.ClothingBagSlotIncrease
    end

    return { weight = baseWeight, slots = baseSlots }
end

--- Clamp helper — never let the server set values below the base.
local function ClampedSet(src, newWeight, newSlots, baseWeight, baseSlots)
    if newWeight < baseWeight then newWeight = baseWeight end
    if newSlots  < baseSlots  then newSlots  = baseSlots  end
    ox_inventory:SetMaxWeight(src, newWeight)
    ox_inventory:SetSlotCount(src, newSlots)
end

--- Check whether the player can safely remove the capacity grant.
--- excludeSlot  – the slot the bag item itself occupies (skip it).
local function CanRemoveBag(src, baseWeight, baseSlots, excludeSlot)
    local inventory = ox_inventory:GetInventory(src)
    if not inventory then return false, nil end

    if Config.EnableWeightIncrease and inventory.weight > baseWeight then
        return false, 'weight'
    end

    if Config.EnableSlotIncrease then
        local items = ox_inventory:GetInventoryItems(src)
        for _, item in pairs(items) do
            if item.slot > baseSlots and item.slot ~= excludeSlot then
                return false, 'slots'
            end
        end
    end

    return true, nil
end

--- Verify that `src` actually owns the named backpack item in their inventory.
--- Returns true only when the item is found.
local function PlayerOwnsBackpack(src, itemName)
    local count = ox_inventory:GetItem(src, itemName, nil, true)
    return count and count > 0
end

-- ─────────────────────────────────────────────────────────────
--  Inventory-bag net events
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('yote_backpack:increaseCapacity', function(itemName)
    if not Config.UseInventoryBags then return end

    local src = source
    local bc  = Config.Backpacks[itemName]
    if not bc then return end

    -- Security: ensure the caller actually has this item
    if not PlayerOwnsBackpack(src, itemName) then
        print(('[yote_backpacks] Security: player %s tried to grant capacity for %s without owning it'):format(src, itemName))
        return
    end

    local state = GetPlayerState(src)

    -- Idempotency: already granted for this bag type
    if state.inventoryBag == itemName then return end

    -- If they somehow have a different bag grant active, remove it first
    if state.inventoryBag then
        local oldBc = Config.Backpacks[state.inventoryBag]
        if oldBc then
            local inv = ox_inventory:GetInventory(src)
            if inv then
                if Config.EnableWeightIncrease then
                    ox_inventory:SetMaxWeight(src, inv.maxWeight - (oldBc.weightIncrease or 0))
                end
                if Config.EnableSlotIncrease then
                    ox_inventory:SetSlotCount(src, inv.slots - (oldBc.slotIncrease or 0))
                end
            end
        end
    end

    state.inventoryBag = itemName

    local inv = ox_inventory:GetInventory(src)
    if not inv then return end

    if Config.EnableWeightIncrease and bc.weightIncrease then
        ox_inventory:SetMaxWeight(src, inv.maxWeight + bc.weightIncrease)
    end
    if Config.EnableSlotIncrease and bc.slotIncrease then
        ox_inventory:SetSlotCount(src, inv.slots + bc.slotIncrease)
    end
end)

RegisterNetEvent('yote_backpack:decreaseCapacity', function(itemName)
    if not Config.UseInventoryBags then return end

    local src = source
    local bc  = Config.Backpacks[itemName]
    if not bc then return end

    local state = GetPlayerState(src)

    -- Only remove the grant if we actually granted it for this bag
    if state.inventoryBag ~= itemName then return end

    state.inventoryBag = nil

    local inv = ox_inventory:GetInventory(src)
    if not inv then return end

    local base = GetBaseCapacity(src)
    if not base then return end

    local newWeight = inv.maxWeight - (bc.weightIncrease or 0)
    local newSlots  = inv.slots     - (bc.slotIncrease  or 0)

    ClampedSet(src, newWeight, newSlots, base.weight, base.slots)
end)

-- ─────────────────────────────────────────────────────────────
--  Clothing-bag net events
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('yote_backpack:increaseClothingBag', function()
    if not Config.UseClothingBags then return end

    local src   = source
    local state = GetPlayerState(src)

    -- Idempotency
    if state.clothingBag then return end

    state.clothingBag = true

    local inv = ox_inventory:GetInventory(src)
    if not inv then return end

    if Config.EnableWeightIncrease then
        ox_inventory:SetMaxWeight(src, inv.maxWeight + Config.ClothingBagWeightIncrease)
    end
    if Config.EnableSlotIncrease then
        ox_inventory:SetSlotCount(src, inv.slots + Config.ClothingBagSlotIncrease)
    end
end)

RegisterNetEvent('yote_backpack:decreaseClothingBag', function()
    if not Config.UseClothingBags then return end

    local src   = source
    local state = GetPlayerState(src)

    if not state.clothingBag then return end

    state.clothingBag = false

    local inv = ox_inventory:GetInventory(src)
    if not inv then return end

    local base = GetBaseCapacity(src)
    if not base then return end

    local newWeight = inv.maxWeight - Config.ClothingBagWeightIncrease
    local newSlots  = inv.slots     - Config.ClothingBagSlotIncrease

    ClampedSet(src, newWeight, newSlots, base.weight, base.slots)
end)

RegisterNetEvent('yote_backpack:canRemoveClothingBag', function()
    if not Config.UseClothingBags then return end

    local src   = source
    local state = GetPlayerState(src)
    if not state.clothingBag then
        -- No grant active — safe to remove
        TriggerClientEvent('yote_backpack:allowRemoveBag', src)
        return
    end

    local inv = ox_inventory:GetInventory(src)
    if not inv then return end

    -- Base = current maxWeight minus the clothing-bag grant (and any inventory-bag grant)
    local base = GetBaseCapacity(src)
    if not base then return end

    -- For the purpose of this check, the "safe" capacity is without the clothing bag
    local safeWeight = base.weight
    local safeSlots  = base.slots

    local canRemove, reason = CanRemoveBag(src, safeWeight, safeSlots)

    if canRemove then
        TriggerClientEvent('yote_backpack:allowRemoveBag', src)
    else
        TriggerClientEvent('yote_backpack:cannotRemoveBag', src, reason)
    end
end)

-- ─────────────────────────────────────────────────────────────
--  Player disconnect cleanup
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    playerState[source] = nil
end)

-- ESX logout cleanup (if Framework = 'esx')
if Config.Framework == 'esx' then
    AddEventHandler('esx:playerLogout', function(src)
        playerState[src] = nil
    end)
end

-- ─────────────────────────────────────────────────────────────
--  ox_inventory hooks (run after ox_inventory is ready)
-- ─────────────────────────────────────────────────────────────

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do Wait(500) end

    if not Config.UseInventoryBags then return end

    local backpackItemFilter = {}
    for itemName in pairs(Config.Backpacks) do
        backpackItemFilter[itemName] = true
    end

    -- Hook 1: Prevent removing a backpack that has excess weight/items in extra slots
    local backpackRemovalHook = ox_inventory:registerHook('swapItems', function(payload)
        local itemName    = payload.fromSlot.name
        local backpackConfig = Config.Backpacks[itemName]

        if backpackConfig and payload.fromType == 'player' then
            local src  = payload.source
            local inv  = ox_inventory:GetInventory(src)
            if not inv then return false end

            -- Base capacity = current minus this bag's grant
            local baseWeight = inv.maxWeight - (backpackConfig.weightIncrease or 0)
            local baseSlots  = inv.slots     - (backpackConfig.slotIncrease  or 0)

            local canRemove, reason = CanRemoveBag(src, baseWeight, baseSlots, payload.fromSlot.slot)

            if not canRemove then
                local messages = {
                    weight = Strings.too_much_weight,
                    slots  = Strings.items_in_extra_slots
                }
                TriggerClientEvent('ox_lib:notify', src, {
                    type        = 'error',
                    title       = Strings.cannot_remove_backpack,
                    description = messages[reason]
                })
                return false
            end
        end

        return true
    end, {
        print      = false,
        itemFilter = backpackItemFilter,
    })

    -- Hook 2: Enforce one-backpack limit on swap
    local swapHook = ox_inventory:registerHook('swapItems', function(payload)
        if not Config.OneBagInInventory then return true end

        if payload.toType == 'player'
            and payload.toInventory ~= payload.fromInventory
            and Config.Backpacks[payload.fromSlot.name]
        then
            local src = payload.source
            for itemName in pairs(Config.Backpacks) do
                local count = ox_inventory:GetItem(src, itemName, nil, true)
                if count and count > 0 then
                    TriggerClientEvent('ox_lib:notify', src, {
                        type        = 'error',
                        title       = Strings.action_incomplete,
                        description = Strings.one_backpack_only
                    })
                    return false
                end
            end
        end

        return true
    end, {
        print      = false,
        itemFilter = backpackItemFilter,
    })

    -- Hook 3: Enforce one-backpack limit on createItem — block immediately (no delay)
    local createHook
    if Config.OneBagInInventory then
        createHook = ox_inventory:registerHook('createItem', function(payload)
            if not Config.Backpacks[payload.item.name] then return end

            local src   = payload.inventoryId
            local items = ox_inventory:GetInventoryItems(src)

            for _, item in pairs(items) do
                if Config.Backpacks[item.name] then
                    -- Already has a bag — block creation outright
                    TriggerClientEvent('ox_lib:notify', src, {
                        type        = 'error',
                        title       = Strings.action_incomplete,
                        description = Strings.one_backpack_only
                    })
                    return false
                end
            end
        end, {
            print      = false,
            itemFilter = backpackItemFilter,
        })
    end

    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName ~= GetCurrentResourceName() then return end
        ox_inventory:removeHooks(backpackRemovalHook)
        ox_inventory:removeHooks(swapHook)
        if createHook then ox_inventory:removeHooks(createHook) end
    end)
end)

-- ─────────────────────────────────────────────────────────────
--  Portable stash (optional)
-- ─────────────────────────────────────────────────────────────

if Config.PortableStashMode then
    -- Stash logic lives in server/stash.lua; nothing extra needed here
    -- because fxmanifest includes server/**.lua
end
