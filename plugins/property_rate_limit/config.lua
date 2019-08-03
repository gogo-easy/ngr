---
---  Property rate limit plugin' common static config
--- Created by jacobs.
--- DateTime: 2018/4/27 下午2:14
---

local _M = {}

_M.plugin_name = "property_rate_limit"
_M.blocked_key_prefix = _M.plugin_name .. "_blocked_"

_M.blocked_record_list_key_prefix = _M.plugin_name .. "_blocked_record_list_"
_M.limit_record_list_key_prefix = _M.plugin_name .. "_limit_record_list_"
_M.blocked_record_expire_days = 5
_M.limit_record_expire_days = 5

_M.small_error_types = {
    biz = {
        type_property_reject = "pro.reject"
    },
    sys = {
        type_property_set_blocked_error = "pro.set_blo_err",
        type_property_added_limit_error = "pro.add_lim_err",
        type_property_added_blocked_error = "pro.add_blo_err",
    }
}

--- 特征限速防刷配置数据前缀
_M.property_rate_limit = "property_rate_limit_"
_M.property_rate_limit_old_all = "property_rate_limit_old_all"


_M.build_property_rate_limit_key = function (host)
    return (host or '') .."_".._M.property_rate_limit
end

_M.build_limit_recored_key = function (gateway_code,host,day)
    return _M.limit_record_list_key_prefix..gateway_code.."_"..host.."_"..day;
end

_M.blocked_recored_key = function (gateway_code,host,day)
    return _M.blocked_record_list_key_prefix..gateway_code.."_"..host.."_"..day;
end

return _M