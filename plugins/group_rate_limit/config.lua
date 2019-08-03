---
---  Group rate limiting plugin's global configuration constant
--- Created by jacobs.
--- DateTime: 2018/4/10 下午3:59
---

local _M = {}

_M.name = "group_rate_limit"

_M.small_error_types = {
    sys =  {
        type_plugin_conf = "grp.conf_error"
    },
    biz = {
        type_rate_control = "grp.reject",
        type_service_not_found = "grp.no_service"
    }
}


return _M