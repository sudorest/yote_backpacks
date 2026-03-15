local bagEquipped     = false   -- true when prop is attached AND capacity granted
local bagObj          = nil     -- entity handle for the prop
local currentBagType  = nil     -- itemName of equipped bag, or nil
local ox_inventory    = exports.ox_inventory
local ped             = cache.ped
local justConnect     = true
local clothingBagActive  = false
local checkingRemoval    = false
local lastBagDrawable    = 0
local lastBagTexture     = 0

-- ─────────────────────────────────────────────────────────────
--  Internal helpers
-- ─────────────────────────────────────────────────────────────

local function GetBackpackConfig(itemName)
    return Config.Backpacks[itemName]
end

--- Attach the prop and (optionally) grant server-side capacity.
--- Pass skipCapacity=true when re-attaching after a ped/vehicle change
--- so we do not double-grant.
local function PutOnBag(itemName, skipCapacity)
    if bagEquipped then return end

    local bc = GetBackpackConfig(itemName)
    if not bc then return end

    local hash     = bc.model
    local offset   = bc.offset   or Config.DefaultBackpackOffset
    local rotation = bc.rotation or Config.DefaultBackpackRotation

    lib.requestModel(hash, 1000)
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.5)
    bagObj = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, true, false, false)
    AttachEntityToEntity(
        bagObj, ped, GetPedBoneIndex(ped, Config.BackpackBone),
        offset.x,   offset.y,   offset.z,
        rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true
    )

    bagEquipped    = true
    currentBagType = itemName

    if not skipCapacity then
        TriggerServerEvent('yote_backpack:increaseCapacity', itemName)
    end
end

--- Delete the prop only — does NOT touch server capacity.
--- Used when entering a vehicle with RemoveBagInVehicle=true so that
--- the extra slots stay available for inventory interaction while seated.
local function RemoveBagProp()
    if DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
        bagObj = nil
    end

    if currentBagType then
        local bc = GetBackpackConfig(currentBagType)
        if bc then SetModelAsNoLongerNeeded(bc.model) end
    end

    -- Note: bagEquipped and currentBagType are intentionally NOT cleared here.
    -- The bag is still logically equipped; only the visual is hidden.
end

--- Full removal: delete prop AND revoke server capacity.
local function RemoveBag()
    if not bagEquipped then return end

    if DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
        bagObj = nil
    end

    if currentBagType then
        local bc = GetBackpackConfig(currentBagType)
        if bc then SetModelAsNoLongerNeeded(bc.model) end
        TriggerServerEvent('yote_backpack:decreaseCapacity', currentBagType)
    end

    bagEquipped    = false
    currentBagType = nil
end

local function CheckForBackpack()
    for itemName in pairs(Config.Backpacks) do
        if ox_inventory:Search('count', itemName) > 0 then
            return itemName
        end
    end
    return nil
end

local function IsClothingBagBlacklisted(drawable, texture)
    if not Config.ClothingBagBlacklist then return false end

    local entry = Config.ClothingBagBlacklist[drawable]
    if not entry then return false end

    if type(entry) == 'table' then
        for _, blockedTexture in ipairs(entry) do
            if blockedTexture == texture then return true end
        end
        return false
    end

    return true
end

local function UpdateClothingBagCapacity()
    if not Config.UseClothingBags or checkingRemoval then return end

    local currentDrawable = GetPedDrawableVariation(ped, 5)
    local currentTexture  = GetPedTextureVariation(ped, 5)
    local hasValidBag     = currentDrawable > 0
        and not IsClothingBagBlacklisted(currentDrawable, currentTexture)

    if hasValidBag and not clothingBagActive then
        clothingBagActive = true
        lastBagDrawable   = currentDrawable
        lastBagTexture    = currentTexture
        TriggerServerEvent('yote_backpack:increaseClothingBag')
    elseif not hasValidBag and clothingBagActive then
        checkingRemoval = true
        TriggerServerEvent('yote_backpack:canRemoveClothingBag')
    elseif hasValidBag and clothingBagActive
        and (currentDrawable ~= lastBagDrawable or currentTexture ~= lastBagTexture)
    then
        lastBagDrawable = currentDrawable
        lastBagTexture  = currentTexture
    end
end

-- ─────────────────────────────────────────────────────────────
--  Net events from server
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('yote_backpack:cannotRemoveBag', function(reason)
    checkingRemoval = false
    SetPedComponentVariation(ped, 5, lastBagDrawable, lastBagTexture, 0)

    local messages = {
        weight = Strings.too_much_weight,
        slots  = Strings.items_in_extra_slots
    }

    if messages[reason] then
        lib.notify({
            type        = 'error',
            title       = Strings.cannot_remove_backpack,
            description = messages[reason]
        })
    end
end)

RegisterNetEvent('yote_backpack:allowRemoveBag', function()
    checkingRemoval   = false
    clothingBagActive = false
    lastBagDrawable   = 0
    lastBagTexture    = 0
    TriggerServerEvent('yote_backpack:decreaseClothingBag')
end)

-- ─────────────────────────────────────────────────────────────
--  Framework: player loaded
-- ─────────────────────────────────────────────────────────────

local function OnPlayerLoaded()
    if not Config.UseInventoryBags then return end

    CreateThread(function()
        Wait(Config.SpawnDelay)
        local foundBag = CheckForBackpack()
        if foundBag then PutOnBag(foundBag) end
    end)
end

-- QBCore
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', OnPlayerLoaded)

-- ESX
if Config.Framework == 'esx' then
    AddEventHandler('esx:playerLoaded', OnPlayerLoaded)
end

-- ─────────────────────────────────────────────────────────────
--  ox_inventory update (handles initial load + bag swaps)
-- ─────────────────────────────────────────────────────────────

AddEventHandler('ox_inventory:updateInventory', function(changes)
    if not Config.UseInventoryBags then return end

    if justConnect then
        -- Fix 1b: clear the flag BEFORE the wait so a second fired event
        -- during the delay does not trigger a second PutOnBag.
        justConnect = false
        Wait(Config.SpawnDelay)
        local foundBag = CheckForBackpack()
        if foundBag then PutOnBag(foundBag) end
        return
    end

    for _, v in pairs(changes) do
        if type(v) == 'table' or type(v) == 'boolean' then
            local foundBag = CheckForBackpack()

            if foundBag ~= currentBagType then
                if bagEquipped then
                    RemoveBag()
                    Wait(100)
                end
                if foundBag then PutOnBag(foundBag) end
            end
            break
        end
    end
end)

-- ─────────────────────────────────────────────────────────────
--  Cache callbacks
-- ─────────────────────────────────────────────────────────────

lib.onCache('ped', function(value)
    ped = value

    if Config.UseClothingBags then
        Wait(500)
        UpdateClothingBagCapacity()
    end

    -- Fix 1c: re-attach prop without re-granting capacity (skipCapacity=true).
    if Config.UseInventoryBags and bagEquipped and currentBagType then
        -- Destroy old prop silently (already detached from old ped entity)
        if DoesEntityExist(bagObj) then
            DeleteObject(bagObj)
            bagObj = nil
        end
        -- Temporarily clear bagEquipped so PutOnBag's guard doesn't block us,
        -- but keep currentBagType so skipCapacity path knows what to re-attach.
        local tempBag = currentBagType
        bagEquipped   = false
        -- currentBagType is reset inside PutOnBag; pass true to skip server event
        Wait(100)
        PutOnBag(tempBag, true)
    end
end)

lib.onCache('vehicle', function(value)
    if not Config.UseInventoryBags then return end
    if GetResourceState('ox_inventory') ~= 'started' then return end

    if value then
        -- Entering a vehicle
        if Config.RemoveBagInVehicle then
            -- Fix 1a / Issue #1: hide the prop only; keep capacity active so
            -- the extra slots are visible when the player opens their inventory
            -- while seated.
            RemoveBagProp()
        end
        -- If RemoveBagInVehicle=false: do nothing — prop stays on.
    else
        -- Leaving a vehicle
        if bagEquipped and currentBagType then
            -- Re-attach prop without re-granting (capacity was never removed)
            if not DoesEntityExist(bagObj) then
                local bc     = GetBackpackConfig(currentBagType)
                local hash   = bc and (bc.model)
                if hash then
                    local offset   = bc.offset   or Config.DefaultBackpackOffset
                    local rotation = bc.rotation or Config.DefaultBackpackRotation
                    lib.requestModel(hash, 1000)
                    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.5)
                    bagObj = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, true, false, false)
                    AttachEntityToEntity(
                        bagObj, ped, GetPedBoneIndex(ped, Config.BackpackBone),
                        offset.x,   offset.y,   offset.z,
                        rotation.x, rotation.y, rotation.z,
                        true, true, false, true, 1, true
                    )
                end
            end
        elseif not bagEquipped then
            -- Fallback: not equipped at all (e.g. RemoveBagInVehicle=false path
            -- where the bag was never removed, so this branch should rarely fire)
            local foundBag = CheckForBackpack()
            if foundBag and not bagEquipped then PutOnBag(foundBag) end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────
--  Clothing bag polling thread
-- ─────────────────────────────────────────────────────────────

if Config.UseClothingBags then
    CreateThread(function()
        while true do
            Wait(500)
            UpdateClothingBagCapacity()
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
--  Debug command
-- ─────────────────────────────────────────────────────────────

if Config.EnableDebugCommand then
    RegisterCommand(Config.DebugCommandName or 'baginfo', function()
        local drawable   = GetPedDrawableVariation(ped, 5)
        local texture    = GetPedTextureVariation(ped, 5)
        local blacklisted = IsClothingBagBlacklisted(drawable, texture)
        print(('[yote_backpacks] debug — drawable:%d texture:%d blacklisted:%s equipped:%s bag:%s'):format(
            drawable, texture, tostring(blacklisted), tostring(bagEquipped), tostring(currentBagType)
        ))
        lib.notify({
            type        = 'info',
            description = ('Drawable: %d | Texture: %d | Blacklisted: %s | Bag: %s'):format(
                drawable, texture, tostring(blacklisted), tostring(currentBagType)
            )
        })
    end)
end
