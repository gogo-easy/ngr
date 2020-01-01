---
---  Global rate limiting plugin's config information define
--- Copyright (c) GoGo Easy Team & Jacobs Lei
--- Author: Jacobs Lei
--- Date: 2018/4/9
--- Time: 下午2:05

local _M = {}

_M.name = "global_rate_limit"
_M.property_key_rate_limit_count = "GLOBAL_RATE_LIMIT_COUNT"
_M.property_key_rate_limit_period = "GLOBAL_RATE_LIMIT_PERIOD"

_M.small_error_types = {
    sys =  {
        type_plugin_conf = "grl.conf_error"
    },
    biz = {
        type_rate_control = "grl.reject"
    }
}

return _M

