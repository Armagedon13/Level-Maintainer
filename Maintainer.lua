local term = require("term")
local event = require("event")
local component = require("component")
local gpu = component.gpu
local ae2 = require("src.AE2")
local cfg = require("config")

local items = cfg.items
local sleepInterval = cfg.sleep
local timezone = cfg.timezone or 0  -- Default 0 (UTC) if not set

-- Try to get internet component for real time
local internet = nil
local hasInternet = component.isAvailable("internet")
if hasInternet then
  internet = component.internet
end

-- Cache real time (update every 100 calls to reduce requests)
local cachedRealTime = 0
local realTimeCounter = 100

-- Auto-update check
pcall(function()
  local shell = require("shell")
  shell.execute("updater silent")
end)

-- Function to get real world time with timezone offset
local function getLocalTime()
  -- Try to use internet card for real time
  if hasInternet and internet then
    -- Update cache every 100 calls
    if realTimeCounter >= 100 then
      pcall(function()
        cachedRealTime = internet.time()
      end)
      realTimeCounter = 0
    end
    realTimeCounter = realTimeCounter + 1
    
    -- If we have real time, use it
    if cachedRealTime > 0 then
      local adjustedTime = cachedRealTime + (timezone * 3600)
      return os.date("%H:%M:%S", adjustedTime)
    end
  end
  
  -- Fallback: use os.date with timezone offset
  -- This uses the server's system time
  local currentTime = os.time()
  local adjustedTime = currentTime + (timezone * 3600)
  return os.date("%H:%M:%S", adjustedTime)
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

while true do
  term.clear()
  term.setCursor(1, 1)
  print("Press Q to exit. Item inspection interval: " .. sleepInterval .. " sec.\n")

  local itemsCrafting = ae2.checkIfCrafting()

  for item, cfgItem in pairs(items) do
    if itemsCrafting[item] then
      logInfo(item .. ": is already being crafted, skipping...")
    else
      -- Support both formats
      local data, threshold, batch_size
      
      if type(cfgItem[1]) == "table" then
        data = cfgItem[1]
        threshold = cfgItem[2]
        batch_size = cfgItem[3]
      else
        data = nil
        threshold = cfgItem[1]
        batch_size = cfgItem[2]
      end
      
      local success, msg = ae2.requestItem(item, data, threshold, batch_size)
      
      local color = nil
      if msg:find("^Failed to request") then
        color = 0xFF0000
      elseif msg:find("^Requested") then
        color = 0xFFFF00
      elseif msg:find("The amount %(") and msg:find("Aborting request%.$") then
        color = 0x00FF00
      end

      logInfoColoredAfterColon(item .. ": " .. msg, color)
    end
  end

  local _, _, _, code = event.pull(sleepInterval, "key_down")
  if code == 0x10 then
    exitMaintainer()
  end
end