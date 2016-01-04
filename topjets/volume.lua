local wibox = require('wibox')
local scheduler = require('scheduler')
local naughty = require('naughty')
local utility = require("utility")
local base = require('topjets.base')

local volume = base()

local icons = {}

function volume.init()
   for i, level in ipairs({ "zero", "low", "medium", "high" }) do
      icons[i] = base.icon("audio-volume-" .. level, "status")
   end
   icons.muted = base.icon("audio-volume-muted", "status")

   scheduler.register_recurring("topjets_volume", 20, function() volume.update() end)
end

function volume.new()
   local w = wibox.widget.imagebox()
   w.inc = volume.inc
   w.dec = volume.dec
   w.mute = volume.mute
   return w
end

local function get_master_infos()
   local state, vol

   vol = utility.pslurp("pamixer --get-volume", "*line")
   state = utility.pslurp("pamixer --get-mute", "*line")
   if state == "false" then
     state = "on"
   else
     state = "muted"
   end

   return state, vol
end

function volume.notify(state, vol, icon)
   volume.notification_id =
      base.notify({ title = "Volume: " .. vol .. "%",
                    text = "State: " .. state,
                    position = "bottom_right", timeout = 3,
                    icon = icon.large, replaces_id = volume.notification_id}).id
end

function volume.update(to_notify)
   local state, vol = get_master_infos()
   local idx = math.floor(math.min(math.max(tonumber(vol), 0), 99) / 25) + 1
   local naughty_icon

   if state == "muted" then
      volume.refresh_all(icons.muted)
      naughty_icon = icons.muted
   else
      volume.refresh_all(icons[idx])
      naughty_icon = icons[idx]
   end

   if to_notify then
      volume.notify(state, vol, naughty_icon)
   end
end

function volume.refresh(w, icon)
   w:set_image(icon.small)
end

function volume.inc(volume_step)
  os.execute("pamixer --increase " .. volume_step)
  volume.update(true)
end

function volume.dec(volume_step)
  os.execute("pamixer --decrease " .. volume_step)
  volume.update(true)
end

function volume.mute()
  os.execute("pamixer --toggle-mute")
  volume.update(true)
end

return volume
