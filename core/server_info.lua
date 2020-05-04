--[[
   Ngr server's base information definition, such as version & name and so on....
--]]
local ngr_cache = require("core.cache.local.global_cache_util")
local ngr_cache_prefix = require("core.cache.local.global_cache_prefix")


local server = {}
server.version = "1.2.0-pre"
server.name="NgrRouter"
server.full_name = server.name .. "/" .. server.version
server.last_sync_time = ngr_cache.get(ngr_cache_prefix.server_info .. "last_sync_time")
return server