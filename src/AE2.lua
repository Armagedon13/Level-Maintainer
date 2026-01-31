local component = require("component")
local ME = component.me_interface
local gpu = component.gpu

local AE2 = {}

local itemCache = {}
local cacheTimestamp = 0
local CACHE_DURATION = 600 -- 10 minutes

-- Returns a table of CPU statuses: {isBusy=true/false, name=string, craftingLabel=string|nil}
function AE2.getCpuStatus()
  local cpus = {}
  for _, cpu in pairs(ME.getCpus()) do
    local status = {}
    status.name = cpu.cpu.name and cpu.cpu.name() or "CPU"
    status.isBusy = cpu.cpu.isBusy and cpu.cpu.isBusy() or false
    local final = cpu.cpu.finalOutput and cpu.cpu.finalOutput()
    status.craftingLabel = final and final.label or nil
    table.insert(cpus, status)
  end
  return cpus
end

function AE2.printColoredAfterColon(line, color)
  if type(line) ~= "string" then line = tostring(line) end
  local before, after = line:match("^(.-):%s*(.+)$")
  if not before then
    io.write(line .. "\n")
    return
  end

  local old = gpu.getForeground()
  io.write(before .. ": ")
  if color then gpu.setForeground(color) end
  io.write(after .. "\n")
  gpu.setForeground(old)
end

local function formatNumber(num)
  if type(num) ~= "number" then return tostring(num) end
  local str = tostring(num)
  local parts = {}
  local len = #str
  local firstGroup = len % 3
  if firstGroup == 0 then firstGroup = 3 end
  table.insert(parts, str:sub(1, firstGroup))
  local i = firstGroup + 1
  while i <= len do
    table.insert(parts, str:sub(i, i + 2))
    i = i + 3
  end
  return table.concat(parts, "_")
end

-- Function to get or cache a specific craftable item
local function getCraftableForItem(itemName)
  local currentTime = os.time()
  
  -- Check if we have a cached version of this specific item and it's still valid
  if itemCache[itemName] and currentTime - cacheTimestamp < CACHE_DURATION then
    return itemCache[itemName]
  end
  
  -- If cache is too old, clear it completely to save memory
  if currentTime - cacheTimestamp >= CACHE_DURATION then
    itemCache = {}
    cacheTimestamp = currentTime
  end
  
  -- Look for this specific item in craftables
  local craftables = ME.getCraftables({label = itemName})
  if craftables and #craftables >= 1 then
    itemCache[itemName] = craftables[1] -- Cache only this one item
    return craftables[1]
  end
  
  itemCache[itemName] = nil -- Cache that it's not craftable
  return nil
end

-- Helper function to detect if an item is a fluid drop
local function isFluidDrop(name)
  local lowerName = name:lower()
  return lowerName:find("^drop of ") or lowerName:find("^molten ")
end

-- Helper function to extract fluid name from drop name
local function extractFluidName(dropName)
  local cleaned = dropName:gsub("^[Dd]rop [Oo]f ", ""):gsub("^[Mm]olten ", "")
  -- Convert to fluid tag format (e.g., "Molten SpaceTime" -> "molten.spacetime")
  return cleaned:lower():gsub(" ", ".")
end

-- Returns: success:boolean, message:string
function AE2.requestItem(name, data, threshold, count)
  local craftable = getCraftableForItem(name)
  if not craftable then
    return false, "is not craftable!"
  end

  -- Check Thresholds
  if threshold and threshold > 0 then
    local currentStock = 0
    local itemInSystem = nil
    
    -- Detect if this is a fluid drop
    local isFluid = isFluidDrop(name)
    
    if isFluid then
      local fluidName = extractFluidName(name)
      
      if data and data.fluid_tag then
        local fluidTag = '{Fluid:' .. data.fluid_tag .. '}'
        itemInSystem = ME.getItemInNetwork("ae2fc:fluid_drop", 0, fluidTag)
      else
        local fluidTag = '{Fluid:' .. fluidName .. '}'
        itemInSystem = ME.getItemInNetwork("ae2fc:fluid_drop", 0, fluidTag)
      end
      
      if itemInSystem then
        currentStock = itemInSystem.size or 0
      end
    else
      local item = craftable.getItemStack()
      
      if item and item.name then
        if data and data.item_id then
          local itemName = data.item_id
          local itemDamage = tonumber(data.item_meta) or 0
          itemInSystem = ME.getItemInNetwork(itemName, itemDamage)
        else
          local damage = tonumber(item.damage) or 0
          
          if item.tag then
            itemInSystem = ME.getItemInNetwork(item.name, damage, item.tag)
          end
          
          if itemInSystem == nil then
            itemInSystem = ME.getItemInNetwork(item.name, damage)
          end
        end
        
        if itemInSystem then
          currentStock = itemInSystem.size or 0
        end
      end
    end

    -- Check if threshold is met
    if currentStock >= threshold then
      local currentFmt = formatNumber(currentStock)
      local thresholdFmt = formatNumber(threshold)
      return false, "The amount (" .. currentFmt .. ") >= threshold (" .. thresholdFmt .. ")! Aborting request."
    end
  end

  -- Execute Crafting Request
  if craftable then
    local craft = craftable.request(count)
    
    local timeout = 5 
    while craft.isComputing() and timeout > 0 do 
        os.sleep(0.1) 
        timeout = timeout - 1
    end

    if craft.hasFailed() then
      return false, "Failed to request " .. formatNumber(count)
    else
      return true, "Requested " .. formatNumber(count)
    end
  end

  return false, "is not craftable!"
end

function AE2.checkIfCrafting()
  local items = {}
  for _, cpu in pairs(ME.getCpus()) do
    local final = cpu.cpu.finalOutput()
    if final then
      items[final.label] = true
    end
  end
  return items
end

-- Function to manually clear the cache if needed
function AE2.clearCache()
  itemCache = {}
  cacheTimestamp = 0
end

return AE2