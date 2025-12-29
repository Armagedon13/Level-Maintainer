-- upload_config.lua
-- Utility to upload config.lua to Pastebin from OpenComputers
-- Usage: Run this script to upload /home/config.lua and get a link

local shell = require("shell")
local configPath = "/home/config.lua"

print("Uploading config.lua to Pastebin...")
local result = shell.execute("pastebin put " .. configPath)
print("\n")
if result then
  print("Upload complete. Check above for your Pastebin link.")
else
  print("Upload failed. Make sure pastebin program is installed and HTTP is enabled.")
end