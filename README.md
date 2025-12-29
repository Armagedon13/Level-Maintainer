# Level Maintainer

Automatically maintain item and fluid levels in your Applied Energistics 2 (AE2) network without the lag and randomness of AE2's Level Emitter system. Features threshold support and auto-crafting optimization.

## Features

- 🚀 **High Performance** - Optimized caching system reduces AE2 API calls
- 🎯 **Threshold Support** - Maintain minimum stock levels (optional)
- 💧 **Fluid Support** - Works with both items and fluids
- 🔄 **Auto-Update** - Automatically checks for updates on startup
- ⚙️ **Easy Configuration** - Simple config format with automatic detection
- 🕒 **Timezone Support** - Configure your local timezone for accurate timestamps

## Requirements

### Hardware
- **ME Interface** (full block) connected to an **Adapter**
- **Crafting Monitors** on your ME CPUs
- **Internet Card** (for auto-updates)
- **Adapter** with **Inventory Controller Upgrade** installed
- **Vanilla Chest** connected to the Adapter (for Pattern setup)
- Standard OpenComputers components (Computer Case, CPU, RAM, etc.)

## Installation

Download and run the installer:
```bash
wget https://raw.githubusercontent.com/kintzo/Level-Maintainer/master/installer.lua && installer
```

The installer will:
- Download all necessary files
- Create required directories
- Preserve your existing `config.lua` if present
- Set up the auto-updater

## Usage

### Starting the Maintainer
```bash
Maintainer
```

This will:
1. Check for updates (silent mode)
2. Start monitoring configured items
3. Auto-craft items when below threshold

**Press Q** to exit the Maintainer.

### Adding Items with Pattern
```bash
Pattern
```

The Pattern tool helps you add items without manually editing the config:

1. Place items or fluid drops in the chest connected to your Adapter
2. Run `Pattern`
3. The script will automatically detect the chest
4. Follow the prompts to set threshold and batch size for each item
5. Items are added to `config.lua` without overwriting existing entries

**Note:** Computer components (cards, upgrades, etc.) are automatically ignored.

## Configuration

Edit `config.lua` to customize the maintainer behavior:

### Basic Format
```lua
cfg["items"] = {
  ["Item Name"] = {threshold, batch_size}
}
```

### Examples
```lua
cfg["items"] = {
  -- With threshold - crafts when stock falls below 128
  ["Iron Ingot"] = {128, 64},
  
  -- Without threshold - always crafts (better performance!)
  ["Osmium Dust"] = {nil, 64},
  
  -- Fluids work the same way
  ["drop of Molten SpaceTime"] = {1000, 1},
  ["drop of Water"] = {nil, 1000},
}
```

### Settings

#### Sleep Interval
Time between craft checks in seconds:
```lua
cfg["sleep"] = 10  -- Check every 10 seconds
```

#### Timezone
Set your local timezone offset in hours for accurate timestamps:
```lua
cfg["timezone"] = 0  
```

**Common timezones:**
- `-3` - Argentina, Brazil, Chile
- `-5` - USA East Coast (EST)
- `-4` - USA East Coast (EDT - Daylight Saving)
- `0` - UTC/GMT
- `+1` - Central European Time (CET)
- `+2` - Central European Summer Time (CEST)

If not set, defaults to UTC (`0`).

### Performance Tips

⚠️ **Thresholds have a performance impact!** 

- Each threshold requires checking current stock levels in your AE2 network
- Use `nil` threshold when you just want continuous crafting
- Only set thresholds when you need to maintain minimum stock levels

**Recommended:**
```lua
["Item Name"] = {nil, 64}  -- Fast, no stock checking
```

**Use only when needed:**
```lua
["Item Name"] = {1000, 64}  -- Slower, checks stock every cycle
```

## Auto-Update System

The maintainer automatically checks for updates when started:

- **Silent mode** - No notification if already up to date
- **Interactive mode** - Prompts you to update when a new version is available
- **Config preservation** - Your `config.lua` is NEVER modified during updates

### Manual Update Check
```bash
updater
```

### How It Works

1. Compares local version with GitHub repository
2. If update available, prompts for confirmation
3. Downloads updated files (excludes `config.lua`)
4. Automatically reboots after successful update

## Troubleshooting

### "Inventory Controller not found"
- Ensure the Inventory Controller Upgrade is installed in the Adapter
- The Adapter must be adjacent to the chest

### "is not craftable"
- Item doesn't have a crafting pattern in AE2
- Pattern is disabled or blocked
- Check your AE2 crafting patterns

### "Failed to request"
- Missing ingredients in AE2 network
- All CPUs are busy
- Pattern configuration issue

### Items not being crafted
- Verify item is in `config.lua`
- Check threshold isn't already met
- Ensure CPUs have Crafting Monitors installed

### Wrong timezone
- Edit `cfg["timezone"]` in `config.lua`
- Use negative numbers for western timezones
- Restart Maintainer after changing

## Advanced Usage

### Batch Format Support

The maintainer supports both old and new config formats:

**New simplified format** (recommended):
```lua
["Item Name"] = {threshold, batch_size}
```

**Old format** (still supported):
```lua
["Item Name"] = {{item_id = "mod:item", item_meta = 0}, threshold, batch_size}
["Fluid Name"] = {{fluid_tag = "molten.metal"}, threshold, batch_size}
```

The new format auto-detects whether an item is a fluid or regular item.

## Credits

Original concept by difayal, Echoloquate and  Niels1006
Optimizations and improvements by Armagedon13  
Based on the Level Maintainer system for Applied Energistics 2

## License

This project is open source and available for modification and distribution.

## Support

For issues, suggestions, or contributions, please visit:
https://github.com/kintzo/Level-Maintainer

---

**Version:** 2.8+
