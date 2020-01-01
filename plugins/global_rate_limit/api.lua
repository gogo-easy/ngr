---
--- 全局限流 RESTFUL API
--- Copyright (c) GoGo Easy Team & Jacobs Lei
--- Author: Jacobs Lei
--- Date: 2018/5/2
--- Time: 上午10:45

local global_cache = require("core.cache.local.global_cache_util")
local global_cache_prefix = require("core.cache.local.global_cache_prefix")
local plugin_config = require("plugins.global_rate_limit.config")

local BaseAPI = require("plugins.base_api")
local API = BaseAPI:new(plugin_config.name, 2)

API:get("/".. plugin_config.name .."/info", function(store,cache_client)
    return function(req, res, next)
        local limit_period = global_cache.get(global_cache_prefix.global_property .. plugin_config.property_key_rate_limit_period)
        local limit_count = global_cache.get(global_cache_prefix.global_property.. plugin_config.property_key_rate_limit_count)
        local result = {}
        if limit_period and limit_count then
            result.success = true
            result.err_msg = "ok"
            result.data = {
                limit_period = limit_period,
                limit_count = limit_count
            }
        else
             result = {
                success = false,
                err_msg = "global rate limit information do not exist."

            }
        end
        res:json(result)
    end
end)

return API