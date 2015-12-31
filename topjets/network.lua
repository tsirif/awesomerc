local wibox = require('wibox')
local l = require('layout')
local system = require('system')
local base = require('topjets.base')

local network = base()

local custom_hosts = rc.hosts or {}
local hosts = { "github.com", "192.30.252.130",
                custom_hosts.local_ip or "10.0.0.1",
                custom_hosts.router_ip or "192.168.1.1" }
local short_labels = { "", "!DNS: ", "L: ", "R: " }
local labels = { "World", "W/o DNS", "Local", "Router" }
local tooltip = { title = "Network\t\tLatency\t\tLoss" }

local icon_names = { wired = {connected = "network-transmit-receive"},
                     wireless = {connected = "network-wireless-connected"},
                     cellular = {
                       connected = {}
                       -- input 3g, 4g, E connections
                     },
                     none = {connected = "network-offline"}}
local icons = {}

function network.init()
  for k, v in pairs(icon_names) do
    icons[k] = {}
    if k ~= "cellular" then
      icons[k]["connected"] = base.icon(v.connected, "status")
    else
      icons[k]["connected"] = {}
      -- input 3g, 4g, E connection icon lookups
    end
  end
   for _, t in pairs({"wireless", "cellular"}) do
     for i, level in ipairs({ "weak", "ok", "good", "excellent" }) do
       icons[t][i] = base.icon("network-" .. t .."-signal-" .. level, "status")
     end
   end

   system.network.interfaces = rc.interfaces or { "eth0", "wlan0" }
   system.network.hosts = hosts
   system.network.add_connection_callback(network.connection_callback)
   system.network.add_latency_callback(network.latency_callback)
   system.network.add_traffic_callback(network.traffic_callback)

   system.network.init()
end

function network.new(is_v)
   local network_icon = wibox.widget.imagebox(icons.none.connected.large)
   local network_text = wibox.widget.textbox()

   local _widget =
      l.fixed { l.margin { l.midpoint { network_icon,
                                        vertical = is_v },
                           margin_left = (is_v and 4 or 0), margin_right = vista.scale(4) },
                l.midpoint { network_text,
                             vertical = is_v },
                vertical = is_v }

   _widget.network_icon = network_icon
   _widget.network_text = network_text

   return _widget
end

function network.refresh(w, iface_type, strength, downrate, uprate, data)
   if iface_type ~= nil then
      if iface_type == "wireless" or iface_type == "cellular" then
        local idx = math.floor(math.min(math.max(strength * 100, 0), 99) / 25) + 1
        w.network_icon:set_image(icons[iface_type][idx].large)
      else
        w.network_icon:set_image(icons[iface_type].connected.large)
      end
      if iface_type == "none" then
         w.network_text:set_markup("")
      end
    end
   local units = {"B", "KB", "MB"}
   if downrate ~= nil and uprate ~= nil then
     local d = downrate
     local di = 0
     while 100.0 <= d do
       di = di + 1
       d = downrate / 1024^di
     end
     local u = uprate
     local ui = 0
     while 100.0 <= u do
       ui = ui + 1
       u = uprate / 1024^ui
     end
     w.network_text:set_markup(string.format("%.1f %s/\n%.1f %s",
                                             d, units[di+1],
                                             u, units[ui+1]))
   end
   -- if data ~= nil then
   --    for i = 1, #hosts do
   --       if data[hosts[i]].loss ~= 100 then
   --          w.network_text:set_markup(string.format("%s%d ms", short_labels[i], math.floor(data[hosts[i]].time)))
   --          return
   --       end
   --    end
   --    w.network_text:set_markup("")
   -- end
end

function network.update_tooltip(data)
   tooltip.text = ""
   for i = 1, #hosts do
      local lat = data[hosts[i]].time
      if lat == -1 then
         lat = "∞\t"
      elseif lat < 1 then
         lat = math.floor(lat * 1000) .. " μs"
      else
         lat = math.floor(lat) .. " ms"
      end
      tooltip.text = tooltip.text .. string.format("%s\t\t%s\t\t%d%%",
                                                   labels[i], lat, data[hosts[i]].loss)
      if i < #hosts then
         tooltip.text = tooltip.text .. "\n"
      end
   end
end

function network.tooltip()
   return tooltip
end

function network.connection_callback(_, iface_type, strength)
   if iface_type ~= "cellular" then
      tooltip.icon = icons[iface_type].connected.large
   end
   network.refresh_all(iface_type, strength, nil, nil, nil)
end

function network.latency_callback(data)
   network.update_tooltip(data)
   -- network.refresh_all(nil, nil, nil, nil, data)
end

function network.traffic_callback(downrate, uprate)
  network.refresh_all(nil, nil, downrate, uprate, nil)
end

return network
