---
---API Groups's Request Rate Limit Configuration Dao
-- Author: Jacobs Lei
-- Date: 2018/4/3
-- Time: 下午6:39

local xpcall = xpcall
local debug = debug
local global_cache = require("core.cache.local.global_cache_util")
local global_cache_prefix = require("core.cache.local.global_cache_prefix")
local cjson = require("core.utils.json")
local dao_config = require("core.dao.config")
local user_log = require("core.log.user_log")
local _M = {}


function _M.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select * from c_group_rate_limit where group_id = ?",
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


---
--- 加载所有可用的API组限流配置信息
-- @param store
--
function _M.load_enable_group_rate_limit(store,hosts)
    local ok, e, data,res_flag
    ok = xpcall(function()

        local sql = [[select
                      c.id,
                      c.group_id,
                      c.enable,
                      c.rate_limit_count,
                      c.rate_limit_period
                    from c_host a,c_api_group b,c_group_rate_limit c
                    where a.id = b.host_id and b.id = c.group_id and a.enable = 1 and b.enable = 1
        ]]

        sql = dao_config.add_where_hosts(sql .. " and a.host ",hosts)

        sql = sql .. " order by c.updated_at desc"
        local flag,objects, err = store:query({
            sql = sql,
        })
        res_flag = flag
        data = objects
    end,function()
        e = debug.traceback()
    end)
    if ( not ok  or e ) then
        ngx.log(ngx.ERR, "[FATAL ERROR] load group rate limit information error.")
    end
    return res_flag,data
end

---
--- 通过组id获取组限流信息(优先从local cache获取)
--@param group_id
--@param store
--
function _M.get_by_group_id_from_cache(store,group_id)
    local obj,_ = global_cache.get_json(global_cache_prefix.api_group_rate_limit .. group_id)
    return obj
end

---
--- 通过组id获取组限流信息(从storage中取)
--@param group_id
--@param store
--
function _M.get_by_group_id(store,group_id)
    local ok, e,obj
    ok = xpcall(function()
        local flag,object, err = store:query({
            sql =[[
                select
                  c_group_rate_limit.id,
                  group_id,
                  enable,
                  rate_limit_count,
                  rate_limit_period,
                  c_err_resp_template.id           as err_id,
                  c_err_resp_template.content_type as content_type,
                  c_err_resp_template.message      as message,
                  c_err_resp_template.http_status  as http_status
                from c_group_rate_limit
                  left join c_err_resp_template on c_group_rate_limit.id = biz_id and plugin_name = 'group_rate_limit'
                where group_id = ?
            ]],
            params = {group_id}
        })

        if not err and object and type(object) == "table" and #object >= 1 then
            obj = object[1]
        elseif err then
            ngx.log(ngx.ERR, "[FATAL ERROR] load group[".. group_id .."] rate limit information error:",err)
        end
    end,function()
        e = debug.traceback()
    end)
    if ( not ok  or e ) then
        ngx.log(ngx.ERR, "[FATAL ERROR] load group rate limit information error.", e)
    end
    return obj
end

function _M.insert(store,group_rate_limit)
    ngx.log(ngx.DEBUG,"insert c_group_rate_limit...param["..cjson.encode(group_rate_limit).."]")

    user_log.print_log(store,user_log.module.group_rate_limit .."-新增",nil,group_rate_limit)

    return store:insert({
        sql = "INSERT INTO c_group_rate_limit(group_id,rate_limit_count,rate_limit_period,enable) VALUES (?,?,?,?)",
        params={group_rate_limit.group_id,group_rate_limit.rate_limit_count,group_rate_limit.rate_limit_period,group_rate_limit.enable}
    })
end

function _M.update(store, group_rate_limit)
    ngx.log(ngx.DEBUG,"update c_group_rate_limit...param["..cjson.encode(group_rate_limit).."]")

    user_log.print_log(store,user_log.module.group_rate_limit .."-修改","group_rate_limit_dao",group_rate_limit)

    local res = store:update({
        sql = "UPDATE c_group_rate_limit SET rate_limit_count = ?, rate_limit_period=?,enable=? WHERE group_id = ?",
        params={group_rate_limit.rate_limit_count,group_rate_limit.rate_limit_period,group_rate_limit.enable,group_rate_limit.group_id}
    })
    return res;
end



function _M.delete(store,group_id)
    ngx.log(ngx.DEBUG,"delete c_group_rate_limit...param["..group_id.."]")

    user_log.print_log(store,user_log.module.group_rate_limit .."-删除","group_rate_limit_dao",{id=group_id})

    local res = store:delete({
        sql = "delete from c_group_rate_limit where group_id = ?",
        params={group_id}
    })

    return res;
end


return _M