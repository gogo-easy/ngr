---
--- 功能：waf 常量配置
--- Created by: yusai.
--- DateTime: 2018/5/2
---

local _M = {}

  _M.plugin_name = "waf"

 _M.build_waf_hit_record_key = function (gateway_code,host,current_day)
    return _M.plugin_name .. gateway_code .. "_" .. host .."_hit_record_"..current_day
  end

  _M.waf_judge_record_expire_days = 5


_M.small_error_types = {
  sys =  {
    type_waf_exe_error = "waf.exe_error",
    type_waf_add_hit_error = "waf.add_hit_error",
  },
  biz = {
    type_waf_hit = "waf.waf_hit"
  }
}

--- 防火墙配置数据前缀
_M.prefix_waf = "waf_"
_M.waf_old_all = _M.prefix_waf.."_old_all"
_M.build_cache_waf_key = function(host)
  return (host or "") .. _M.prefix_waf
end

return _M