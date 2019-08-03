---define cache prefix for using ngx.dict

local prefix = {}

--- api组配置数据前缀
prefix.api_group = "api_group_"

--- 上次api group 数据
prefix.old_api_group_all = "old_api_group_all"

--- 插件配置数据前缀
prefix.plugin = "plugin_"

--- 全局属性配置数据前缀
prefix.global_property = "global_property_"

--- api组限速配置数据前缀
prefix.api_group_rate_limit = "api_group_rate_limit_"



--- 防火墙配置数据前缀
prefix.waf = "waf_"

-- 限速配置数据前缀
prefix.rate_limit = "rate_limit-"


--- 选择器配置数据前缀
prefix.selector = "selector_"

prefix.remove_healthchecker_all ="remove_healthchecker_names"

return prefix