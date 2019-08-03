---
--- Selector configuration information dao
-- Copyright (c) 2016 - 2018 www.mwee.cn & Jacobs Lei 
-- Author: Jacobs Lei
-- Date: 2018/4/3
-- Time: 下午6:41

local xpcall = xpcall
local condition_dao = require("core.dao.selector_condition_dao")
local ngr_cache = require("core.cache.local.global_cache_util")
local ngr_cache_prefix = require("core.cache.local.global_cache_prefix")
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local utils = require("core.utils.utils")

local _dao = {}

function _dao.load_selector(store,selector_params)

    local sql_frefix = "select id, selector_name,selector_type,enable from c_selector where 1=1"

    local sql,params = dynamicd_build:build_and_condition_sql(sql_frefix,selector_params)

    return store:query({
        sql = sql,
        params = params
    })
end

function _dao.load_selector_by_pk(store,selector_id)

    if not selector_id or selector_id == "" then
        return nil
    end

    local ok, e, data
    ok = xpcall(function()
        local flag,selectors, err = store:query({
            sql = "select id, selector_name,selector_type from c_selector where enable = 1 and id = ?",
            params = { selector_id }
        })
        if not err and selectors and type(selectors) == "table" and #selectors > 0 then
            local selector = selectors[1]
            local conditions = condition_dao.load_condition_by_selector_id ( store, selector_id)
            if conditions and type(conditions) ==  "table"  then
                    selector.conditions = conditions
                    data = selector
            else
                ngx.log(ngx.ERR, "[FATAL ERROR] load conditions by selector_id[" .. selector_id .."] error.")
            end
        else
            ngx.log(ngx.ERR, "[FATAL ERROR] load selector[" .. selector_id .."] information error.")
        end
    end,function()
        e = debug.traceback()
    end)
    if ( not ok  or e ) then
        ngx.log(ngx.ERR, "[FATAL ERROR] load waf information error.")
    end
    return data
end


function _dao.update_selector(store, selector)
    if not selector or type(selector) ~= "table" then
        return false
    end
    ngx.log(ngx.ERR,"update_selector===",selector.id)
    local result = store:update({
        sql = "update c_selector  set `selector_name` = ?, `selector_type`=?,`enable`=?  where `id`=? ",
        params = {selector.selector_name, selector.selector_type,selector.enable,selector.id}
    })

    return result
end

function _dao.delete_selector(store, selector_id)
    local delete_result = store:delete({
        sql = "delete from c_selector where `id` = ? ",
        params = { selector_id}
    })
    if delete_result then
        return true
    else
        ngx.log(ngx.ERR, "delete selector err, ", selector_id)
        return false
    end
end



function _dao.update_local_selector_condition(store, selector_id)
    if not selector_id then
        ngx.log(ngx.ERR, "error to find selector from storage when updating local selector condition, selector_id is nil")
        return false
    end

    local selector = _dao.load_selector_by_pk(store, selector_id)
    if not selector  then
        ngx.log(ngx.ERR, "error to find selector from storage when updating local selector condition, selector_id:", selector_id)
        return false
    end

    local success, err, forcible = ngr_cache.set_json(ngr_cache_prefix.selector..selector_id, selector)
    if err or not success then
        ngx.log(ngx.ERR, "update local selector and conditions  error, err:", err)
        return false
    end
    return true
end


function _dao.create_selector(store, selector)
    return store:insert({
        sql = "insert into c_selector(`selector_name`, `selector_type`, `enable`) values(?,?,?)",
        params = {utils.trim(selector.selector_name), selector.selector_type, "1" }
    })
end


return _dao