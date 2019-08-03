
---
--- 健康检查
--- Created by yusai.
--- DateTime: 2018/7/4 下午1:47
---

local require = require
local tostring = tostring
local setmetatable = setmetatable
local ngx = ngx
local ngx_log  = ngx.log
local ngx_ERR = ngx.ERR
local ngx_DEBUG = ngx.DEBUG
local ngx_INFO = ngx.INFO
local str_format = string.format
local log_config = require("core.utils.log_config")
local singletons = require("core.framework.singletons")
local ngr_cache = require("core.cache.local.global_cache_util")
local ngr_cache_prefix = require("core.cache.local.global_cache_prefix")
local shard_name = require("core.constants.shard_name")
local shard_name_health_check = shard_name.health_check
local shared = ngx.shared
local router_dao = require("core.dao.api_router_dao")
local resty_lock = require("resty.lock")

-- table holding our api group objects, indexed by healthchecker name
local api_groups = setmetatable({}, { __mode = "k" })


-- healthcheck default configure
-- type:http or tcp, do not work for passive checking mode,just for active checking mode
local healthchecks_defaults = {
    type = "tcp",
    active = {
        timeout = 6,
        concurrency = 10,
        http_path = "/",
        healthy = {
            interval = 0, -- 0 = disabled by default
            http_statuses = { 200, 201, 202, 203, 204, 205, 206, 207, 208, 226,
                              300, 301, 302, 303, 304, 305, 306, 307, 308 },
            successes = 3,
        },
        unhealthy = {
            interval = 0, -- 0 = disabled by default
            http_statuses = {502, 503, 504, 505 },
            tcp_failures = 6,
            timeouts = 6,
            http_failures = 6,
        },
    },

    --  http status not in healthy and not in unhealthy, do not be processed
    passive = {
        healthy = {
            http_statuses = { 200, 201, 202, 203, 204, 205, 206, 207, 208, 226, 300, 301, 302, 303, 304, 305, 306, 307, 308 },
            successes = 1,
        },
        unhealthy = {
            -- 429 Too Many Requests
            http_statuses = {502, 503, 504 },
            tcp_failures = 30,  -- 0 = circuit-breaker disabled by default
            timeouts = 30,      -- 0 = circuit-breaker disabled by default
            http_failures = 30 -- 0 = circuit-breaker disabled by default
        },
    },
}

local unhealthy_expire_time = 3
--healthchecks_defaults.passive.unhealthy.expire_time


local function set_api_group_target_status(api_group, host, port, status)

    if not api_group then
        ngx_log(ngx_ERR,"set_api_group_target_status's input parameter error: api_group is nil.")
        return false
    end
    local targets = api_group.targets
    if not  targets or #targets < 1 then
        ngx_log(ngx_ERR,"set_api_group_target_status's input parameter error: api_group(",router_dao.build_host_group_context(api_group.host,api_group.group_context),")targets is empty")
        return false
    end
    local worker_id = ngx.worker.id()
    ngx_log(ngx_INFO,"worker[",worker_id,"] set_api_group_target_status's parameter:host=",host, ",port=",port, ",status=", status)
    local size = #targets
    for i = 1, size do
        local target = targets[i]
        local target_host = target.host
        local target_port = target.port
        ngx_log(ngx_DEBUG,"[healthchecks] set_api_group_target_status's targets loop input parameter: host=",target_host , ",port=",target_port)
        if host == target_host and tostring(port) == tostring(target_port) then

            local host_group_context = router_dao.build_host_group_context(api_group.host,api_group.group_context)
            ngx_log(ngx_INFO,"[healthchecks] ,","worker[",worker_id,"] Target[ip=",target_host,", port=",target_port,"] of api_group[", host_group_context,"] 's status is set to ", status)
            if target.health and target.health == status then
                return false
            end

            local lock = resty_lock:new(shard_name.lock)
            local lock_key = "updating_target_health_status_" .. host .. "_" .. port .. "_locking"
            local elapsed, err = lock:lock(lock_key)
            if not elapsed then
                ngx_log(ngx_ERR,str_format(log_config.sys_error_format,log_config.ERROR,"failed to acquire the lock: "..err))
                return false
            end

            target.health = status
            -- 更新缓存
            local success, err, _ = ngr_cache.set_json(ngr_cache_prefix.api_group .. host_group_context , api_group)
            if err then
                ngx_log(ngx_INFO,"***[healthchecks] Target[ip=",target_host,", port=",target_port,"] of api_group[", host_group_context,"] 's status is set to ", status," by health checking program failed,error:", err)
                return false
            end
            -- 更新history_api_groups
            local history_groups = ngr_cache.get_json(ngr_cache_prefix.old_api_group_all)
            if history_groups then
                history_groups[host_group_context] = api_group
                ngr_cache.set_json(ngr_cache_prefix.old_api_group_all, history_groups)
            end

            local ok, err = lock:unlock()
            if not ok then
                ngx_log(ngx_ERR,str_format(log_config.sys_error_format,log_config.ERROR,"failed to  release the lock: "..err))
                return false
            end
            return true
        end
    end
    ngx_log(ngx_INFO,"[healthchecks] ,","worker[",worker_id,"] set_api_group_target_status's  parameter error: host and port is incorrect.")
    return false
end

---
--- 对非健康节点保持熔断开启状态
-- open circuit break for unhealthy target
-- @param ip
-- @param port
local function keep_target_circuit_break_open_status(group_id,ip,port)
    local key = "circuit_break_target:"..group_id..":".. ip .. ":" ..port
    local value, flags = shared[shard_name_health_check]:get(key)
    if value then
        return
    end
    local success, err, forcible  = shared[shard_name_health_check]:set(key, true, unhealthy_expire_time)
    if  err then
        ngx_log(ngx_ERR,"[healthchecks] keep target circuit break status to open error :", err)
    else
        ngx_log(ngx_INFO,"[healthchecks] keep target circuit break status to open successfully:", ip , ":",port)
    end
end

---
--- 是否需要对非健康节点尝试关闭熔断状态（即判定是否为半开状态)
-- is unhealthy target's status half close or not
-- @param ip
-- @param port
local function is_half_close_circuit_break_target(group_id,ip,port)
    local key = "circuit_break_target:"..group_id..":".. ip .. ":" ..port
    local value, flags = shared[shard_name_health_check] : get(key)
    if value then
        return false
    else
        return true
    end
end

--
-- @param host_group_context = host .. group_context
local function get_healthchecker(host_group_context)
    return singletons.healthcheckers[host_group_context]
end


local function add_healthchecker(api_group,healthchecker)
    local host_group_context = router_dao.build_host_group_context(api_group.host,api_group.group_context)
    local hc_name = healthchecker:get_name()
    local worker_id = ngx.worker.id()
    ngx_log(ngx_INFO,"[healthchecks] Added a new healthchecker on worker[id=",worker_id,"] for api group: ", host_group_context)
    singletons.healthcheckers[host_group_context] = healthchecker
    api_groups[hc_name] = api_group
end

--
-- @param host_group_context = host .. group_context
local function remove_healthchecker(host_group_context)
    local worker_id = ngx.worker.id()
    ngx_log(ngx_INFO,"[healthchecks] Removed healthchecker on worker[id=",worker_id,"] for api group: ", host_group_context)
    local healthchecker = get_healthchecker(host_group_context)
    if not healthchecker then
        ngx_log(ngx_ERR,"[healthchecks] Removed healthchecker on worker[id=",worker_id,"] for api group: ", host_group_context , "failed, maybe healthcheck was not exist before.")
        return
    end
    local hc_name = healthchecker:get_name()
    api_groups[hc_name] = nil
    healthchecker:clear()
    singletons.healthcheckers[host_group_context] = nil
end

local function update_healthcheck_api_group(healthchecker,api_group)
    local name = healthchecker: get_name()
    api_groups[name] = api_group
end

-- 操作target
local function populate_healthchecker(api_group,healthchecker )

    local host_group_context = router_dao.build_host_group_context(api_group.host,api_group.group_context)
    local targets = api_group.targets
    local history_targets

    ngx_log(ngx_DEBUG,host_group_context .. "operation_target=========start===== ")
    history_targets = api_group.history_targets

    if not targets then -- 目前targets 为空,全部清除 healthcheck target
        if history_targets then
            for _, tg in ipairs(history_targets) do
                local _,err = healthchecker:remove_target (tg.host, tg.port)
                if err then
                    ngx_log(ngx_ERR,host_group_context .. ":remove_target err:",err)
                end
            end
        end
    else
        -- 新增节点操作
        for _, tg in ipairs(targets) do
            local is_add_target = true
            for _, htg in ipairs(history_targets or {}) do
                if tg.host == htg.host and tg.port == htg.port then
                    is_add_target = false
                    break
                end
            end
            if is_add_target then
                -- 新增加的target
                local ok,err = healthchecker:add_target(tg.host,tg.port)
                if not ok then
                    ngx_log(ngx_ERR,host_group_context .. ":[healthchecks] failed adding target err:",err)
                end
            end
        end

        -- 删除节点操作
        for _, htg in ipairs(history_targets or {}) do
            local is_del_target = true
            for _, tg in ipairs(targets) do
                if htg.host == tg.host and htg.port == tg.port then
                    is_del_target = false
                    break
                end
            end
            -- 删除target
            if is_del_target then
                local _,err = healthchecker:remove_target (htg.host, htg.port)
                if err then
                    ngx_log(ngx_ERR,host_group_context .. ":"..is_del_target.."-remove_target err:",err)
                end
            end
        end
    end
    ngx_log(ngx_DEBUG,host_group_context .. "operation_target=========end===== ")
end

local init_healthchecker
do

    --
    --
    -- register callback function for healthchecker's result
    -- @param healthchecker The healthchecker object
    -- @param api_group The API Group object
    --
    local function attach_healthchecker_to_api_group(healthchecker)
        local hc_callback = function(target, event)
            --  "remove",
            --  "healthy",
            --  "unhealthy",
            --  "mostly_healthy",
            --  "mostly_unhealthy",
            --  "clear",
            local worker_id = ngx.worker.id()
            if not target then
                ngx_log(ngx_INFO,"[healthchecks] callback is executed on worker[id=",worker_id,"],event[",event,"] need not be processed." )
                return
            end
            local ip  = target.ip
            local port = target.port
            ngx_log(ngx_INFO,"[healthchecks] callback is executed on worker[id=",worker_id,"],target: ", ip, ":" ,port,",event:",event)
            local healthchecker_name = healthchecker:get_name()
            if event == healthchecker.events.healthy then
                set_api_group_target_status(api_groups[healthchecker_name], ip, port, true)
            elseif event == healthchecker.events.unhealthy then

                local api_group = api_groups[healthchecker_name]

                if not api_group then
                    return
                end
                local group_id = api_group.id;

                local msg = "[healthchecks] unhealthy [id="..worker_id.."]group_id: "..group_id ..": target: "..ip ..":"..port;
                ngx_log(ngx_ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

                set_api_group_target_status(api_group, ip, port, false)

                keep_target_circuit_break_open_status(group_id,ip, port)

            else
                return
            end
        end

        -- Register event using a weak-reference in worker-events,
        singletons.worker_events.register_weak(hc_callback, healthchecker.EVENT_SOURCE)
    end

    local healthcheck
    init_healthchecker = function(api_group)

        local host_group_context = router_dao.build_host_group_context(api_group.host,api_group.group_context)

        ngx_log(ngx_DEBUG,host_group_context .. "init_healtchecker=========start===== ")
        -- 获取已有 hc
        local healthchecker = get_healthchecker(host_group_context)
        local err
        if not healthchecker then
            if not healthcheck then
                healthcheck = require("resty.healthcheck") -- delayed initialization
            end
            healthchecker,err = healthcheck.new({
                name = "healthcheck:" .. host_group_context,
                shm_name = shard_name_health_check,
                checks = healthchecks_defaults,
            })
            add_healthchecker(api_group, healthchecker)
        end

        if not healthchecker or err then
            ngx_log(ngx_ERR, "[healthchecks] error creating health checker: ", err)
            return
        end

        update_healthcheck_api_group(healthchecker,api_group)

        populate_healthchecker(api_group, healthchecker)

        attach_healthchecker_to_api_group(healthchecker)

        ngx_log(ngx_DEBUG,host_group_context .. "init_healtchecker=========end===== ")
    end

end

return {
    init_healthchecker = init_healthchecker,
    remove_healthchecker = remove_healthchecker,
    get_healthchecker = get_healthchecker,
    keep_target_circuit_break_open_status = keep_target_circuit_break_open_status,
    is_half_close_circuit_break_target = is_half_close_circuit_break_target,
}