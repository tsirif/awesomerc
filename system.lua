local socket = require('socket')
local utility = require('utility')
local asyncshell = require('asyncshell')

local system = { }

-- Network subsystem --
system.network = { hosts = {},
                   interfaces = {},
                   options = { ping_count = 4,
                               ping_timeout = 5,
                               interval = 30 } }

local initialized = false
local hosts_metrics = {}
local callbacks = { latency = {}, connection = {}, traffic = {} }
local complete = {}
local interface_connected = {}
local last_iface_connected = nil
local last_time_measured = nil
local last_rx_bytes = 0
local last_tx_bytes = 0

local iproute_command = "ip addr show %s 2> /dev/null"
local ping_command = "ping -c %d -w %d -q %s"
local signal_command = "iwconfig %s"
local traffic_command = "ip -s link show %s 2> /dev/null"

function system.network.add_latency_callback(fn)
   table.insert(callbacks.latency, fn)
end

function system.network.add_connection_callback(fn)
   table.insert(callbacks.connection, fn)
end

function system.network.add_traffic_callback(fn)
  table.insert(callbacks.traffic, fn)
end

local function check_complete()
   for _, v in pairs(complete) do
      if not v then return end
   end

   for k, _ in pairs(complete) do
      complete[k] = false
   end

   for _, callback in ipairs(callbacks.latency) do
      callback(hosts_metrics)
   end
end

local function ping_callback(f, host)
   local l = f:read()
   if l == nil then
      hosts_metrics[host].loss = 100
      hosts_metrics[host].time = -1
      complete[host] = true
      check_complete()
      return
   end

   -- Skip two lines
   f:read()
   f:read()

   _, _, loss = string.find(f:read(), ", (%d+)%% packet loss")

   if loss ~= "100" then
      _, _, time = string.find(f:read(), "min/avg/max/mdev = [%d%.]+/([%d%.]+)/.*")
   else
      time = -1
   end

   hosts_metrics[host].loss = tonumber(loss)
   hosts_metrics[host].time = tonumber(time)
   complete[host] = true
   check_complete()
end

local function get_iface_type(iface)
   if not iface then
      return "none"
   elseif iface:match("wl.+") then
      return "wireless"
   else
      return "wired"
   end
end

local function reping_network()
   for _, host in ipairs(system.network.hosts) do
      asyncshell.request(string.format(ping_command, system.network.options.ping_count,
                                       system.network.options.ping_timeout, host),
                         function(f) ping_callback(f, host) end)
   end
end

local function check_connected()
   local count = 0
   for _ in pairs(interface_connected) do count = count + 1 end

   if count < #system.network.interfaces then
      return
   end

   local connected_iface = nil
   for _, iface in ipairs(system.network.interfaces) do
      if interface_connected[iface] then
         connected_iface = iface
         break
      end
   end

   local type = get_iface_type(connected_iface)

   local strength = nil
   if type == "wireless" or type == "cellular" then
     local f = io.popen(signal_command:format(connected_iface))
     local a, b = f:read("*all"):match("Link Quality=(%d+)/(%d+)")
     strength = tonumber(a) / tonumber(b)
     f:close()
   end

   for _, callback in ipairs(callbacks.connection) do
      callback(connected_iface, type, strength)
   end

   if last_iface_connected ~= connected_iface then
      last_iface_connected = connected_iface
      last_time_measured = socket.gettime()
      last_rx_bytes, last_tx_bytes = find_traffic()
      reping_network()
      calculate_rates()
   end
end

local function iproute_callback (f, iface)
   local t = f:read("*all")
   interface_connected[iface] = t:match("inet %d+%.%d+%.%d+%.%d+") and true or false
   check_connected()
end

local function requery_network()
   interface_connected = {}

   for _, iface in ipairs(system.network.interfaces) do
      asyncshell.request(string.format(iproute_command, iface),
                         function(f) iproute_callback(f, iface) end)
   end
end

local function find_traffic()
  local down, up
  local f = io.popen(traffic_command:format(last_iface_connected))
  for line in f:lines() do
    if line:match("RX") ~= nil then
      down = f:lines()():match("(%d+)")
    end
    if line:match("TX") ~= nil then
      up = f:lines()():match("(%d+)")
    end
  end
  f:close()
  return down, up
end

local function calculate_rates()
   local downrate = 0
   local uprate = 0

   if last_iface_connected ~= nil then
     local down, up
     local time_now = socket.gettime()
     down, up = find_traffic()
     local delta = time_now - last_time_measured
     downrate = (down - last_rx_bytes) / delta
     uprate = (up - last_tx_bytes) / delta
     last_rx_bytes = down
     last_tx_bytes = up
     last_time_measured = time_now
   end

   for _, callback in ipairs(callbacks.traffic) do
      callback(downrate, uprate)
   end
end

function system.network.init()
   if initialized then return end
   for _, host in ipairs(system.network.hosts) do
      hosts_metrics[host] = {}
      complete[host] = false
   end
   scheduler.register_recurring("system.network.connection", 10, requery_network)
   scheduler.register_recurring("system.network.latency", system.network.options.interval,
                                  reping_network)
   scheduler.register_recurring("system.network.traffic", 2, calculate_rates)
   initialized = true
end

return system
