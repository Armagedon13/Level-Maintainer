local cfg = {}

-- EXAMPLE --
-- NEW SIMPLIFIED FORMAT:
-- ["item_name"] = {threshold, batch_size}
-- ["item_name"] = {nil, batch_size}  -- without threshold (better performance!)

-- OLD FORMAT (for backward compatibility):
-- ["item_name"] = {{item_id, item_meta},threshold, batchsize} -- keep in mind that no threshold has a better performance!
-- ["fluid_name"] = {{fluid_tag item},threshold, batchsize}}  -- keep in mind that no threshold has a better performance!
-- ["Osmium Dust"] = {{ item_id = "gregtech:gt.metaitem.01", item_meta = "2083"}, nil, 64}, -- without threshold, batch_size=64
-- ["drop of Molten SpaceTime"] = {{ fluid_tag = "molten.spacetime"}, 1000, 64} -- with threshold, batch_size=64

cfg["items"] = {

}

cfg["sleep"] = 10

-- Timezone offset in hours
-- -3 = Argentina/Brazil/Chile (UTC-3)
-- -5 = USA East Coast (UTC-5)
-- 0 = UTC
-- +1 = Central Europe (UTC+1)
cfg["timezone"] = 0

-- Filter chest configuration (optional)
-- Set to the side number where the filter chest is connected
-- 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left
-- Any item placed in this chest will pause its maintenance
cfg["filterChestSide"] = 1 -- Disabled by default, set to 0-5 to enable

return cfg
