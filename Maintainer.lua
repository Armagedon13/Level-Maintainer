local term = require("term")
local event = require("event")
local component = require("component")
local gpu = component.gpu
local filesystem = require("filesystem")
local ae2 = require("src.AE2")
local cfg = require("config")

local items = cfg.items
local sleepInterval = cfg.sleep
local timezone = cfg.timezone or 0
local filterChestSide = cfg.filterChestSide or nil -- Optional filter chest configuration

-- Auto-update check
pcall(function()
  local shell = require("shell")
  shell.execute("updater silent")
end)

local function getRealTime()
  local tempfile = "/tmp/timefile"
  local file = filesystem.open(tempfile, "a")
  if file then
    file:close()
    local timestamp = filesystem.lastModified(tempfile) / 1000
    filesystem.remove(tempfile)
    return timestamp
  else
    return os.time()
  end
end

local function getLocalTime()
  local realTime = getRealTime()
  local offsetTime = realTime + (timezone * 3600)
  
  local timetable = os.date("*t", offsetTime)
  
  local min = timetable.min
  if min < 10 then min = "0" .. min end
  
  local sec = timetable.sec
  if sec < 10 then sec = "0" .. sec end
  
  return timetable.hour .. ":" .. min .. ":" .. sec
end

local function exitMaintainer()
  term.clear()
  term.setCursor(1, 1)
  print("Exit from Maintainer...")
  os.exit(0.5)
end

local function logInfoColoredAfterColon(msg, color)
  if type(msg) ~= "string" then msg = tostring(msg) end
  local before, after = msg:match("^(.-):%s*(.+)$")
  if not before then
    print(msg)
    return
  end

  local old = gpu.getForeground()
  io.write("[" .. getLocalTime() .. "] " .. before .. ": ")
  if color then gpu.setForeground(color) end
  io.write(after .. "\n")
  gpu.setForeground(old)
end

local function logInfo(msg)
  print("[" .. getLocalTime() .. "] " .. msg)
end

-- Function to scan filter chest and get paused items
local function getPausedItems()
  local pausedItems = {}
  
  if not filterChestSide then
    return pausedItems -- No filter chest configured
  end
  
  if not component.isAvailable("inventory_controller") then
    logInfo("Warning: Inventory Controller not available, filter chest disabled")
    return pausedItems
  end
  
  local inv = component.inventory_controller
  local size = inv.getInventorySize(filterChestSide)
  
  if not size or size < 1 then
    logInfo("Warning: Filter chest not accessible on configured side")
    return pausedItems
  end
  
  -- Scan all slots in the filter chest
  for slot = 1, size do
    local stack = inv.getStackInSlot(filterChestSide, slot)
    if stack and stack.size and stack.size > 0 then
      local item_name = stack.label or stack.name
      if item_name then
        pausedItems[item_name] = true
      end
    end
  end
  
  return pausedItems
end

while true do
  term.clear()
  term.setCursor(1, 1)
  print("Press Q to exit. Item inspection interval: " .. sleepInterval .. " sec.\n")

  -- Scan filter chest for paused items
  local pausedItems = getPausedItems()
  
  if filterChestSide and next(pausedItems) then
    local count = 0
    for _ in pairs(pausedItems) do count = count + 1 end
    logInfo("Filter chest active - " .. tostring(count) .. " items paused")
  end

  local itemsCrafting = ae2.checkIfCrafting()


  -- Allow Crafting of low priority items only if all CPUs are either idle or crafting other stocked items
  local allowLow = true
  local cpus = ae2.getCpuStatus and ae2.getCpuStatus() or {}
  for _, cpu in ipairs(cpus) do
    if cpu.isBusy then
      local crafting = cpu.craftingLabel
      if crafting and not items[crafting] then
        -- busy with something not in config
        allowLow = false
        break
      end
    end
  end

  for item, cfgItem in pairs(items) do
    if pausedItems[item] then
      logInfoColoredAfterColon(item .. ": paused by filter chest", 0x808080) -- Gray color
    elseif itemsCrafting[item] then
      -- Item is actively crafting -> Green logic implies working
      logInfoColoredAfterColon(item .. ": is already being crafted, skipping...", 0x00FF00)
    else
      local data, threshold, batch_size, priority

      if type(cfgItem[1]) == "table" then
        -- Formato Pattern.lua / Complejo
        data = cfgItem[1]
        threshold = cfgItem[2]
        batch_size = cfgItem[3]
        priority = cfgItem[4] or "high"
      else
        -- Formato Simple / Manual
        data = nil
        threshold = cfgItem[1]
        batch_size = cfgItem[2]
        priority = cfgItem[3] or "high"
      end

      if priority == "high" or allowLow then
        local success, msg = ae2.requestItem(item, data, threshold, batch_size)
        local color = nil
        if msg:find("^Failed to request") or msg:find("is not craftable") then
          color = 0xFF0000 -- RED (Error)
        elseif msg:find("The amount %(") and msg:find("Aborting request%.$") then
          color = 0xFFFF00 -- YELLOW (Threshold Reached / Standby)
        elseif msg:find("^Requested") then
          color = 0x00FF00 -- GREEN (Success / Crafting started)
        end
        logInfoColoredAfterColon(item .. ": " .. msg, color)
      else
        color = 0x808080 -- GRAY (Low priority skipped)
        logInfoColoredAfterColon(item .. ": Low priority, CPUs busy with non-stocked jobs, skipping...", color)
      end
    end
  end

  local _, _, _, code = event.pull(sleepInterval, "key_down")
  if code == 0x10 then -- Q key
    exitMaintainer()
  end
end