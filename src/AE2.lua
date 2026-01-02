local component = require("component")
local ME = component.me_interface
local gpu = component.gpu

-- Locals
local pairs = pairs
local tostring = tostring
local type = type
local table_insert = table.insert
local string_gsub = string.gsub
local os_sleep = os.sleep
local os_time = os.time

local AE2 = {}

local itemCache = {}
local cacheTimestamp = 0
local CACHE_DURATION = 600 -- 10 minutes to refresh patterns

-- SNAPSHOT STORAGE
local snapshot = {
    items = {},
    fluids = {},
    cpus = {}
}

-- fast helper to clean names
local function cleanName(name)
    return string_gsub(string_gsub(name:lower(), "^drop of ", ""), "^molten ", "")
end

--------------------------------------------------------------------------------
-- SNAPSHOT SYSTEM beta
--------------------------------------------------------------------------------

function AE2.updateSnapshot()
    -- 1. Reset tables
    snapshot.items = {}
    snapshot.fluids = {}
    
    -- 2. MASSIVE Item Download Only 1 network call
    local allItems = ME.getItemsInNetwork()
    if allItems then
        for _, item in pairs(allItems) do
            -- Sum sizes in case of variants with same name
            local label = item.label
            if label then
                snapshot.items[label] = (snapshot.items[label] or 0) + item.size
            end
        end
    end

    -- 3. MASSIVE Fluid Download Only 1 network call the same but with fluids
    local allFluids = ME.getFluidsInNetwork()
    if allFluids then
        for _, fluid in pairs(allFluids) do
            local label = fluid.label
            if label then
                -- Store by exact name
                snapshot.fluids[label] = (snapshot.fluids[label] or 0) + fluid.amount
                -- Store by "clean" name for lookup
                local clean = cleanName(label)
                if clean ~= label:lower() then
                    snapshot.fluids[clean] = (snapshot.fluids[clean] or 0) + fluid.amount
                end
            end
        end
    end

    -- 4. CPU Status Download
    snapshot.cpus = {}
    local cpus = ME.getCpus()
    if cpus then
        for _, cpu in pairs(cpus) do
            -- Store only necessary info to save RAM
            local info = {
                isBusy = cpu.cpu.isBusy(),
                craftingLabel = nil
            }
            if info.isBusy then
                local final = cpu.cpu.finalOutput()
                if final then info.craftingLabel = final.label end
            end
            table_insert(snapshot.cpus, info)
        end
    end
end

--------------------------------------------------------------------------------
-- DATA READING
--------------------------------------------------------------------------------

function AE2.getStock(name)
    -- hash table lookup
    local itemStock = snapshot.items[name] or 0
    
    local fluidStock = snapshot.fluids[name] or 0
    if fluidStock == 0 then
        fluidStock = snapshot.fluids[cleanName(name)] or 0
    end

    -- Fluid priority (GTNH Logic)
    if fluidStock > 0 then return fluidStock end
    return itemStock
end

function AE2.getCpusSnapshotted()
    return snapshot.cpus
end

function AE2.checkIfCraftingSnapshotted()
    local activeCrafts = {}
    for _, cpu in pairs(snapshot.cpus) do
        if cpu.craftingLabel then
            activeCrafts[cpu.craftingLabel] = true
        end
    end
    return activeCrafts
end

--------------------------------------------------------------------------------
-- UTILITIES
--------------------------------------------------------------------------------

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
  local len = #str
  local first = len % 3
  if first == 0 then first = 3 end
  local res = {str:sub(1, first)}
  for i = first + 1, len, 3 do
    table_insert(res, str:sub(i, i + 2))
  end
  return table.concat(res, "_")
end

local function getCraftableForItem(itemName)
  local now = os_time()
  if now - cacheTimestamp >= CACHE_DURATION then
    itemCache = {}
    cacheTimestamp = now
  end
  if itemCache[itemName] then return itemCache[itemName] end
  
  -- This call remains individual because getCraftables is too heavy
  -- to call without filters. Mitigated by the 10-min cache.
  local craftables = ME.getCraftables({label = itemName})
  local craftable = craftables and craftables[1] or nil
  itemCache[itemName] = craftable
  return craftable
end

--------------------------------------------------------------------------------
-- CRAFTING REQUEST
--------------------------------------------------------------------------------

function AE2.requestItem(name, data, threshold, count)
  local craftable = getCraftableForItem(name)
  if not craftable then
    return false, "is not craftable!"
  end

  if threshold and threshold > 0 then
    -- Use snapshot stock
    local currentStock = AE2.getStock(name)

    if currentStock >= threshold then
      return false, "The amount (" .. formatNumber(currentStock) .. ") >= threshold (" .. formatNumber(threshold) .. ")! Aborting request."
    end
  end

  -- If we reach here, we proceed to craft
  if craftable then
    local craft = craftable.request(count)
    
    -- Non-blocking wait
    local timeout = 5 
    while craft.isComputing() and timeout > 0 do 
        os_sleep(0.1) 
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

return AE2