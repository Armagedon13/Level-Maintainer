local term = require("term")
local event = require("event")
local component = require("component")
local gpu = component.gpu
local ae2 = require("src.AE2")
local cfg = require("config")

-- Localizing functions
local pairs = pairs
local tostring = tostring
local os_date = os.date
local os_time = os.time
local io_write = io.write
local print = print

local items = cfg.items
local sleepInterval = cfg.sleep
local timezone = cfg.timezone or 0
local filterChestSide = cfg.filterChestSide -- Optional

-- Silent auto-update
pcall(function()
  local shell = require("shell")
  shell.execute("updater silent")
end)

-- TIME
local function getLocalTime()
    -- Simple timezone adjustment on host time idk this meybe cannot work
    local now = os_time()
    local offsetTime = now + (timezone * 3600)
    return os_date("%H:%M:%S", offsetTime)
end

local function logInfoColoredAfterColon(msg, color)
    if type(msg) ~= "string" then msg = tostring(msg) end
    local timeStr = "[" .. getLocalTime() .. "] "
    
    local before, after = msg:match("^(.-):%s*(.+)$")
    if not before then
        print(timeStr .. msg)
        return
    end

    local old = gpu.getForeground()
    io_write(timeStr .. before .. ": ")
    if color then gpu.setForeground(color) end
    io_write(after .. "\n")
    gpu.setForeground(old)
end

local function logInfo(msg)
    print("[" .. getLocalTime() .. "] " .. msg)
end

-- Helper function for filter chest (if used)
local function getPausedItems()
    local paused = {}
    if not filterChestSide or not component.isAvailable("inventory_controller") then 
        return paused 
    end
    
    local inv = component.inventory_controller
    local size = inv.getInventorySize(filterChestSide)
    if not size or size < 1 then return paused end
    
    for slot = 1, size do
        local stack = inv.getStackInSlot(filterChestSide, slot)
        if stack and stack.label then
            paused[stack.label] = true
        end
    end
    return paused
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------
while true do
    term.clear()
    term.setCursor(1, 1)
    print("Press Q to exit. Item inspection interval: " .. sleepInterval .. " sec.\n")

    -- 1. TAKE SNAPSHOT
    -- This makes exactly 3 network calls total, regardless of item count.
    ae2.updateSnapshot()

    -- 2. Process logic with in-memory data
    local pausedItems = getPausedItems()
    if filterChestSide and next(pausedItems) then
        local count = 0
        for _ in pairs(pausedItems) do count = count + 1 end
        logInfo("Filter chest active - " .. count .. " items paused")
    end

    -- Use snapshot to check crafting status
    local itemsCrafting = ae2.checkIfCraftingSnapshotted()
    local cpus = ae2.getCpusSnapshotted()

    -- Smart Priority Logic
    local allowLow = true
    for _, cpu in pairs(cpus) do
        if cpu.isBusy then
            -- If CPU is busy with something NOT in our config,
            -- we assume it's a manual user request.
            if cpu.craftingLabel and not items[cpu.craftingLabel] then
                allowLow = false
                break
            end
        end
    end

    -- 3. Iterate items
    for item, cfgItem in pairs(items) do
        -- A. Is it paused by filter chest?
        if pausedItems[item] then
            logInfoColoredAfterColon(item .. ": paused by filter chest", 0x808080)
        
        -- B. Is it already crafting?
        elseif itemsCrafting[item] then
            logInfoColoredAfterColon(item .. ": is already being crafted, skipping...", 0x00FF00)
            
        else
            -- C. Evaluate Configuration
            local data, threshold, batch_size, priority
            if type(cfgItem[1]) == "table" then
                data = cfgItem[1]
                threshold = cfgItem[2]
                batch_size = cfgItem[3]
                priority = cfgItem[4] or "high"
            else
                data = nil
                threshold = cfgItem[1]
                batch_size = cfgItem[2]
                priority = cfgItem[3] or "high"
            end

            -- D. Execute or skip based on priority 
            if priority == "high" or allowLow then
                local success, msg = ae2.requestItem(item, data, threshold, batch_size)
                
                local color = nil
                if msg:find("^Failed to request") or msg:find("is not craftable") then
                    color = 0xFF0000 
                elseif msg:find("The amount %(") and msg:find("Aborting request%.$") then
                    color = 0xFFFF00 
                elseif msg:find("^Requested") then
                    color = 0x00FF00 
                end
                
                logInfoColoredAfterColon(item .. ": " .. msg, color)
            else
                logInfoColoredAfterColon(item .. ": Low priority, CPUs busy, skipping...", 0x808080)
            end
        end
    end

    -- Press 'Q' key to exit
    local _, _, _, code = event.pull(sleepInterval, "key_down")
    if code == 0x10 then 
        term.clear()
        term.setCursor(1,1)
        print("Exiting...")
        os.exit()
    end
end