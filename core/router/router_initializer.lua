---
---
--- Created by Go Go Easy Team.
--- DateTime: 2018/7/4 下午5:18
---

local require = require
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local type = type
local xpcall = xpcall
local debug = debug
local str_len = string.len
local table_insert = table.insert
local table_sort = table.sort
local api_router_dao = require("core.dao.api_router_dao")
local group_target_dao = require("core.dao.group_target_dao")
local gray_divide_dao = require("core.dao.gray_divide_dao")
local ngr_cache = require("core.cache.local.global_cache_util")
local ngr_cache_prefix = require("core.cache.local.global_cache_prefix")
local api_router_config = require("plugins.api_router.config")
local log_config = require("core.utils.log_config")
local dao_config = require("core.dao.config")
local cjson = require("core.utils.json")
local ngx = ngx
local ERR = ngx.ERR
local INFO = ngx.INFO
local ngx_log = ngx.log
local str_format = string.format

local _M = {}

function _M.get_targets(api_group, gray_divide_id,is_need_health_state)
    local result_targets = {}
    local all_targets = api_group.targets or {}


    if not gray_divide_id or tonumber(gray_divide_id) == 0 then
        -- 当gray_divide_id ==0 或者nil的时候，获取group的targets
        for _, target in ipairs(all_targets) do
            if not target.is_only_ab or tonumber(target.is_only_ab) == 0 then
                table_insert(result_targets, target)
            end
        end
    else
        -- 根据gray_divide_id获取ab分流targets
        for _, gray_divide in ipairs(api_group.gray_divides) do
            if tonumber(gray_divide.id) == tonumber(gray_divide_id) then
                result_targets = gray_divide.targets
            end
        end
    end

    -- is_need_health_state==true的时候，返回节点有健康检查信息
    if is_need_health_state ==true then
        if not all_targets or #all_targets == 0 then
            ngx.log(ngx.ERR,'group:', api_group.group_context, ' targets is empty')
            return {}
        end

        for _, target in ipairs(all_targets) do
            for _,result_target in ipairs(result_targets) do
                if target.host == result_target.host and target.port == result_target.port then
                    result_target.health = target.health
                end
            end
        end
    end

    if #result_targets == 0 then
        local msg = "gray_divide_id:" .. gray_divide_id .. " targets is empty;group info is:" .. cjson.encode(api_group);
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))
    end

    ngx.log(ngx.DEBUG,'result_targets are:', cjson.encode(result_targets))

    return result_targets
end

local function deal_targets_weight(targets)
    local wheel_size = 0
    for _, target in ipairs(targets) do
        local weight = tonumber(target.weight) or 1
        target.begin_idx = wheel_size + 1
        wheel_size = wheel_size + weight
        target.end_idx = wheel_size
    end
    return wheel_size
end

local function deal_group_targets_weight(group_info)
    local group_info_targets = _M.get_targets(group_info, 0)
    group_info.wheel_size = deal_targets_weight(group_info_targets)

    for _, gray_divide in ipairs(group_info.gray_divides) do
        local gray_divide_targets = _M.get_targets(group_info,gray_divide.id)
        gray_divide.wheel_size = deal_targets_weight(gray_divide_targets)
    end

end

local function _init_gray_divide_targets(gray_divides, store)

    for _, v in ipairs(gray_divides) do
        local flag, results = group_target_dao.query_target_by_gray_divide_id(v.id, store)
        if flag == true then
            v.targets = results or {}
        end
    end

end

--- initialize group_info's targets information when api group enable load balancing
-- @param group_info
-- @param store
--
local  function _init_group_targets(group_info,store)
    local enable_balancing = group_info.enable_balancing
    if enable_balancing and tonumber(enable_balancing) == 1 then
        local group_id = group_info.id
        local lb_algo = tonumber(group_info.lb_algo)
        local flag,targets = group_target_dao.query_target_by_group_id(group_id,store)

        _init_gray_divide_targets(group_info.gray_divides, store)

        if flag == true then
            group_info.targets = targets
            if lb_algo == 1 then
                deal_group_targets_weight(group_info)
            end
        end
    end
end

local function _init_gray_divides(group_info, store)
    group_info.gray_divide_id = 0

    local flag,results = gray_divide_dao.get_gray_divide_by_group_id(group_info.id, store)
    group_info.gray_divides = results or {}
end

local function init_group_contexts(host_contexts, old_host_contexts)

    for host,group_contexts in pairs(host_contexts) do
        -- 排序
        table_sort(group_contexts,function (firstly,second)
            local firstly_len = (firstly == dao_config.default_group_context and 0 or str_len(firstly))
            local second_len = (second == dao_config.default_group_context and 0 or str_len(second))
            if firstly_len > second_len then
                return true;
            else
                return false;
            end
        end)
        -- 缓存
        local success, err, forcible = ngr_cache.set_json(api_router_config.build_cache_group_context_key(host), group_contexts);

        if group_contexts then
            ngx_log(INFO,"init host group context:",cjson.encode(group_contexts))
        end

        if ( not success or err ) then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"Init group context information error 【".. host .."】 error:" .. err))
        end
    end
    local success, err, forcible = ngr_cache.set_json(api_router_config.api_group_context_old_all_key, host_contexts);
    if ( not success or err ) then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"Init old group context information error:".. err))
    end

    -- 清理
    if old_host_contexts then
        for key, _ in pairs(old_host_contexts) do
            ngr_cache.delete(api_router_config.build_cache_group_context_key(key))
        end
    end

end

-- 构建数据，把group_context 以 host分组
local function build_host_contexts_map(group_info,data,old_data)
    local contents = data[group_info.host]
    if not contents then

        local contents = {}
        table_insert(contents,group_info.group_context)
        data[group_info.host] = contents
    else
        table_insert(contents,group_info.group_context)
        data[group_info.host] = contents
    end

    if old_data then
        old_data[group_info.host] = nil
    end
end

local function init_targets_health(c_targets,o_targets)


    if not c_targets then
        return
    end

    local is_add_tg = true
    if o_targets then
        for _, c_tg in ipairs(c_targets) do
            for _, o_tg in ipairs(o_targets) do
                if c_tg.host == o_tg.host and c_tg.port == o_tg.port then
                    is_add_tg = false
                    c_tg.health = o_tg.health
                    break
                end
            end

            if is_add_tg then
                c_tg.health = true
            end
        end
    else
        for _, c_tg in ipairs(c_targets) do
            c_tg.health = true
        end
    end
end

local function _init_enable_api_groups(store,config)
    local hosts = config.application_conf.hosts;
    ngx.log(ngx.DEBUG,"hosts are:".. cjson.encode(hosts))
    if (not hosts and #hosts < 1) then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"hosts must be configured!"))
        return false
    end
    -- 根据配置文件的hosts，获取api_group
    local api_groups= api_router_dao.query_group_info_by_hosts(hosts,store)
    if not api_groups or #api_groups < 1 then
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,"api_groups init is empty"))
        return false
    end
    ngx.log(ngx.DEBUG,"api_groups are", cjson.encode(api_groups))

    local old_data = ngr_cache.get_json(ngr_cache_prefix.old_api_group_all)
    local new_data ={}
    -- 存储以 host 与group context 分组数据
    local host_contexts = {}
    -- 存储需要移除的healthchecker名称
    local remove_healthchecker_names = {}

    local old_host_contexts = ngr_cache.get_json(api_router_config.api_group_context_old_all_key)
    if api_groups and type(api_groups) == "table" and #api_groups > 0 then
        for _, api_group in ipairs(api_groups) do

            -- 构建host 与group context 分组
            build_host_contexts_map(api_group,host_contexts,old_host_contexts)

            -- add gray divides to api_group.gray_divides
            _init_gray_divides(api_group, store)

            -- added group targets
            local host_group_context = api_router_dao.build_host_group_context(api_group.host,api_group.group_context)
            local enable_balancing = api_group.enable_balancing
            if enable_balancing and tonumber(enable_balancing) == 1 then
                _init_group_targets(api_group, store)
            end

            ngx.log(ngx.DEBUG,"group context [",api_group.group_context,"],api group info in init work:",cjson.encode(api_group))

            -- 缓存本次host_context
            new_data[host_group_context] = api_group

            local history_api_group,flag =ngr_cache.get_json(ngr_cache_prefix.api_group..host_group_context);

            if history_api_group then
                if tonumber(enable_balancing) == 1 then
                    api_group.history_targets = history_api_group.targets
                    init_targets_health(api_group.targets,history_api_group.targets)
                else
                    -- 清理上一次 enable_balancing 为 1 的 healthchecker
                    if tonumber(history_api_group.enable_balancing) == 1 then
                        table_insert(remove_healthchecker_names,host_group_context)
                    end
                end
            else
                if tonumber(enable_balancing) == 1 then
                    -- 初始化health
                    init_targets_health(api_group.targets,nil)
                end
            end

            -- 在old 中剔除history存在的host_context
            if old_data and old_data[host_group_context] then
                old_data[host_group_context] = nil
            end
            ngx.log(ngx.DEBUG,"ngr_cache:", cjson.encode(api_group))
            local success, err, forcible = ngr_cache.set_json(ngr_cache_prefix.api_group .. host_group_context , api_group)
            if err or not success then
                ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"Put api_group[" .. host_group_context .. "] to local cache  error:".. err))
                return false
            end
            ngx.log(ngx.DEBUG, "put api_group[" .. host_group_context .. "] to local cache success,cache key[",ngr_cache_prefix.api_group .. host_group_context,"]")
        end

        -- 缓存group context
        init_group_contexts(host_contexts,old_host_contexts)

    else
        ngx.log(ngx.INFO, "can not find data from storage when initializing api groups.")
    end
    -- 缓存数据
    local success, err, forcible = ngr_cache.set_json(ngr_cache_prefix.old_api_group_all, new_data)
    if err or not success then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"init_enable_of_api_groups error: ".. err))
        return false
    end

    -- 清理数据
    if old_data then
        for host_group_context, api_group in pairs(old_data) do
            ngx.log(ngx.DEBUG, "delete api group in cache host_group_context[" .. host_group_context .. "]")
            local enable_balancing = api_group.enable_balancing
            if enable_balancing and tonumber(enable_balancing)==1 then
                table_insert(remove_healthchecker_names,host_group_context)
            end
            local success, err, forcible = ngr_cache.delete(ngr_cache_prefix.api_group..host_group_context)
        end
    end
    -- 缓存需要移除的hc
    ngr_cache.set_json(ngr_cache_prefix.remove_healthchecker_all,remove_healthchecker_names)

    return true
end

function _M.initialize(store,config)
    local ok, e, result
    ok, result = xpcall(function ()
        return _init_enable_api_groups(store,config)
    end,function()
        e = debug.traceback()
    end
    )

    if not ok or e then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"[load api group's data error], error:".. e))
        return false
    end

    return result
end

return _M