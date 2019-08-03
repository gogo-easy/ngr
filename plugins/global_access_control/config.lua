---
--- 配置
--- Created by yusai.
--- DateTime: 2018/5/16 下午6:04
---
local _M = {}

_M.name = "global_access_control"


_M.small_error_types = {
    -- see error_utils
    gac = {
        type_service_not_found = "ctl.no_service",
        type_host_error = "ctl.host_error"
    }
}

return _M
