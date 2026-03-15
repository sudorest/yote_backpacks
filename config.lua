-- ██    ██  ██████  ████████ ███████       ██████   █████   ██████ ██   ██ ██████   █████   ██████ ██   ██ ███████
-- ╚██  ██  ██    ██    ██    ██            ██   ██ ██   ██ ██      ██  ██  ██   ██ ██   ██ ██      ██  ██  ██
--  ╚████   ██    ██    ██    █████         ██████  ███████ ██      █████   ██████  ███████ ██      █████   ███████
--   ╚██    ██    ██    ██    ██            ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ ██      ██  ██       ██
--    ██     ██████     ██    ███████       ██████  ██   ██  ██████ ██   ██ ██      ██   ██  ██████ ██   ██ ███████

Config = {}

-- ═══════════════════════════════════════════════════════════════
--                         GENERAL SETTINGS
-- ═══════════════════════════════════════════════════════════════

Config.OneBagInInventory = true  -- Prevent players from carrying more than one backpack
Config.RemoveBagInVehicle = true -- Hide the backpack prop when entering a vehicle
                                  -- Capacity (extra slots/weight) is preserved while seated

-- Framework: 'qbcore' | 'esx' | nil
-- Set to 'esx' to enable esx:playerLoaded / esx:onPlayerLogout support.
-- Leave as nil (or 'qbcore') for QBCore (uses QBCore:Client:OnPlayerLoaded).
Config.Framework = nil

-- Debug
Config.EnableDebugCommand = false -- Enable debug command
Config.DebugCommandName   = 'baginfo'

-- ═══════════════════════════════════════════════════════════════
--                      BACKPACK SYSTEM TYPE
-- ═══════════════════════════════════════════════════════════════

-- Both systems can be enabled simultaneously.
-- UseInventoryBags  — item-based backpacks with 3D props.
-- UseClothingBags   — illenium-appearance clothing component detection.
Config.UseInventoryBags = true
Config.UseClothingBags  = false

-- ═══════════════════════════════════════════════════════════════
--                    WEIGHT & SLOT SETTINGS
-- ═══════════════════════════════════════════════════════════════

Config.EnableWeightIncrease = true
Config.EnableSlotIncrease   = true

-- ═══════════════════════════════════════════════════════════════
--              ILLENIUM-APPEARANCE INTEGRATION
-- ═══════════════════════════════════════════════════════════════

Config.ClothingBagWeightIncrease = 10000 -- Grams added when a clothing bag is detected
Config.ClothingBagSlotIncrease   = 10

-- Clothing Bag Blacklist — drawables (component 5) to ignore.
-- [drawable] = true        → block all textures of that drawable
-- [drawable] = {0, 1, 2}  → block only those specific textures
Config.ClothingBagBlacklist = {
    [0] = true, -- drawable 0 = no bag / default torso
    -- [1] = {0, 1, 2},
}

-- ═══════════════════════════════════════════════════════════════
--                       TIMING SETTINGS
-- ═══════════════════════════════════════════════════════════════

Config.SpawnDelay        = 4500  -- ms to wait after player load before equipping bag
Config.BackpackCheckDelay = 1000 -- (legacy, kept for compatibility)

-- ═══════════════════════════════════════════════════════════════
--                  BACKPACK ATTACHMENT SETTINGS
-- ═══════════════════════════════════════════════════════════════

Config.DefaultBackpackOffset = {
    x = 0.07,
    y = -0.11,
    z = -0.05,
}

Config.DefaultBackpackRotation = {
    x = 0.0,
    y = 90.0,
    z = 175.0,
}

Config.BackpackBone = 24818 -- Ped bone index used for prop attachment

-- ═══════════════════════════════════════════════════════════════
--                CUSTOM BACKPACK CONFIGURATIONS
-- ═══════════════════════════════════════════════════════════════

-- Only used when UseInventoryBags = true.
-- Add as many entries as you need.
Config.Backpacks = {
    ['backpack'] = {
        label          = 'Backpack',
        model          = `sf_prop_sf_backpack_03a`,
        weightIncrease = 10000, -- Additional weight capacity in grams
        slotIncrease   = 10,    -- Additional inventory slots
        offset         = nil,   -- nil = use DefaultBackpackOffset
        rotation       = nil,   -- nil = use DefaultBackpackRotation
    },
    ['duffel_bag'] = {
        label          = 'Duffel Bag',
        model          = `h4_p_h4_m_bag_var22_arm_s`,
        weightIncrease = 15000,
        slotIncrease   = 10,
        offset         = { x = -0.28, y = -0.02, z = -0.04 },
        rotation       = { x = 0.0,   y = 90.0,  z = 175.0 },
    },
}

-- ═══════════════════════════════════════════════════════════════
--                     PORTABLE STASH (OPTIONAL)
-- ═══════════════════════════════════════════════════════════════

-- When enabled, designated backpack items open a personal stash instead of
-- (or in addition to) granting extra inventory capacity.
-- Requires server/stash.lua — see that file for further options.
Config.PortableStashMode = false

-- List of item names that should act as portable stashes.
-- Items NOT listed here continue to behave as normal capacity-boosting bags.
Config.PortableStashBackpacks = {
    -- 'stash_bag',
}

-- ═══════════════════════════════════════════════════════════════
--                    NOTIFICATION STRINGS
-- ═══════════════════════════════════════════════════════════════

Strings = {
    action_incomplete      = 'Action Incomplete',
    one_backpack_only      = 'You can only have 1 backpack equipped!',
    too_much_weight        = 'You are carrying too much weight. Remove items first.',
    items_in_extra_slots   = 'You have items in extra slots. Move them first.',
    cannot_remove_backpack = 'Cannot Remove Backpack',
}

-- Thank you @sugaa for the amazing suggestions!
