
local ngr_cache = require("core.cache.local.global_cache_util")
local ngr_cache_prefix = require("core.cache.local.global_cache_prefix")
local plugin_dao =require("core.dao.plugin_dao")

-- build common apis
return function(plugin)
    local API = {}

    API["/" .. plugin .. "/enable"] = {
        POST = function(store)
            return function(req, res, next)
                local enable = req.body.enable
                if enable == "1" then enable = true else enable = false end

                local plugin_enable = "0"
                if enable then plugin_enable = "1" end
                local update_result = plugin_dao.update_plugin_enable(store,plugin, plugin_enable)

                if update_result then
                    return res:json({
                        success = true ,
                        msg = "successful"
                    })
                else
                    res:json({
                        success = false,
                        msg = "operation failed"
                    })
                end
            end
        end
    }

    return API
end
