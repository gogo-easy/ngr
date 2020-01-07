local ngr_cache = require("core.cache.local.global_cache_util")
local ngr_cache_prefix = require("core.cache.local.global_cache_prefix")
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local group_rate_limit = require("core.dao.group_rate_limit_dao")
local group_target_dao = require("core.dao.group_target_dao")
local user_log = require("core.log.user_log")

local utils = require("core.utils.utils")
local dao_config = require("core.dao.config")
local cjson = require("core.utils.json");
local debug = debug
local ngx = ngx
local _M={}


function _M.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select * from c_api_group where id = ?",
        params ={
            id
        }
    })
    if info and #info >0 then
        return info[1]
    else
        return nil
    end
end


--[[
    功能：根据请求参数获取api_group 信息
    参数：req_api_group -- table
         store
]]
function _M.load_api_group_info(req_api_group,store)

    local sql_prefix =[[
        select
          c_api_group.*,
          c_host.host,
          c_host.gateway_id,
          c_host.enable                       host_enable,
          c_gateway.gateway_code,
          c_err_resp_template.id           as err_id,
          c_err_resp_template.content_type as content_type,
          c_err_resp_template.message      as message,
          c_err_resp_template.http_status      as http_status
        from c_api_group
          join c_host on c_api_group.host_id = c_host.id
          join c_gateway on c_host.gateway_id = c_gateway.id
          left join c_err_resp_template on c_api_group.id = biz_id and plugin_name = 'api_router'
        where 1 = 1
    ]]
    -- 根据参数动态组装SQL
    local sql,params = dynamicd_build:build_and_condition_like_sql(sql_prefix,req_api_group)
    local flag,api_group = store:query({
        sql = sql .. dao_config.query_list_order,
        params =params
    })

    if api_group and type(api_group) and #api_group > 0 then
        return true,api_group
    end

    return false,nil
end

function _M.load_api_group_info_by_ip(req_api_group,store,ip)

    local sql_prefix =[[
        select
          distinct
          c_api_group.*,
          c_host.host,
          c_host.gateway_id,
          c_host.enable                       host_enable,
          c_gateway.gateway_code,
          c_err_resp_template.id           as err_id,
          c_err_resp_template.content_type as content_type,
          c_err_resp_template.message      as message,
          c_err_resp_template.http_status      as http_status
        from c_api_group
          join c_host on c_api_group.host_id = c_host.id
          join c_gateway on c_host.gateway_id = c_gateway.id
          join c_group_target on c_api_group.id = c_group_target.group_id
          left join c_err_resp_template on c_api_group.id = biz_id and plugin_name = 'api_router'
        where 1 = 1
    ]]
    -- 根据参数动态组装SQL
    local sql,params = dynamicd_build:build_and_condition_like_sql(sql_prefix,req_api_group)
    sql = sql .. " and c_group_target.host = '"..ip.."'"
    local flag,api_group = store:query({
        sql = sql .. dao_config.query_list_order,
        params =params
    })

    if api_group and type(api_group) and #api_group > 0 then
        return true,api_group
    end

    return false,nil
end

function _M.query_simple_group_info(store, req_api_group)
    local sql = "select a.id,a.group_context,a.host_id,a.enable_balancing from c_api_group a where 1=1"

    local params = {}
    if req_api_group and req_api_group.host_id then
        sql = sql .. "and host_id=?"
        params.host_id = req_api_group.host_id
    end

    local flag,api_group = store:query({
        sql = sql,
        params = params
    })

    if api_group and type(api_group) and #api_group > 0 then
        return true,api_group
    end

    return false,nil
end

--[[
    功能：查询所有未配置限流规则的组id
    参数：store
]]
function _M.load_not_group_rate_limit(store,hosts)

    local ok, e, data,res_flag
    ok = xpcall(function ()
        local sql = [[select a.id
                from c_api_group a, c_host c
                where a.host_id = c.id and not exists(select 1
                                                      from c_group_rate_limit b
                                                      where a.id = b.group_id and b.enable = 1)
        ]]

        sql = dao_config.add_where_hosts(sql .." and c.host ",hosts)

        local flag,ids = store:query({
            sql = sql
        })
        res_flag = flag
        data = ids

    end,function ()
        e = debug.traceback()
    end)

    if ( not ok  or e ) then
        ngx.log(ngx.ERR, "[FATAL ERROR] load group rate limit error.")
    end

    return res_flag,data
end

--[[
    功能：根据请求参数获取api_group 和 group_rate_limit  信息
    参数：req_api_group -- table
         store
]]
function _M.load_api_group_and_rate_limit(req_api_group,store,ip)

    local flag,content
    if ip then
        flag ,content = _M.load_api_group_info_by_ip(req_api_group,store,ip)
    else
        flag ,content = _M.load_api_group_info(req_api_group,store)
    end
    if content then
        for _, v in ipairs(content) do
          local group_rate =   group_rate_limit.get_by_group_id(store,v.id)
            if group_rate then
                v["group_rate_limit"] = group_rate
            end
          local _, group_target = group_target_dao.query_target_and_gray_divide_count_by_group_id(v.id, store)
            if group_target then
                v["group_target"] = group_target
            end
        end
        return true,content
    end
    return false,nil
end

--[[
    功能：新增api_group信息
    参数：api_group -- 参考表结构字段传入
         store
]]
function _M.insert_api_group(api_group,store)
    ngx.log(ngx.INFO,"insert_api_group...param【"..cjson.encode(api_group).."】")

    -- 记录日志
    user_log.print_log(store,user_log.module.api_router .."-新增",nil,api_group)

    local sql = [[
            insert into c_api_group
                (group_name,
                 group_context,
                 upstream_domain_name,
                 upstream_service_id,
                 enable_balancing,
                 need_auth,
                 enable,
                 lb_algo,
                 gen_trace_id,
                 host_id,
                 enable_rewrite,
                 rewrite_to)
                values (?, ?, ?, ?, ?, ?, ?, ?, ?, ? , ?, ?);
        ]]
    return store:insert({
        sql = sql,
        params={
                utils.trim(api_group.group_name),
                utils.trim(api_group.group_context),
                utils.trim(api_group.upstream_domain_name),
                utils.trim(api_group.upstream_service_id) or 0,
                api_group.enable_balancing or 0,api_group.need_auth or 0,api_group.enable or 0,api_group.lb_algo or 0,
                api_group.gen_trace_id or 0,
                api_group.host_id,
                api_group.enable_rewrite or 0,
                api_group.rewrite_to or "",
        }
    })
end


--[[
    功能：修改api_group信息
    参数：api_group  参考c_api_group表结构字段传入
         store
]]
function _M.update_api_group(api_group,store)
    ngx.log(ngx.INFO,"update_api_group...param【"..cjson.encode(api_group).."】")
    -- 记录日志
    user_log.print_log(store,user_log.module.api_router .. "-修改","api_router_dao",api_group)

    local sql = [[
        UPDATE c_api_group
            set group_name = ?, group_context = ?, upstream_domain_name = ?, upstream_service_id = ?, enable_balancing = ?,
              need_auth    = ?, enable = ?, lb_algo = ?, host_id = ?, gen_trace_id = ?,enable_rewrite = ?,rewrite_to = ?, updated_at = sysdate()
            where id = ?
    ]]
    local res = store:update({
        sql = sql,
        params={
            api_group.group_name,
            api_group.group_context,
            api_group.upstream_domain_name,
            api_group.upstream_service_id or 0,
            api_group.enable_balancing or 0,
            api_group.need_auth or 0,
            api_group.enable,
            api_group.lb_algo or 0,
            api_group.host_id,
            api_group.gen_trace_id,
            api_group.enable_rewrite or 0,
            api_group.rewrite_to or "",
            api_group.id
        }
    })
    return res;
end

--[[
    功能：删除api_group信息
    参数：id  主键
         store
]]
function _M.delete_api_group(id,store)
    -- 记录日志
    user_log.print_log(store,user_log.module.api_router .. "-删除","api_router_dao",{id=id})

    local res = store:delete({
        sql = "delete from c_api_group where id = ?",
        params={id}
    })
    return res;
end

function _M.update_api_group_enable(api_group,store)
    local res = store:update({
        sql = "UPDATE c_api_group set enable=? where id = ?",
        params={
            api_group.enable,
            api_group.id
        }
    })
    user_log.print_log(store,user_log.module.api_router.. (api_group.enable == "1" and "启用" or "禁用"),
            nil,{id=api_group.id,enable=api_group.enable})

    return res;
end


function _M.query_group_info_by_hosts(hosts,store)

    if(not hosts and #hosts < 1) then
        ngx.log(ngx.ERR, "query group info by hosts：hosts can not be empty")
        return nil
    end

    local query_string = string.rep("?,",#hosts)
    local param_string = string.sub(query_string,1,string.len(query_string)-1)
    local sql_string = "select b.id,b.gen_trace_id,b.group_name,b.group_context,"..
            "b.upstream_domain_name,b.upstream_service_id,b.enable_balancing,b.need_auth,"..
            "b.lb_algo,b.enable,b.host_id,b.enable_rewrite,b.rewrite_to,"..
            "a.host from c_host a,c_api_group b  " ..
            "where a.id=b.host_id and b.enable=1 and a.enable=1 and a.host in(" .. param_string .. ")"
    local flag,api_groups,err = store:query({
        sql = sql_string,
        params=hosts
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when initializing api groups error:", err)
        return nil
    end
    return api_groups
end

function _M.query_enable_api_group_from_store(store)
    local flag,api_groups, err = store:query({
        sql = "select * from c_api_group where enable = 1",
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when initializing api groups error:", err)
        return nil
    end
    return api_groups
end

-- =========================== 从全局缓存里获取信息 ==============

function _M.get_api_group_by_group_context(host,group_context)

    local host_group_context = _M.build_host_group_context(host,group_context)
    local res,flag =ngr_cache.get_json(ngr_cache_prefix.api_group..host_group_context);
    if res then
        return res;
    end
    ngx.log(ngx.ERR, "can not  get object table from local cache, cache_key=", ngr_cache_prefix.api_group..host_group_context)
    return nil
end

function _M.build_host_group_context(host,group_context)
    return (host or '').."-"..(group_context or '')
end

return _M;