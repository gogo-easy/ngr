---
--- Created by yusai.
--- DateTime: 2018/9/10 下午1:51
---

local _M = {}

local utils = require("core.utils.utils")
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local dao_config = require("core.dao.config")
local co_parameter_dao = require("core.dao.co_parameter_dao")
local user_log = require("core.log.user_log")

function _M.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select * from p_anti_sql_injection where id = ?",
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

function _M.inster_anti_sql_injection(store,data)

    local res,id = store:insert({
        sql = "INSERT INTO `p_anti_sql_injection`(`group_id`,path,`remark`,`enable`,database_type) VALUES(?,?,?,?,?)",
        params={
            data.group_id,
            utils.trim(data.path),
            utils.trim(data.remark) or '',
            data.enable or 0,
            data.database_type or 'MYSQL'
        }
    })
    user_log.print_log(store,user_log.module.anti_sql_injection .. "-新增",nil,data)
    return res,id
end


function _M.update_anti_sql_injection(store,data)
    -- 记录日志
    user_log.print_log(store,user_log.module.anti_sql_injection .. "-修改","anti_sql_injection_dao",data)

    local res= store:update({
        sql = "update p_anti_sql_injection set group_id=?,path=?,remark=?,enable = ?,update_at =sysdate(),database_type=? where id = ?",
        params={
            data.group_id,
            utils.trim(data.path),
            utils.trim(data.remark),
            data.enable or 0,
            data.database_type or 'MYSQL',
            data.id

        }
    })
    return res
end

function _M.update_enable(store,id,enable)

    local res= store:update({
        sql = "update p_anti_sql_injection set enable=? where id = ?",
        params={
            enable,
            id

        }
    })
    user_log.print_log(store,user_log.module.anti_sql_injection .. (enable == "1" and "启用" or "禁用"),
            nil,{id=id,enable=enable})
    return res
end


function _M.delete_anti_sql_injection(store,id)
    -- 记录日志
    user_log.print_log(store,user_log.module.anti_sql_injection .. "-删除","anti_sql_injection_dao",{id=id})

    local res = store : delete ({
        sql = "delete from `p_anti_sql_injection` where `id` = ?",
        params = {id }
    })
    return res
end


function _M.load_enable_anti_sql_injection(store,hosts)

    local data={}
    local ok, e
    ok = xpcall(function()
        local sql = [[
            select
              d.gateway_code,
              c.host,
              b.group_context,
              a.id,
              a.group_id,
              a.path,
              a.enable,
              a.database_type
            from p_anti_sql_injection a, c_api_group b, c_host c, c_gateway d
            where a.group_id = b.id and b.host_id = c.id and c.gateway_id = d.id
            and c.enable = 1 and a.enable = 1
    ]]
        sql = dao_config.add_where_hosts(sql.."and c.host ",hosts)
        local flag,objects, err = store:query({
            sql = sql
        })
        if flag then
            for _, anti in ipairs(objects) do
                local property_list = co_parameter_dao.load_co_parameter_by_bizid(anti.id,"anti_sql_injection",store)
                if property_list and #property_list >0 then
                    anti["property_list"] = property_list
                    table.insert(data,anti)
                end
            end
        else
            ngx.log(ngx.ERR, "[FATAL ERROR] load anti sql injection information error.")
        end

    end, function()
        e = debug.traceback()
    end)
    if (not ok or e) then
        ngx.log(ngx.ERR, "[FATAL ERROR] load anti sql injection information error.",e)
    end
    return data
end

function _M.load_anti_sql_injection(store,query_param)
    local sql_prefix = [[
        select
          d.gateway_code,
          c.host,
          c.id as host_id,
          c.gateway_id,
          b.group_context,
          a.id,
          a.group_id,
          a.path,
          a.enable,
          a.remark,
          c.enable as host_enable,
          a.database_type
        from p_anti_sql_injection a, c_api_group b, c_host c, c_gateway d
        where a.group_id = b.id and b.host_id = c.id and c.gateway_id = d.id
    ]]
    local sql,params = dynamicd_build:build_and_condition_like_sql(sql_prefix,query_param)
    sql = sql .. " order by a.update_at desc"
    local flag, anti_injection_list= store:query({
        sql = sql,
        params =params
    })
    return flag, anti_injection_list
end

return _M