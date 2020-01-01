---
---
-- Selector Condition configuration information dao
-- Copyright (c) GoGo Easy Team & Jacobs Lei
-- Author: Jacobs Lei
-- Date: 2018/4/3
-- Time: 下午6:41

local xpcall = xpcall
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local utils = require("core.utils.utils")
local user_log = require("core.log.user_log")

local _dao = {}


function _dao.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select * from c_selector_condition where id = ?",
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

function _dao.load_condition(store,condition_param)

    local sql_prefix = "select id, selector_id,param_type,condition_opt_type,param_name,param_value from c_selector_condition where 1=1"

    local sql,params = dynamicd_build:build_and_condition_sql(sql_prefix,condition_param)

    return store:query({
            sql = sql,
            params = params
        })
end

function _dao.get_selector_id_by_id(store,id)
    local flag,ids,err = store:query({
        sql = "select selector_id from c_selector_condition where id =?",
        params = {id}
    })
    if ids and #ids > 0 then
        local data = ids[1]
        return data.selector_id,nil
    end
    return nil,err
end

function _dao.check_repeat(store, condition)
    local flag,results,err = store:query({
        sql = "select id from c_selector_condition where param_type=? and condition_opt_type=? and param_name=? and param_value=? and selector_id=?",
        params = {utils.trim(condition.param_type),
                  utils.trim(condition.condition_opt_type),
                  utils.trim(condition.param_name) ,
                  utils.trim(condition.param_value),
                  condition.selector_id}
    })
    if not flag or err then
        ngx.log(ngx.ERR,"check_repeat err:",err)
        return false,"query failed"
    end
    if not results or #results == 0 then
        return true,nil
    end
    if condition.id then
        for _, result in ipairs(results) do
            if tonumber(condition.id) ~= tonumber(result.id) then
                return false,"条件已存在"
            end
        end
    else
        return false,"条件已存在"
    end
    return true,nil
end

function _dao.load_condition_by_selector_id(store,selector_id)
    if not selector_id or selector_id == "" then
        return nil
    end
    local ok, e, data
    ok = xpcall(function()
        local flag,conditions, err = store:query({
            sql = "select id, selector_id,param_type,condition_opt_type,param_name,param_value from c_selector_condition where selector_id = ?",
            params = {selector_id}
        })

        if not err and conditions and type(conditions) == "table" then
            data = conditions
        else
            ngx.log(ngx.ERR, "[FATAL ERROR] load conditions by selector_id["..selector_id.."] information error.")
        end
    end,function()
        e = debug.traceback()
    end)
    if ( not ok  or e ) then
        ngx.log(ngx.ERR, "[FATAL ERROR] load conditions by selector_id["..selector_id.."] information error.")
    end
    return data
end


function _dao.delete_conditions_by_id(store, id)

    user_log.print_log(store,user_log.module.selector_condition .."-删除","selector_condition_dao",{id=id})


    local delete_result = store:delete({
        sql = "delete from c_selector_condition where `id` = ? ",
        params = { id }
    })
    if delete_result then
        return true
    else
        ngx.log(ngx.ERR, "delete conditions of selector err, id", id)
        return false
    end
end


function _dao.delete_conditions_of_selector(store, selector_id)

    user_log.print_log(store,user_log.module.selector_condition .."-删除",nil,{selector_id=selector_id})

    local delete_result = store:delete({
        sql = "delete from c_selector_condition where `selector_id` = ? ",
        params = { selector_id }
    })
    if delete_result then
        return true
    else
        ngx.log(ngx.ERR, "delete conditions of selector err, selector_id", selector_id)
        return false
    end
end

function _dao.update_condition(store, condition)

    user_log.print_log(store,user_log.module.selector_condition .."-修改","selector_condition_dao",condition)

    return store:update({
        sql = "update c_selector_condition set param_type=?,condition_opt_type=?,param_name=?,param_value=? where id = ?",
        params = {utils.trim(condition.param_type),
                  utils.trim(condition.condition_opt_type),
                  utils.trim(condition.param_name) ,
                  utils.trim(condition.param_value),condition.id}
    })
end

function _dao.create_condition(store, condition)

    user_log.print_log(store,user_log.module.selector_condition .."-新增",nil,condition)

    return store:insert({
        sql = "insert into c_selector_condition(`selector_id`, `param_type`, `condition_opt_type`, `param_name`,`param_value`) values(?,?,?,?,?)",
        params = { condition.selector_id,
                   utils.trim(condition.param_type),
                   utils.trim(condition.condition_opt_type),
                   utils.trim(condition.param_name) ,
                   utils.trim(condition.param_value)}
    })
end

function _dao.count_condition_by_selectorid(store, selector_id)
    local flag,data, err = store:query({
        sql = "select count(*) as count_num from c_selector_condition where selector_id = ?",
        params = {selector_id}
    })
    if not err and flag then
        return data[1].count_num
    else
        ngx.log(ngx.ERR, "[FATAL ERROR] count conditions by selector_id["..selector_id.."] information error.")
    end
end

return _dao

