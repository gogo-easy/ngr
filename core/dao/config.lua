--- dao 公用配置
--- Created by yusai.
--- DateTime: 2018/6/7 下午1:54
---

local _M = {}

_M.query_list_order = " order by updated_at desc"

-- 默认路由的group_context
_M.default_group_context = "-default-";

_M.add_where_hosts = function(sql_prefix,hosts)
    sql_prefix = sql_prefix .." in("
    for _, host in ipairs(hosts) do
        sql_prefix = sql_prefix .. "'"..host .."',"
    end
    sql_prefix = string.sub(sql_prefix,1,string.len(sql_prefix)-1)
    sql_prefix = sql_prefix ..")"
    return sql_prefix
end
return _M