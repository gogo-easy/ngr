--[[
 NGR API Gateway APPLICATION 主程序入口
 created by Jacobs Lei @2018-03-26
--]]

local pcall = pcall
local xpcall = xpcall
local require = require
local pairs  = pairs
local tonumber = tonumber
local setmetatable = setmetatable
local debug_traceback = debug.traceback
local singletons = require("core.framework.singletons")
local config_loader = require ("core.utils.config_loader")
local server_info = require("core.server_info")
local utils = require("core.utils.utils")
local base_dao = require("core.dao.base_dao")
local table_insert = table.insert
local table_sort = table.sort
local upstream_error_handlers = require("core.upstream_error_handlers")
local log_config = require("core.utils.log_config")
local ngx = ngx
local ngx_log = ngx.log
local ERR = ngx.ERR
local ipairs = ipairs
local timer_at = ngx.timer.at
local str_format = string.format
local resty_lock = require("resty.lock")
local xpcall_helper = require("core.utils.xpcall_helper")
local router_initializer = require("core.router.router_initializer")
local shard_name = require("core.constants.shard_name")
local custom_headers = require("core.utils.custom_headers")
require("core.framework.globalpatches")()
local healthcheck_helper = require("core.router.healthcheck_helper")
local ngr_cache = require("core.cache.local.global_cache_util")
local api_router_config = require("plugins.api_router.config")
local ngr_cache_prefix = require("core.cache.local.global_cache_prefix")
local router_dao = require("core.dao.api_router_dao")
local healthchecker_helper = require("core.router.healthcheck_helper")
local init_healthchecker = healthchecker_helper.init_healthchecker
local remove_healthchecker = healthchecker_helper.remove_healthchecker
local keep_target_circuit_break_open_status = healthcheck_helper.keep_target_circuit_break_open_status


-- Response Header definition
local HEADERS = {
    -- ngr process latency time
    PROXY_LATENCY = custom_headers.PROXY_LATENCY,
    -- upstream server process latency
    UPSTREAM_LATENCY = custom_headers.UPSTREAM_LATENCY,
    -- upstream balance lantency time
    BALANCER_LATENCY = custom_headers.BALANCER_LATENCY,
    SERVER = custom_headers.SERVER,
    VIA = custom_headers.VIA,
    SERVER_PROFILE = custom_headers.SERVER_PROFILE
}

-- Application main 
local Ngr = {}

---Get current time in ms
local function now()
    return ngx.now() * 1000
end


---[[
---加载plugins插件node
---@config 全局配置ngr.json
---@store 数据库存储对象
--]]
local function load_conf_plugin_handlers(app_context)
    ngx.log(ngx.DEBUG, "Loading ngr.conf's plugins node.")
    local sorted_plugins = {}
    local plugins = app_context.config.plugins

    for _, plugin_name in ipairs(plugins) do
        local loaded, plugin_handler = utils.load_module_if_exists("plugins." .. plugin_name .. ".handler")
        if not loaded then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"The following plugin is not installed or has no handler: " .. plugin_name))
        else
            ngx.log(ngx.DEBUG, "Loading plugin: " .. plugin_name)
            table_insert(sorted_plugins, {
                name = plugin_name,  --plugin name
                handler = plugin_handler(app_context)  --plugin handler module
            })
        end
    end

    table_sort(sorted_plugins, function(a, b)
        local priority_a = a.handler.PRIORITY or 0
        local priority_b = b.handler.PRIORITY or 0
        return priority_a > priority_b
    end)

    return sorted_plugins
end

-- 初始化 hc
local function init_hc()
    -- 初始化hc
   xpcall(function ()
       local host_contexts = ngr_cache.get_json(api_router_config.api_group_context_old_all_key)
        if host_contexts then
            for host, contexts in pairs(host_contexts) do
                if contexts then
                    for _, context in ipairs(contexts) do
                        local host_group_context = router_dao.build_host_group_context(host,context)
                        local api_group,flag =ngr_cache.get_json(ngr_cache_prefix.api_group..host_group_context);
                        if api_group then
                            if api_group.enable_balancing and tonumber(api_group.enable_balancing) == 1 then
                                init_healthchecker(api_group)
                            end
                        end
                    end
                end
            end
        end
    end,function(err)
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"[init healthchecker error], error:".. debug_traceback(err)))
    end
    )
    -- 移除hc
    xpcall(function ()
        local remove_hc_names = ngr_cache.get_json(ngr_cache_prefix.remove_healthchecker_all)
        if remove_hc_names then
            for _, name in pairs(remove_hc_names) do
                remove_healthchecker(name)
            end
        end
    end,function(err)
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"[remove healthchecker error], error:".. debug_traceback(err)))
    end
    )
end

---
--- load base store configuration data into local cache timer,schedule time: 30s
-- @param premature
-- @param store
-- @param config
--
local function load_base_config_data_timer(premature, store, config)
    if premature then
        return
    end
    local worker_id = ngx.worker.id()
    local timer_interval = config.load_conf_interval or 30
    ngx.log(ngx.DEBUG, "Ngr basic configuration data's initialization execute at workers[id=", worker_id,"]")
    local start_time = ngx.now()
    local lock = resty_lock:new(shard_name.lock,{
        exptime = 20,  -- timeout after which lock is released anyway
        timeout = 10,   -- max wait time to acquire lock
    })
    local lock_key = "load_base_config_data_lock"
    local elapsed, err = lock:lock(lock_key)
    if elapsed and not err then
        -- step one, loading api groups information
        local init_routers_success = router_initializer.initialize(store,config)
        if not init_routers_success then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,
                    "[Load core configuration] worker["..worker_id.."] load API Group,targets,AB divides to local cache failed"))
        end
        -- step two, loading global properties information
        local load_global_property_success = base_dao.load_global_properties_data_from_db_2_cache(store)
        if not load_global_property_success then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,
                    "[Load core configuration] worker["..worker_id.."] load global properties to local cache failed"))
        end

        local ok, err = lock:unlock()
        if not ok then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,
                    "[Load core configuration] worker["..worker_id.."]  release load_base_config_data_lock lock: "..err))
        end


        local end_time = ngx.now()
        local latency = end_time - start_time
        if latency > timer_interval then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.WARN,
                    "[Load core configuration] worker["..worker_id.."]  executing load base configuration latency is   ".. latency .." seconds"))
        end
        -- 初始化 健康检查器
        init_hc()
    else
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.WARN,
                "[Load core configuration] worker["..worker_id.."] acquire load_base_config_data_lock failed: "..err))
    end


    local ok, err = timer_at(timer_interval, load_base_config_data_timer, store,config);
    if not ok then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"[Load core configuration] worker["..worker_id.."]  create loading configuration timer failed:".. err))
        return
    end
end


local function load_plugin_config_data_timer(premature, store, config)

    if premature then
        return
    end
    local lock = resty_lock:new(shard_name.lock)
    local lock_key = "load_plugin_config_data_lock"
    local elapsed, err = lock:lock(lock_key)
    if not elapsed then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"failed to acquire the lock(plugin): "..err))
        return
    end

    local worker_id = ngx.worker.id()
    ngx.log(ngx.DEBUG, "Ngr plugin configuration data's initialization execute at workers[id=", worker_id,"]")

    --  loading base lugins information
    for _, plugin in ipairs(singletons.loaded_plugins) do
        local plugin_name = plugin.name
        local load_success = base_dao.load_plugin_data_from_db_2_cache(store, plugin_name)
        if not load_success then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"loadplugin to cache failure,plugin_name="..plugin_name))
        end
        xpcall_helper.execute(function()
            plugin.handler:init_worker_timer()
        end)

    end
    local ok, err = lock:unlock()
    if not ok then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"failed to  release the lock(plugin): "..err))
    end
    -- 只让一个worker定期更新配置
    --   if worker_id ==  0 then
    local timer_interval = config.load_conf_interval or 30
    local ok, err = timer_at(timer_interval, load_plugin_config_data_timer, store,config);
    if not ok then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"Ngr workers failed to create loading configuration timer:".. err))
        return
    end
    --   end
end

---
--load base store configuration data into distributed cache timer,schedule time: 30s
--
--
local function load_ext_config_data_timer(premature, store, config,cache)
    if premature then
        return
    end
    local worker_id = ngx.worker.id()
    local worker_count = ngx.worker.count()
    if worker_count == 1  or (worker_count > 1 and  worker_id == 1 ) then
        local lock = resty_lock:new(shard_name.lock)
        local lock_key = "load_ext_config_data_lock"
        local elapsed, err = lock:lock(lock_key)
        if not elapsed then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"failed to acquire the lock: ".. err))
            return
        end
        for _, plugin in ipairs(singletons.loaded_plugins) do
            xpcall_helper.execute(function()
                plugin.handler:init_worker_ext_timer()
            end)
        end
        local ok, err = lock:unlock()
        if not ok then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"failed to  release the lock: "..err))
        end

        local timer_interval = config.load_ext_conf_interval or 60
        local ok, err = timer_at(timer_interval, load_ext_config_data_timer, store,config,cache);
        if not ok then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"Ngr workers failed to create loading configuration timer:"..err))
            return
        end
    end
end

---
--- execute plugin's handler init worker
---
local function execute_plugin_init_worker()
    for _, plugin in ipairs(singletons.loaded_plugins) do
        local name = plugin.name;
        local plugin_in_store = base_dao.find_plugin_by_name(name)
        if ( plugin_in_store and plugin_in_store.enable == 1 ) then
            ngx.log(ngx.DEBUG, "Ngr worker execute plugin[name=", name,"]'s init_worker method.")
            plugin.handler:init_worker()
        end
    end
end

----
---init worker's timer context
---
local function init_worker_timer(premature, store, config,cache)
    if premature then
        return
    end
    load_base_config_data_timer(premature,store, config)
    load_plugin_config_data_timer(premature,store, config)
    load_ext_config_data_timer(premature,store,config,cache)
    execute_plugin_init_worker()
end


---- NGR  core applicaition  initializing is beginning ---------
--[[application initialize configuration
	such as global configuration,
	database connection,cache connection
--]]
function Ngr.init(global_conf_path)
    ngx.log(ngx.INFO, "Ngr Application is starting loading configuration.")
    local app_context ={}
    local status, err = pcall(function()
    	-- 加载所有全局配置
        app_context.config = config_loader.load(global_conf_path)
        app_context.store = require("core.store.mysql_store_impl")(app_context.config.store_mysql)
        app_context.cache_client = require("core.store.d_cache_client")(app_context.config)
        -- config_service 不执行此段
        if app_context.config.application_conf.service_type == "gateway_service" then
            singletons.loaded_plugins = load_conf_plugin_handlers(app_context)
            singletons.healthcheckers = setmetatable({}, { __mode = "k" })
            app_context.prometheus_metrics =  require("core.metrics.prometheus_utils")
            app_context.prometheus_metrics:init()
        end

        ngx.update_time()
        app_context.config.ngr_start_at = ngx.localtime()
    end)

    if not status or err then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"Ngr Application Startup error: "..err))
        os.exit(1)
    end

    Ngr.data = {
    	config = app_context.config,
        start_time = app_context.config.ngr_start_at,
        profile = app_context.config.profile,
    	store = app_context.store,
        cache_client  = app_context.cache_client,
        prometheus_metrics = app_context.prometheus_metrics,
	}
	return app_context.config,app_context.store,app_context.cache_client, app_context.prometheus_metrics
end


--[[
--initialize nginx worker's configuration
--setting the schedule program
--]]
function Ngr.initWorker()
	-- 仅在 init_worker 阶段调用，初始化随机因子，仅允许调用一次
    math.randomseed()

    -- 初始化 worker events
    local worker_events = require("resty.worker.events")
    local ok, err = worker_events.configure {
        shm = shard_name.worker_events, -- defined by "lua_shared_dict"
        timeout = 6,            -- life time(in seconds) of event data in shm
        interval = 1,           -- poll interval (seconds)

        wait_interval = 0.010,  -- wait before retry fetching event data
        wait_max = 0.5,         -- max wait time before discarding event
    }
    if not ok then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"could not start inter-worker events: "..err))
        return os.exit(1)
    end
    singletons.worker_events  = worker_events

    -- 初始化定时器，清理计数器
    if Ngr.data  then
        local timer_delay = Ngr.data.config.load_conf_delay or 0
        local ok, err = timer_at(timer_delay, init_worker_timer,Ngr.data.store, Ngr.data.config,Ngr.data.cache_client)
        if not ok then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"Ngr workers failed to create loading configuration timer: "..err))
            return os.exit(1)
        end
    end
end


--[[
 访问控制执行阶段执行逻辑： 如路由控制，防火墙控制， 全局限流控制, 基于特征限流控制等
 具体执行逻辑由插件执行
--]]
function Ngr.access()
	ngx.ctx.NGR_ACCESS_START = now()

    for _, plugin in ipairs(singletons.loaded_plugins) do
        local name = plugin.name;
        local plugin_in_store = base_dao.find_plugin_by_name(name)
        if ( plugin_in_store and plugin_in_store.enable == 1 ) then
            plugin.handler:access()
        end
    end
    local now_time = now()
    ngx.ctx.NGR_ACCESS_TIME = now_time - ngx.ctx.NGR_ACCESS_START
    ngx.ctx.NGR_ACCESS_ENDED_AT = now_time
    ngx.ctx.NGR_ACCESS_LATENCY = now_time - ngx.req.start_time() * 1000
    ngx.ctx.ACCESSED = true
end

--[[
 响应头过滤阶段执行逻辑
 具体执行逻辑由插件执行
--]]
function Ngr.header_filter()
	if ngx.ctx.ACCESSED  then
        local now_time = now()
         -- time spent waiting for a response from upstream
        if ngx.ctx.BALANCERED then
            ngx.ctx.NGR_WAITING_TIME = now_time - ngx.ctx.NGR_BALANCER_ENDED_AT
        else
            ngx.ctx.NGR_WAITING_TIME = now_time - ngx.ctx.NGR_ACCESS_ENDED_AT
        end
        ngx.ctx.NGR_HEADER_FILTER_STARTED_AT = now_time

    end

    for _, plugin in ipairs(singletons.loaded_plugins) do
        local name = plugin.name;
        local plugin_in_store = base_dao.find_plugin_by_name(name)
        if ( plugin_in_store and plugin_in_store.enable == 1 ) then
            plugin.handler:header_filter()
        end        
    end

    if ngx.ctx.ACCESSED then
        ngx.header[HEADERS.UPSTREAM_LATENCY] = ngx.ctx.NGR_WAITING_TIME
        if ngx.ctx.BALANCERED then
            ngx.header[HEADERS.PROXY_LATENCY] = ngx.ctx.NGR_ACCESS_LATENCY + ngx.ctx.NGR_BALANCER_LATENCY
            ngx.header[HEADERS.BALANCER_LATENCY] = ngx.ctx.NGR_BALANCER_LATENCY
        else
            ngx.header[HEADERS.PROXY_LATENCY] = ngx.ctx.NGR_ACCESS_LATENCY
        end

    end
    ngx.header[HEADERS.SERVER] = server_info.full_name
    ngx.header[HEADERS.VIA] = server_info.full_name
    ngx.header[HEADERS.SERVER_PROFILE] = Ngr.data.start_time .. "/" .. Ngr.data.profile

    -- 其它头信息
    local add_headers = custom_headers.get_add_headers()
    if add_headers then
        for key, value in pairs(add_headers) do
            ngx.header[key] = value
        end
    end

end

--[[
--响应体过滤控制执行逻辑
  具体执行逻辑由插件执行
]]
function Ngr.body_filter()
    for _, plugin in ipairs(singletons.loaded_plugins) do
        local name = plugin.name;
        local plugin_in_store = base_dao.find_plugin_by_name(name)
        if ( plugin_in_store and plugin_in_store.enable == 1 ) then
            plugin.handler:body_filter()
        end
    end

    if ngx.ctx.ACCESSED then
        ngx.ctx.NGR_RECEIVE_TIME = now() - ngx.ctx.NGR_HEADER_FILTER_STARTED_AT
    end
end
--[[
--日志阶段执行逻辑
--具体执行逻辑由插件执行
--]]
function Ngr.log()
    for _, plugin in ipairs(singletons.loaded_plugins) do
        local name = plugin.name
        local plugin_in_store = base_dao.find_plugin_by_name(name)
        if ( plugin_in_store and plugin_in_store.enable == 1 ) then
            plugin.handler:log()
        end
    end
    local addr = ngx.ctx.balancer_address
    -- If response was produced by an upstream (ie, not by a ngr plugin)
    if ngx.ctx.BALANCERED == true then
        -- Report HTTP status for passive health checks
        if addr and addr.healthchecker and addr.ip then
            ngx.log(ngx.DEBUG, "report upstream http status: ",addr.group_id, addr.ip,addr.port,ngx.status)
            addr.healthchecker: report_http_status(addr.ip, addr.port, ngx.status, "passive")
        end
        -- 半开
        if addr and  addr.half_open then
            keep_target_circuit_break_open_status(addr.group_id,addr.ip,addr.port)
        end
    end
    Ngr.data.prometheus_metrics:log()
end

--[[
-- upstream interval error的处理逻辑
--]]
function Ngr.error_handle()
    return upstream_error_handlers(ngx,Ngr.data.cache_client)
end

--[[
-- upstream balancer phase execute logic:
 ]]
function Ngr.balancer()
    ngx.ctx.NGR_BALANCER_START_AT = now()
    for _, plugin in ipairs(singletons.loaded_plugins) do
        local name = plugin.name
        local plugin_in_store = base_dao.find_plugin_by_name(name)
        if ( plugin_in_store and plugin_in_store.enable == 1 ) then
            plugin.handler:balancer()
        end
    end
    local now_time = now()
    ngx.ctx.NGR_BALANCER_LATENCY = now_time - ngx.ctx.NGR_BALANCER_START_AT
    ngx.ctx.NGR_BALANCER_ENDED_AT = now_time
    ngx.ctx.BALANCERED = true
end

----- NGR core application initializing finished -----------

return Ngr