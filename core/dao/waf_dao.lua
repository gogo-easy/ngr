---
--- WAF configuration information dao
-- Copyright (c) 2016 - 2018 www.mwee.cn & Jacobs Lei 
-- Author: Jacobs Lei
-- Date: 2018/4/3
-- Time: 下午6:40

local xpcall = xpcall
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local condition_dao = require("core.dao.selector_condition_dao")
local selector_dao = require("core.dao.selector_dao")
local utils = require("core.utils.utils")
local dao_config = require("core.dao.config")
local user_log = require("core.log.user_log")

local _M = {}


function _M.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select * from p_waf where id = ?",
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
--- load all the wafs configuration data from the assiged storage
-- @param store
--
function _M.load_enable_waf_config(store,hosts)

    local ok, e, data
    ok = xpcall(function()
        local sql =[[
            select
              w.id,
              w.name,
              w.is_allowed,
              w.selector_id,
              w.enable,
              w.host_id,
              h.host,
              h.gateway_id,
              g.gateway_code
            from p_waf w, c_host h, c_gateway g
            where
              w.host_id = h.id
              and h.gateway_id = g.id
              and w.enable = 1
              and h.enable = 1
        ]]

        sql = dao_config.add_where_hosts(sql .. " and h.host ",hosts)
        local flag,wafs, err = store:query({
            sql =sql .. " order by w.is_allowed asc,w.updated_at desc",
        })
        if not err and wafs and type(wafs) == "table" then
            for _, waf in ipairs(wafs) do
                local selector_id = waf.selector_id
                local selector = selector_dao.load_selector_by_pk(store,selector_id)
                if ( selector) then
                    waf.selector = selector
                end
            end
            data = wafs
        elseif #wafs == 0 then
            data = wafs
            ngx.log(ngx.ERR, "[FATAL ERROR] no waf configuration information in database.")
        else
            ngx.log(ngx.ERR, "[FATAL ERROR] load waf information error.."..err)
        end
    end,function()
        e = debug.traceback()
    end)
    if ( not ok  or e ) then
        ngx.log(ngx.ERR, "[FATAL ERROR] load waf information error."..e)
    end
    return data
end

--[[
    功能：新增api_group信息
    参数：api_group -- 参考表结构字段传入
         store
]]

-- 新增防火墙
-- 参数：p_waf 参考表结构字段传入
function _M.insert_waf(store,waf)

    user_log.print_log(store,user_log.module.waf .."-新增",nil,waf)

    return store:insert({
        sql = "insert into p_waf (name, is_allowed, enable,selector_id,host_id) values (?,?,?,?,?)",
        params={utils.trim(waf.name),waf.is_allowed,waf.enable,waf.selector_id,waf.host_id or 0}
    })
end

-- 查询 waf
function _M.load_waf(store,waf)

    local sql_prefix =[[
        select
          p_waf.id,
          name,
          is_allowed,
          p_waf.enable,
          selector_id,
          p_waf.created_at,
          p_waf.updated_at,
          p_waf.host_id,
          c_host.host,
          c_host.gateway_id,
          c_host.enable as host_enable,
          c_gateway.gateway_code,
          selector_name,
          selector_type,
          c_err_resp_template.id           as err_id,
          c_err_resp_template.content_type as content_type,
          c_err_resp_template.message      as message,
          c_err_resp_template.http_status as http_status
        from p_waf
          left join c_err_resp_template on p_waf.id = biz_id and plugin_name = 'waf'
          , c_selector,c_host,c_gateway
        where selector_id = c_selector.id
        and p_waf.host_id = c_host.id
        and c_host.gateway_id = c_gateway.id
    ]]
    -- 根据参数动态组装SQL
    local sql,params = dynamicd_build:build_and_condition_like_sql(sql_prefix,waf)

    ngx.log(ngx.DEBUG, "[DEBUG] load_waf sql is:" .. sql)
    local flag,waf = store:query({
        sql = sql .. dao_config.query_list_order,
        params =params
    })
    return waf
end


-- 查询 waf
function _M.load_waf_and_condition(store,waf)
    local  wafs = _M.load_waf(store,waf)

    if wafs and #wafs > 0 then
        for _, waf in ipairs(wafs) do
          local conditions = condition_dao.load_condition_by_selector_id(store,waf.selector_id)
            waf["conditions"] = conditions
        end   
    end
    return wafs
end


-- 查询 waf 简单信息
function _M.load_waf_simple_info(store,id)

    local flag,waf = store:query({
        sql = "select * from p_waf where id=?",
        params ={id}
    })
    return waf
end

-- 更新
function _M.updated_waf(store,waf)

    user_log.print_log(store,user_log.module.waf .."-修改","waf_dao",waf)

    local flag,res = store:query({
        sql = "update p_waf set name =?,is_allowed=?,enable=?,host_id=? where id = ?",
        params ={waf.name,waf.is_allowed,waf.enable,waf.host_id or 0,waf.id}
    })
    return res
end

-- 更新
function _M.updated_enable(store,enable,id)

    user_log.print_log(store,user_log.module.waf .. (enable == "1" and "启用" or "禁用"),
            nil,{id=id,enable=enable})

    local flag,res = store:query({
        sql = "update p_waf set enable =? where id = ?",
        params ={enable,id}
    })
    return res
end

-- delete
function _M.delete_waf(store,id)

    user_log.print_log(store,user_log.module.waf .."-删除","waf_dao",{id=id})

    local flag,res = store:query({
        sql = "delete from p_waf where id =?",
        params ={id}
    })
    return res
end

return _M