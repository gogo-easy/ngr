---
--- Created by yusai.
--- DateTime: 2018/9/10 上午11:35
---

local _M = {}

_M.plugin_name = "anti_sql_injection"

_M.anti_sql_injection_prefix ="anti_sql_injection_"
_M.anti_sql_injection_old_all = _M.anti_sql_injection_prefix.."_old_all"

_M.build_cache_asi_host_and_group_context_key = function(host,group_context)
    return (host or "").."_"..(group_context or "")
end

_M.build_cache_anti_sql_injection_key = function(append_key)
    return _M.anti_sql_injection_prefix .. append_key
end
return _M