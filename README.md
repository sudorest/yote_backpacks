# yote_backpacks

A highly configurable backpack system for FiveM using ox_inventory — visual props, expanded inventory capacity, and illenium-appearance clothing bag integration.

**Say goodbye to secondary inventories and hello to an expandable inventory!**

This script removes the fear of powergaming by NOT creating a separate backpack inventory. Instead, it dynamically increases your main ox_inventory slots and/or weight capacity. All items remain in your primary inventory — fully searchable, fully visible, no hidden compartments.

---

## Why This Matters

Traditional backpack systems create separate inventories that:
- Can be exploited for powergaming (hiding items during searches)
- Create confusion about where items are stored
- Require additional UI elements and inventory management
- Can cause item duplication or loss bugs

**yote_backpacks solves this by:**
- ✅ Expanding your **main** inventory when wearing a backpack
- ✅ Keeping all items in **one** inventory, searchable by police/admins
- ✅ No hidden storage or secondary containers
- ✅ Simple, clean, and exploit-resistant
- ✅ Seamless integration with existing ox_inventory features

---

## Features

- **0.0 ms Usage** — Optimized, event-driven with no per-frame loops
- **Single Inventory System** — No secondary inventories; just an expanded main inventory
- **Dual Mode** — Inventory item backpacks with 3D props *and* clothing bags from illenium-appearance can run simultaneously
- **Multiple Backpack Types** — Unlimited custom backpacks with unique models, weights, and slot bonuses
- **Smart Removal Prevention** — Prevents removing a backpack while overweight or using extra slots
- **Clothing Bag Blacklist** — Block specific drawable/texture combinations from granting bonuses
- **Debug Helper Command** — Identify clothing bag drawable/texture IDs in-game
- **Vehicle Integration** — Prop is hidden when entering a vehicle; extra slots/weight remain active so your inventory still reflects the bonus
- **Single Backpack Limit** — Optional enforcement of one backpack per player (blocked immediately at the hook level)
- **Server-Side Security** — Capacity events are verified server-side; spoofed events from clients are ignored
- **ESX + QBCore Support** — `Config.Framework` selects your framework
- **Optional Portable Stash** — Designate specific bag items as personal stashes (server/stash.lua)
- **Fully Configurable** — All settings, positions, and strings in config.lua

---

## Installation

1. Download or clone this repository.
2. Add the backpack items to `ox_inventory/data/items.lua` (see **Item Configuration** below).
3. Copy item images from `_inventory_images/` into `ox_inventory/web/images/`.
4. Place the resource in your `resources` directory.
5. In `server.cfg` ensure `yote_backpacks` starts **after** `ox_lib` and **after** `ox_inventory`.
6. Edit `config.lua` for your setup.
7. Restart the resource (or restart the server).

> **Note on start order**: the manifest declares `ox_inventory` as a dependency, so FiveM will enforce ordering automatically as long as ox_inventory is listed in `server.cfg` before yote_backpacks.

---

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [illenium-appearance](https://github.com/iLLeniumStudios/illenium-appearance) *(optional — only if `UseClothingBags = true`)*

---

## Configuration

All settings are in `config.lua`.

### Framework

```lua
-- 'esx' enables esx:playerLoaded / esx:onPlayerLogout handlers.
-- nil or 'qbcore' uses QBCore:Client:OnPlayerLoaded.
Config.Framework = nil
```

### System Type

```lua
Config.UseInventoryBags = true  -- Item-based backpacks with 3D props
Config.UseClothingBags  = false -- illenium-appearance clothing detection
```

Both can be enabled at the same time (dual-mode). Players will receive the capacity bonus from whichever system(s) are active for them.

### General

```lua
Config.OneBagInInventory  = true  -- Allow only one backpack at a time
Config.RemoveBagInVehicle = true  -- Hide prop when entering a vehicle
                                   -- Extra slots/weight remain active while seated
```

### Weight & Slot Settings

```lua
Config.EnableWeightIncrease = true
Config.EnableSlotIncrease   = true
```

### Clothing Bag Settings

```lua
Config.ClothingBagWeightIncrease = 10000 -- Grams added when a clothing bag is worn
Config.ClothingBagSlotIncrease   = 10
```

### Clothing Bag Blacklist

Prevent specific clothing combinations from granting bonuses:

```lua
Config.ClothingBagBlacklist = {
    [0] = true,       -- Block all textures of drawable 0 (no bag / default)
    [45] = {0, 1, 2}, -- Block only textures 0, 1, 2 of drawable 45
}
```

- `[drawable] = true` — blocks all textures
- `[drawable] = {t1, t2, …}` — blocks specific textures only

Use the debug command (`/baginfo`) to find drawable/texture IDs.

### Timing

```lua
Config.SpawnDelay = 4500 -- ms to wait after player load before equipping bag
```

### Attachment

```lua
Config.DefaultBackpackOffset   = { x = 0.07, y = -0.11, z = -0.05 }
Config.DefaultBackpackRotation = { x = 0.0,  y = 90.0,  z = 175.0 }
Config.BackpackBone            = 24818
```

### Backpack Definitions

```lua
Config.Backpacks = {
    ['backpack'] = {
        label          = 'Backpack',
        model          = `sf_prop_sf_backpack_03a`,
        weightIncrease = 10000,
        slotIncrease   = 10,
        offset         = nil,   -- nil = use DefaultBackpackOffset
        rotation       = nil,
    },
    -- Add as many entries as needed
}
```

### Portable Stash (optional)

```lua
Config.PortableStashMode = false -- Enable the portable stash system
Config.PortableStashBackpacks = {
    -- 'stash_bag', -- item names that open a stash instead of just adding capacity
}
```

See `server/stash.lua` for implementation details.

---

## Item Configuration

Add to `ox_inventory/data/items.lua`:

```lua
['backpack'] = {
    label   = 'Backpack',
    weight  = 220,
    stack   = false,
    consume = 0,
},
['duffel_bag'] = {
    label   = 'Duffel Bag',
    weight  = 350,
    stack   = false,
    consume = 0,
},
```

---

## How It Works

### Core Concept

Instead of a secondary inventory, yote_backpacks modifies `maxWeight` and `slots` on the player's ox_inventory directly:

| State | Slots | Max Weight |
|---|---|---|
| No backpack | 50 | 30 kg |
| With backpack (+10 slots, +10 kg) | 60 | 40 kg |

Everything stays in **one** inventory. Police, admins, and all existing ox_inventory tooling see all items.

### Security Model

- `increaseCapacity` verifies the player actually owns the named item before applying any grant (prevents event spoofing).
- The server tracks which grant is active per player. Duplicate or mismatched `increase` calls are ignored (idempotent).
- `decreaseCapacity` clamps: inventory values will never be set below the pre-bag base, protecting against underflow exploits.

### In-Vehicle Behaviour (Issue #1 fix)

When `RemoveBagInVehicle = true` and a player enters a vehicle, the backpack **prop** is deleted (visual only). The server-side capacity grant is intentionally **not** removed. This means:
- Extra slots and weight remain available while seated.
- Opening inventory in a vehicle shows all slots correctly.
- When the player exits, the prop is re-attached without re-triggering `increaseCapacity`.

### One-Bag Limit

The `createItem` hook blocks a second backpack from being created in the player's inventory immediately (no delay, no after-the-fact removal).

---

## Usage Modes

| `UseInventoryBags` | `UseClothingBags` | Behaviour |
|---|---|---|
| `true` | `false` | Item backpacks only |
| `false` | `true` | Clothing bags only |
| `true` | `true` | Both simultaneously (dual-mode) |
| `false` | `false` | Disabled |

---

## Anti-Powergaming

1. **Single inventory** — all items always visible to police/admin tools.
2. **Removal prevention** — cannot drop a backpack while using extra capacity.
3. **Visual prop** — backpack is visible on the character model.
4. **Transparent system** — uses ox_inventory native weight/slot APIs; no custom containers.

---

## Troubleshooting

**Backpack prop doesn't appear on first join**
- Increase `Config.SpawnDelay`. Default 4500 ms assumes a cold-start; some servers take longer.

**Extra slots disappear when entering a vehicle**
- Update to this version. The bug was caused by `RemoveBag()` revoking server capacity on vehicle entry; it is now fixed — only the prop is removed.

**"You can only have 1 backpack equipped!" when picking up first bag**
- The `createItem` hook fires before the item is fully in the inventory. If you are using a very old ox_inventory version, the `createItem` hook may not exist; update ox_inventory.

**Capacity keeps increasing on respawn**
- Update to this version. The `lib.onCache('ped')` handler now passes `skipCapacity=true` when re-attaching the prop after a ped change, preventing a double-grant.

**Clothing bag bonus not applying**
- Ensure the drawable is not in `Config.ClothingBagBlacklist`.
- Run `/baginfo` to confirm the drawable/texture being detected.
- Verify `Config.UseClothingBags = true`.

**ESX: bag not equipped on login**
- Set `Config.Framework = 'esx'` in config.lua.

---

## Performance

- **Client**: 0.00 ms idle; event-driven (no per-frame tick for inventory bags). Clothing bag mode uses a 500 ms interval thread.
- **Server**: Minimal — capacity changes are pure ox_inventory API calls; no database reads.

---

## Changelog

### 1.2.0 (current)
- **Fix**: In-vehicle slots now visible without swapping items (Issue #1) — prop is hidden on vehicle entry but capacity grant is preserved.
- **Fix**: `justConnect` race condition — flag is cleared before `Wait()` to prevent double equip on rapid inventory updates.
- **Fix**: Ped-cache double capacity grant on respawn/model change — re-attach is now prop-only (`skipCapacity=true`).
- **Fix**: `decreaseCapacity` and `decreaseClothingBag` now clamp to base values; cannot underflow below pre-bag capacity.
- **Security**: `increaseCapacity` server event now verifies caller owns the item before granting capacity.
- **Security**: Per-player grant state tracked server-side; duplicate/spoofed calls are idempotent or rejected.
- **Feature**: Both `UseInventoryBags` and `UseClothingBags` can now be enabled simultaneously (dual-mode).
- **Feature**: ESX framework support — set `Config.Framework = 'esx'`.
- **Feature**: Optional portable stash system (`Config.PortableStashMode`, `server/stash.lua`).
- **Reliability**: `createItem` hook now blocks immediately instead of removing the item after a delay.
- **Config**: Added `Config.Framework`, `Config.PortableStashMode`, `Config.PortableStashBackpacks`.
- **Docs**: Fixed contradictions in README, added troubleshooting section, corrected debug command name.

### 1.1.1
- Minor hook cleanup on resource stop.

### 1.1.0
- Added clothing bag blacklist system.
- Added debug command.
- Improved slot-based removal prevention.

### 1.0.0
- Initial release.

---

## Credits

- Originally inspired by wasabi_backpack
- Built and maintained by [Yot-3](https://github.com/Yot-3)
- Uses [ox_lib](https://github.com/overextended/ox_lib) and [ox_inventory](https://github.com/overextended/ox_inventory) by Overextended
- Clothing bag integration compatible with [illenium-appearance](https://github.com/iLLeniumStudios/illenium-appearance)

## License

Open source — free to modify and use on your server. Please credit the original author.

---

**Version**: 1.2.0
**Tested On**: FiveM Build 6683+, ox_inventory v2.x, ox_lib v3.x
