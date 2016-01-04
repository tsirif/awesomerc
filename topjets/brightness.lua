local wibox = require('wibox')
local scheduler = require('scheduler')
local naughty = require('naughty')
local utility = require("utility")
local base = require('topjets.base')

local brightness = base()

local icons = {}

function brightness.init()
   for i, level in ipairs({ "off", "low", "medium", "high", "full"}) do
      icons[i] = base.icon("notification-display-brightness-" .. level, "status")
   end

   -- scheduler.register_recurring("topjets_brightness", 20, function() brightness.update() end)
end

function brightness.new()
   local w = wibox.widget.imagebox()
   w.inc = brightness.inc
   w.dec = brightness.dec
   return w
end

function brightness.notify(bright, icon)
   brightness.notification_id =
      base.notify({ title = string.format("brightness: %.f%%", bright),
                    position = "bottom_right", timeout = 3,
                    icon = icon.large, replaces_id = brightness.notification_id}).id
end

function brightness.update(to_notify)
   local bright = utility.pslurp("xbacklight -get", "*line")
   local idx = math.floor(math.min(math.max(tonumber(bright), 0), 99) / 20) + 1
   local naughty_icon = icons[idx]
   -- brightness.refresh_all(naughty_icon)
   if to_notify then
     brightness.notify(bright, naughty_icon)
   end
end

function brightness.refresh(w, icon)
   w:set_image(icon.small)
end

function brightness.inc(brightness_step)
  os.execute("xbacklight -inc " .. brightness_step)
  brightness.update(true)
end

function brightness.dec(brightness_step)
  os.execute("xbacklight -dec " .. brightness_step)
  brightness.update(true)
end

return brightness
