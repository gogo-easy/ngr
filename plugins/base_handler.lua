--
-- Base Plugin Handler Type, all the plugins extends from this type
-- from https://github.com/Mashape/kong/blob/master/kong/plugins/base_plugin.lua
-- modified by Jacobs Lei

local Object = require("core.framework.classic")
local base_handler = Object:extend()
local ngx_log_level = ngx.DEBUG

function base_handler:new(name)
    self._name = name
end

function base_handler:get_name()
    return self._name
end

---
-- init_worker phase's plugin executing method. just execute one time
--
--
function base_handler:init_worker()
    ngx.log(ngx_log_level, " executing plugin \"", self._name, "\": init_worker")
end

---
--- init_worker phase's plugin scheduling executing method for loading plugin's base information. execute time by time as an interval
--
function base_handler:init_worker_timer()
    ngx.log(ngx_log_level, " executing plugin \"", self._name, "\": init_worker_timer")
end

---
--- init_worker phase's other plugin scheduling executing method(for loading plugin's extension information), execute time by time as an interval
--
function base_handler:init_worker_ext_timer()
    ngx.log(ngx_log_level, " executing plugin \"", self._name, "\": init_worker_ext_timer")
end

function base_handler:access()
    ngx.log(ngx_log_level, " executing plugin \"", self._name, "\": access")
end

function base_handler:header_filter()
    ngx.log(ngx_log_level, " executing plugin \"", self._name, "\": header_filter")
end

function base_handler:body_filter()
    ngx.log(ngx_log_level, " executing plugin \"", self._name, "\": body_filter")
end

function base_handler:log()
    ngx.log(ngx_log_level, " executing plugin \"", self._name, "\": log")
end

function base_handler:balancer()
    ngx.log(ngx_log_level, " executing plugin \"", self._name, "\": balancer")
end

return base_handler
