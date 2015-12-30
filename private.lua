local utility = require('utility')
local util = require('awful.util')

local private = {}

local locations =
   { thessaloniki = { city = "Thessaloniki", country = "Greece",
                lat = 40.6335, lon = 22.9437,
                gmt = 2 }}
private.user = { name = "tsirif",
                 loc = locations.thessaloniki }

-- forecast.io API key is read from ./.forecast_io_api_key file
private.weather = { api_key = utility.slurp(util.getdir("config") ..
                                               "/.forecast_io_api_key", "*line") }

return private
