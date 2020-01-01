---
--- Copyright (c) GoGo Easy Team & Jacobs Lei
--- Author: Jacobs Lei
--- Date: 2018/4/7
--- Time: 上午10:44

local utils = require("core.utils.utils")
local tonumber = tonumber
local global_cache = require("core.cache.local.global_cache_util")
local global_cache_prefix = require("core.cache.local.global_cache_prefix")
local base_handler = require("plugins.base_handler")
local plugin_config = require("plugins.global_rate_limit.config")
local error_utils = require("core.utils.error_utils")
local rate_limit_utils = require("core.utils.local_rate_limit_utils")
local resp_utils = require("core.resp.resp_utils")
local err_resp_template_utils = require("core.utils.err_resp_template_utils")

local error_type_sys = error_utils.types.ERROR_SYSTEM.name
local error_type_biz = error_utils.types.ERROR_BIZ.name
local PRIORITY = require("plugins.handler_priority")
local base_dao = require("core.dao.base_dao")
local req_var_extractor = require("core.req.req_var_extractor")
local log_config = require("core.utils.log_config")
local plugin_name = plugin_config.name
local ERR = ngx.ERR
local ngx_log = ngx.log
local str_format = string.format

local function check_rate_limit_period(rate_limit_period)
    if not rate_limit_period  then
        return nil
    end
    local period = tonumber(rate_limit_period)
    if  not period then
        return nil
    end
    if  period ~= 1 and period ~= 60 and period ~= 3600 and period ~= 86400 then
        return nil
    end
    ngx.log(ngx.DEBUG, "[global_rate_limit] period valid:", period)
    return period
end


local function check_rate_limit_count(rate_limit_value)
    if not rate_limit_value  then
        return nil
    end
    local total = tonumber(rate_limit_value)
    if  not total or total == 0  then
        return nil
    end
    ngx.log(ngx.DEBUG, "[global_rate_limit] total count valid:", total)
    return total
end


local function get_limit_type(period)
    if not period then return nil end
    if period == 1 then
        return "Second"
    elseif period == 60 then
        return "Minute"
    elseif period == 3600 then
        return "Hour"
    elseif period == 86400 then
        return "Day"
    else
        return nil
    end
end

-- 限速处理
local function rate_limit_handler(rate_limit_code,limit_count,limit_period,p_name,biz_id,cache_client)
    limit_period = check_rate_limit_period(limit_period)
    limit_count = check_rate_limit_count(limit_count)
    if  not limit_period or not limit_count then
        ngx_log(ERR,str_format(log_config.sys_error_format,"[global_rate_limit] period or total count configuration error."))
        error_utils.add_error_2_ctx(error_type_sys,plugin_config.small_error_types.sys.type_plugin_conf)
        return
    end
    local limit_type = get_limit_type(limit_period)
    if not limit_type then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"[global_rate_limit] period configuration error,only support 1 second/minute/hour/day"))
        error_utils.add_error_2_ctx(error_type_sys,plugin_config.small_error_types.sys.type_plugin_conf)
        return
    end
    if limit_type then
        local current_timetable = utils.current_timetable()
        local rate_limit_key = plugin_name .. rate_limit_code .. current_timetable[limit_type]
        local pass  = rate_limit_utils:check_rate_limit(rate_limit_key,limit_count,limit_type)
        if not pass then

            local msg = "ngr " .. rate_limit_code .." rate limit: "..  limit_count .. " remaining:"..  0;
            ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

            error_utils.add_error_2_ctx(error_type_biz,plugin_config.small_error_types.biz.type_rate_control)
            resp_utils.say_customized_response_by_template(p_name,biz_id,resp_utils.status_codes.HTTP_GATEWAY_REJECTED,cache_client)
            return
        end
    end
end


local global_rate_limit_handler = base_handler:extend()
global_rate_limit_handler.PRIORITY = PRIORITY.global_rate_limit

function global_rate_limit_handler:new(app_context)
    global_rate_limit_handler.super.new(self, plugin_name)
    self.app_context = app_context
end

local function execute(cache_client)
    local http_host = req_var_extractor.extract_http_host()
    if not http_host then
        return
    end
    local rate_limit_table = global_cache.get_json(global_cache_prefix.rate_limit .. http_host)

    if not rate_limit_table then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"can not get  [" .. http_host .."] rate limit info from cache "))
        error_utils.add_error_2_ctx(error_type_sys,plugin_config.small_error_types.sys.type_plugin_conf)
        return
    end
    local gateway_limit_period = rate_limit_table.gateway_limit_period;
    -- 网关限速
    rate_limit_handler("gateway_" .. rate_limit_table.gateway_code, rate_limit_table.gateway_limit_count, gateway_limit_period,
            "gateway",rate_limit_table.gateway_id,cache_client)

    local host_limit_period = rate_limit_table.host_limit_period;
    -- 主机限速
    rate_limit_handler("host_" .. http_host, rate_limit_table.host_limit_count, host_limit_period,
            "host",rate_limit_table.host_id,cache_client)
end

function global_rate_limit_handler:access()
    global_rate_limit_handler.super.access(self)
    local cache_client = self.app_context.cache_client
    xpcall(function ()
            execute(cache_client)
        end,
    function (err)
        ngx.log(ngx.ERR, "global_rate_limit_handler access  error: ", debug.traceback(err))
    end)
end

function global_rate_limit_handler:init_worker_ext_timer()
    global_rate_limit_handler.super.init_worker_ext_timer(self)

    local app_context = self.app_context
    base_dao.init_rate_limit(app_context.store,app_context.config.application_conf.hosts)

    -- init gateway error massage
    err_resp_template_utils.init_2_redis("gateway",self.app_context.store,self.app_context.cache_client)
    -- init host error massage
    err_resp_template_utils.init_2_redis("host",self.app_context.store,self.app_context.cache_client)
end

return global_rate_limit_handler
