---
---Base Data access object for initializing global properties configuration, plugins and api groups
-- Copyright (c) GoGo Easy Team & Jacobs Lei
--- Author: Jacobs Lei
-- Date: 2018/4/3
-- Time: 下午6:39

local ipairs = ipairs
local type = type
local xpcall = xpcall
local ngr_cache = require("core.cache.local.global_cache_util")
local ngr_cache_prefix = require("core.cache.local.global_cache_prefix")
local waf_config = require("plugins.waf.config")
local anti_sql_injection_config = require("plugins.anti_sql_injection.config")
local group_rate_limit_dao = require("core.dao.group_rate_limit_dao")
local property_rate_limit_dao = require("core.dao.property_rate_limit_dao")
local waf_dao = require("core.dao.waf_dao")
local plugin_dao = require("core.dao.plugin_dao")
local api_router_dao = require("core.dao.api_router_dao")
local host_dao = require("core.dao.host_dao")
local property_rate_limit_config = require("plugins.property_rate_limit.config")
local anti_sql_injection_dao = require("core.dao.anti_sql_injection_dao")
local cjson = require("core.utils.json")


local _M = {
    desc = "base storage access & local cache manage"
}


-- ########################### local cache init start #############################

local function group_by_host(objects,old_host_data)
    local data={}
    -- 以host为一组。
    for _,item in ipairs(objects) do
        local contents = data[item.host]
        if not contents then
            local contents = {}
            table.insert(contents,item)
            data[item.host] = contents
            -- 清理host
            if old_host_data then
                old_host_data[item.host] = nil
            end
        else
            table.insert(contents,item)
            data[item.host] = contents
        end
    end
    return data,old_host_data
end

local function group_by_host_and_group_context(objects,old_data)
    local data={}
    -- 以host为一组。
    for _,item in ipairs(objects) do
        local key = anti_sql_injection_config.build_cache_asi_host_and_group_context_key(item.host,item.group_context)
        local contents = data[key]
        if not contents then
            local contents = {}
            table.insert(contents,item)
            data[key] = contents
            -- 清理host
            if old_data then
                old_data[key] = nil
            end
        else
            table.insert(contents,item)
            data[key] = contents
        end
    end
    return data,old_data
end

---
--initializing plugin base information form database storage
--@param plugin plugin's name
--@param store storage object

function _M.init_enable_of_plugin(plugin_name, store)
    local success, plugin = plugin_dao.load_plugin_by_plugin_name(plugin_name,store)
    if success and plugin then
        ngr_cache.set_json(ngr_cache_prefix.plugin  .. plugin_name, plugin)
    else
        ngx.log(ngx.ERR, "The plugin[" .. plugin_name .. "] can not been found in database storage .")
        return false,nil
    end

    return true, plugin
end

---
--- initializing group rate limit configuration to global local cache
-- @param store
--
function _M.init_enable_group_rate_limit(store,hosts)

    local flag,objects = group_rate_limit_dao.load_enable_group_rate_limit(store,hosts)

    if flag then
        if ( objects and #objects > 0 ) then
            for _,item in ipairs(objects) do
                local success, err, forcible = ngr_cache.set_json(ngr_cache_prefix.api_group_rate_limit .. item.group_id, item)
                if err or not success then
                    ngx.log(ngx.ERR, "init_enable_group_rate_limit[" .. item.group_id .. "]  error, err:", err)
                    return false
                end
            end
        end
    end

    -- 从缓存中剔除已删除的限流规则
    local id_flag,rate_limits = api_router_dao.load_not_group_rate_limit(store,hosts)
    if id_flag then
        if ( rate_limits and #rate_limits > 0 ) then
            for _,rate_limit in ipairs(rate_limits) do
                local success, err, forcible = ngr_cache.delete(ngr_cache_prefix.api_group_rate_limit .. rate_limit.id)
                if err or not success then
                    ngx.log(ngx.ERR, "init_enable_group_rate_limit delete [" .. rate_limit.id .. "]  error, err:", err)
                    return false
                end
            end
        end
    end

    return true
end

---
--- initializing property rate limit configuration to global local cache
-- @param store
--
function _M.init_property_rate_limit(store,hosts)

    local objects = property_rate_limit_dao.load_enable_property_rate_limit_config(store,hosts)

    local data = {}
    local old_host_data = ngr_cache.get_json(property_rate_limit_config.property_rate_limit_old_all)

    if objects and #objects > 0 then

        -- 按host 分组
        data,old_host_data = group_by_host(objects,old_host_data)
        -- 缓存特征数据，用于清理
        ngr_cache.set_json(property_rate_limit_config.property_rate_limit_old_all, data)
        -- 处理每个对应的特征列表
        for host,prls in pairs(data) do
            local property_rate_config = {}
            for _,prl in ipairs(prls) do
                local property_detail = prl.property_detail
                local key_prefix = prl.id
                for _, pd in ipairs(property_detail) do
                    key_prefix = key_prefix .. "-" ..pd.property_type.."_|_" ..pd.property_name
                end
                property_rate_config[key_prefix] = prl
            end
            local success, err, forcible = ngr_cache.set_json(property_rate_limit_config.build_property_rate_limit_key(host), property_rate_config)
            if err or not success then
                ngx.log(ngx.ERR, "init_property_rate_limit_config into ngr cache  error, err:", err)
            end
        end
    end
    -- 清理数据
    for host,_ in pairs(old_host_data or {}) do
        local success, err, forcible = ngr_cache.delete(property_rate_limit_config.build_property_rate_limit_key(host))
        if err or not success then
            ngx.log(ngx.ERR, "init_property_rate_limit delete: [" .. host .. "] error, err:", err)
        end
    end
    return true
end

---
--- initialzing waf configuration to global local cache
--- including selectors, conditions
-- @param store
--
function _M.init_waf(store,hosts)
    local wafs = waf_dao.load_enable_waf_config(store,hosts)
    local data = {}
    local old_host_data = ngr_cache.get_json(waf_config.waf_old_all)
    if wafs and #wafs >0 then
        -- 按host 分组
        data,old_host_data = group_by_host(wafs,old_host_data)
        -- 缓存，用于清理
        ngr_cache.set_json(waf_config.waf_old_all, data)

        -- 按 host 缓存
        for host,objs in pairs(data) do
            local success, err, forcible = ngr_cache.set_json(waf_config.build_cache_waf_key(host), objs)
            if ( not success or err ) then
                ngx.log(ngx.ERR, "Init wafs information WAFS【"..host.."】 error:", err)
            end
        end
    end
    -- 清理
    if old_host_data then
        for host,_ in pairs(old_host_data) do
            local success, err, forcible = ngr_cache.delete(waf_config.build_cache_waf_key(host))
            if ( not success or err ) then
                ngx.log(ngx.ERR, "delete waf WAF【".. host .."】 error:", err)
            end
        end
    end
end

function _M.init_anti_sql_injection(store,hosts)
   local anti_sql_injections = anti_sql_injection_dao.load_enable_anti_sql_injection(store,hosts)

    ngx.log(ngx.DEBUG,"init anti sql injection query data:",cjson.encode(anti_sql_injections))

    local data = {}
    local old_data = ngr_cache.get_json(anti_sql_injection_config.anti_sql_injection_old_all)
    if anti_sql_injections and #anti_sql_injections > 0 then
        -- 按host 分组
        data,old_data = group_by_host_and_group_context(anti_sql_injections,old_data)
        -- 缓存，用于清理
        ngr_cache.set_json(anti_sql_injection_config.anti_sql_injection_old_all, data)

        for key,objs in pairs(data) do
            local success, err, forcible = ngr_cache.set_json(anti_sql_injection_config.build_cache_anti_sql_injection_key(key), objs)
            if ( not success or err ) then
                ngx.log(ngx.ERR, "Init anti sql injection information error 【".. host .."】 error:", err)
            end
        end
    end

    -- 清理
    if old_data then
        for key,_ in pairs(old_data) do
            local success, err, forcible = ngr_cache.delete(anti_sql_injection_config.build_cache_anti_sql_injection_key(key))
            if ( not success or err ) then
                ngx.log(ngx.ERR, "delete anti sql injection【".. key .."】 error:", err)
            end
        end
    end
end


function _M.init_rate_limit(store,hosts)
    if not hosts or #hosts ==0 then
        ngx.log(ngx.ERR, "hosts must be configured!")
        return
    end

    for _, host in ipairs(hosts) do
        local flag, results = host_dao.query_rate_limit_by_host(host,store)
        if flag==true and #results == 1 then
            ngr_cache.set_json(ngr_cache_prefix.rate_limit .. host, results[1])
        else
            ngx.log(ngx.ERR, "can not get ".. host .. "rate limit info from database")
            ngr_cache.delete(ngr_cache_prefix.rate_limit .. host)
        end
    end

end

-- ########################### local cache init end #############################



--- ########################### init global cache when starting ngr begin #############################

--- [[
--- 加载网关插件信息到全局内存cache中
---@param store 存储对象
---@param plugin 插件对象
---]]
function _M.load_plugin_data_from_db_2_cache(store, plugin)
    local ok, e
    ok = xpcall(function()
        if not plugin or plugin == "" then
            ngx.log(ngx.ERR, "Params error, the `plugin` is nil")
            return false
        end
        local init_plugin_success, _ = _M.init_enable_of_plugin(plugin, store)
        if not init_plugin_success then
            ngx.log(ngx.ERR, "load data of plugin[" .. plugin .. "] error")
            return false
        end
        return true
    end, function()
        e = debug.traceback()
    end)

    if not ok or e then
        ngx.log(ngx.ERR, "[load plugin's data  from storage to local cache error], plugin:", plugin, " error:", e)
        return false
    end
    ngx.log(ngx.DEBUG, "load data of plugin[" .. plugin .. "]  from storage to local cache success")
    return true
end


--- 加载全局属性配置到全局内存中
-- @param store
--
function _M.load_global_properties_data_from_db_2_cache(store)
    local ok,e
    ok = xpcall(function()
        local flag,properties, err = store:query({
            sql = "select * from  c_global_property where enable = 1",
        })

        if not err and properties and type(properties) == "table" and #properties > 0 then
            for _, v in ipairs(properties) do
                local property_name = v["param_name"]
                local property_value = v["param_value"]
                ngr_cache.set(ngr_cache_prefix.global_property .. property_name,property_value)
            end
        elseif #properties == 0 then
            ngx.log(ngx.INFO, "The global properties configuration data's size is 0.")
        else
            ngx.log(ngx.ERR, "[FATAL ERROR] load global configuration data error.")
            return false
        end
    end,function()
        e = debug.traceback()
    end)

    if not ok or e then
        ngx.log(ngx.ERR, "[FATAL ERROR] load global properties's data error, error:", e)
        return false
    end
    return true
end
--- ########################### init global cache when starting ngr end #############################


function _M.find_plugin_by_name(plugin_name)
    local plugin, _= ngr_cache.get_json(ngr_cache_prefix.plugin  .. plugin_name)
    return plugin
end

-- 根据参数名， 从缓存中获取全局属性配
function _M.get_global_property_by_param_name(param_name)
    local param_value,_ = ngr_cache.get(ngr_cache_prefix.global_property .. param_name)
    return param_value;
end


return _M
