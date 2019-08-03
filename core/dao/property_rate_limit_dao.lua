---
--- Properties Request rate limiting dao
-- Copyright (c) 2016 - 2018 www.mwee.cn & Jacobs Lei 
-- Author: Jacobs Lei
-- Date: 2018/4/3
-- Time: 下午6:40

local cjson = require("core.utils.json")
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local dao_config = require("core.dao.config")
local co_parameter_dao = require("core.dao.co_parameter_dao")
local utils = require("core.utils.utils")
local user_log = require("core.log.user_log")
local table = table
local _M = {}



function _M.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select * from p_property_rate_limit where id = ?",
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
-- load all the enable properties rate limiting configuration
-- @param store
--
function _M.load_enable_property_rate_limit_config(store,hosts)
    local data={}
    local ok, e
    ok = xpcall(function()
        local sql = [[select
                      prl.id,
                      prl.name,
                      prl.rate_limit_count,
                      prl.rate_limit_period,
                      prl.is_blocked,
                      prl.block_time,
                      prl.rate_type,
                      prl.effect_s_time,
                      prl.effect_e_time,
                      prl.host_id,
                      h.host,
                      h.gateway_id,
                      g.gateway_code
                    from p_property_rate_limit prl, c_host h,c_gateway g
                    where prl.host_id = h.id and h.gateway_id = g.id and h.enable = 1 and prl.enable = 1]];

        sql = dao_config.add_where_hosts(sql .. " and h.host ",hosts)
        sql = sql .. " order by prl.updated_at desc"
        local flag,objects, err = store:query({
            sql = sql
        })
        if flag then
            for _, prl in ipairs(objects) do
                local property_list = co_parameter_dao.load_co_parameter_by_bizid(prl.id,"property_rate_limit",store)
                if property_list and #property_list >0 then
                    prl["property_detail"] = property_list
                    table.insert(data,prl)
                end
            end
        else
            ngx.log(ngx.ERR, "[FATAL ERROR] load property rate limit information error.")
        end

    end, function()
        e = debug.traceback()
    end)
    if (not ok or e) then
        ngx.log(ngx.ERR, "[FATAL ERROR] load property rate limit information error.",e)
    end
    return data
end

function _M.load_property_rate_limit_config(query_param,store)
    local sql_prefix =[[
        select
          p_property_rate_limit.*,
          c_err_resp_template.id           as err_id,
          c_err_resp_template.http_status as http_status,
          c_err_resp_template.content_type as content_type,
          c_err_resp_template.message      as message,
          c_host.host,
          c_host.enable as host_enable,
          c_gateway.gateway_code,
          c_host.gateway_id
        from p_property_rate_limit
          left join c_err_resp_template on p_property_rate_limit.id = biz_id and plugin_name = 'property_rate_limit'
          , c_host, c_gateway
        where host_id = c_host.id and c_host.gateway_id = c_gateway.id
    ]]
    -- 根据参数动态组装SQL
    local sql,params = dynamicd_build:build_and_condition_like_sql(sql_prefix,query_param)

    local flag,property_rate_limit_config = store:query({
        sql = sql.. dao_config.query_list_order,
        params =params
    })
    -- 取property_detail
    if property_rate_limit_config and #property_rate_limit_config >0 then
        for _, prl in ipairs(property_rate_limit_config) do
            local property_list = co_parameter_dao.load_co_parameter_by_bizid(prl.id,"property_rate_limit",store)
            if property_list and #property_list >0 then
                prl["property_detail"] = property_list
            end
        end
    end

    return property_rate_limit_config
end

function _M.insert(property_rate_limit,store)
    ngx.log(ngx.DEBUG,"insert property_rate_limit...param["..cjson.encode(property_rate_limit).."]")
    local sql ="INSERT INTO `p_property_rate_limit`(`name`,`rate_limit_count`,`rate_limit_period`,`enable`,`is_blocked`,`block_time`,rate_type,host_id"
    if not property_rate_limit.block_time or property_rate_limit.block_time =='' then
        property_rate_limit.block_time = nil
    end
    local params={
        utils.trim(property_rate_limit.name),
        property_rate_limit.rate_limit_count ,
        property_rate_limit.rate_limit_period ,
        property_rate_limit.enable or 0,
        property_rate_limit.is_blocked or 0,
        property_rate_limit.block_time or 0,
        property_rate_limit.rate_type or 0,
        property_rate_limit.host_id or 0
    }
    if not property_rate_limit.rate_type or tonumber(property_rate_limit.rate_type) == 0 then
        sql = sql .. ") VALUES(?,?,?,?,?,?,?,?)"
    else
        sql = sql .. ",effect_s_time,effect_e_time) VALUES(?,?,?,?,?,?,?,?,?,?)"
        table.insert(params,property_rate_limit.effect_s_time)
        table.insert(params,property_rate_limit.effect_e_time)
    end

    local res,id = store:insert({
        sql = sql,
        params=params
    })

    user_log.print_log(store,user_log.module.property_rate_limit .."-新增",nil,property_rate_limit)

    return res,id
end

function _M.update(property_rate_limit,store)
    ngx.log(ngx.DEBUG,"update property_rate_limit...param["..cjson.encode(property_rate_limit).."]")

    user_log.print_log(store,user_log.module.property_rate_limit .."-修改","property_rate_limit_dao",property_rate_limit)

    local sql = "UPDATE `p_property_rate_limit` SET `name` = ?,`rate_limit_count` = ?,`rate_limit_period` = ?,`enable` = ?,`is_blocked` = ?,`block_time` = ?,rate_type=?,host_id=?"

    if tonumber(property_rate_limit.is_blocked) == 0 then
        property_rate_limit.block_time = 0
    end

    local params = {
        property_rate_limit.name,
        property_rate_limit.rate_limit_count ,
        property_rate_limit.rate_limit_period ,
        property_rate_limit.enable,
        property_rate_limit.is_blocked,
        property_rate_limit.block_time,
        property_rate_limit.rate_type or 0,
        property_rate_limit.host_id or 0
    }

    if tonumber(property_rate_limit.rate_type) == 0 then
        sql = sql ..",effect_s_time=null"
        sql = sql ..",effect_e_time=null"
    else

        if property_rate_limit.effect_s_time then
            sql = sql ..",effect_s_time=?"
            table.insert(params,property_rate_limit.effect_s_time)
        end

        if property_rate_limit.effect_e_time then
            sql = sql ..",effect_e_time=?"
            table.insert(params,property_rate_limit.effect_e_time)
        end

    end

    sql = sql .. " WHERE `id` = ?"
    table.insert(params,property_rate_limit.id)
    local res = store : update ({
        sql =sql,
        params = params
    })
    return res
end

function _M.delete(id,store)
    ngx.log(ngx.DEBUG,"delete property_rate_limit id[".. id .."]")

    user_log.print_log(store,user_log.module.property_rate_limit .."-删除","property_rate_limit_dao",{id=id})


    local res = store:delete({
        sql = "delete from `p_property_rate_limit` where `id` = ?",
        params={id}
    })

    return res;
end

function _M.update_enable(id,enable,store)

    user_log.print_log(store,user_log.module.property_rate_limit .. (enable == "1" and "启用" or "禁用"),
            nil,{id=id,enable=enable})

    local res = store : update ({
        sql ="update p_property_rate_limit set enable = ? where id = ?",
        params = {enable,id}
    })
    return res
end

return _M



