---
--- Base on  API Group's request rate limiting plugin handler
--- Created by jacobs.
--- DateTime: 2018/4/10 下午3:52
---

local tonumber = tonumber
local utils = require("core.utils.utils")
local req_var_extractor = require("core.req.req_var_extractor")
local base_dao = require("core.dao.base_dao")
local api_router_dao = require("core.dao.api_router_dao")

local base_handler = require("plugins.base_handler")
local plugin_config =  require("plugins.group_rate_limit.config")
local resp = require("core.resp.resp_utils")
local group_rate_limit_dao = require("core.dao.group_rate_limit_dao")
local rate_limit_utils = require("core.utils.local_rate_limit_utils")
local PRIORITY = require("plugins.handler_priority")
local error_utils = require("core.utils.error_utils")
local err_resp_template_utils = require("core.utils.err_resp_template_utils")
local log_config = require("core.utils.log_config")
local ERR = ngx.ERR
local ngx_log = ngx.log
local str_format = string.format
local error_type_biz = error_utils.types.ERROR_BIZ.name

local plugin_name = plugin_config.name

local group_rate_limit_handler = base_handler:extend()
group_rate_limit_handler.PRIORITY = PRIORITY.group_rate_limit

function group_rate_limit_handler:new(app_context)
    group_rate_limit_handler.super.new(self, plugin_name)
    self.app_context = app_context
    self.store = app_context.store
    self.cache_client = app_context.cache_client
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



function group_rate_limit_handler:access()
    group_rate_limit_handler.super.access(self)
    local req_uri_info = req_var_extractor.extract_req_uri()
    if ( not req_uri_info ) then
        ngx.log(ngx.INFO,"Plugin[" ..plugin_config.name .."] 's handler error, request uri information error." )
        return
    end
    local host_group_context = req_uri_info.req_host.. '-'.. req_uri_info.api_group_context
    local api_group = api_router_dao.get_api_group_by_group_context(req_uri_info.req_host,req_uri_info.api_group_context)
    if ( not api_group ) then
        ngx.log(ngx.INFO,"API Host context[" .. host_group_context .."] can not been found.")
        error_utils.add_error_2_ctx(error_type_biz,plugin_config.small_error_types.biz.type_service_not_found)
        resp.say_response_SERVICE_NOT_FOUND()
        return
    end

    local rate_limit_config = group_rate_limit_dao.get_by_group_id_from_cache(self.app_context.store,api_group.id)
    if ( not rate_limit_config ) then
        ngx.log(ngx.DEBUG,"API Host context[" .. host_group_context .."] did not configured rate limiting before.")
        return
    end
    local limit_period = tonumber(rate_limit_config.rate_limit_period)
    local limit_count = tonumber(rate_limit_config.rate_limit_count)
    local period_type = get_limit_type(limit_period)

    -- only work for valid limit type(1 second/minute/hour/day)
    if period_type then
        local current_timetable = utils.current_timetable()
        local time_key =  current_timetable[period_type]
        local key = plugin_name .. host_group_context .. time_key
        local pass  = rate_limit_utils:check_rate_limit(key,limit_count,period_type)
        if not pass then
            ngx.log(ngx.INFO, "Ngr rate limit: ", limit_count, " remaining:", 0," limited uri: ", req_uri_info.full_uri )
            error_utils.add_error_2_ctx(error_type_biz,plugin_config.small_error_types.biz.type_rate_control)
            resp.say_customized_response_by_template(plugin_name,rate_limit_config.id,resp.status_codes.HTTP_GATEWAY_REJECTED,self.app_context.cache_client)
            return
        end
    end
end

function group_rate_limit_handler: init_worker_timer()
    local store =  self.store
    local hosts = self.app_context.config.application_conf.hosts
    local plugin_name = plugin_name

    if not hosts and #hosts < 1 then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"load  plugin[" .. plugin_name .. "]  hosts must be configured!."))
        return
    end

    local init_group_rate_limit_success = base_dao.init_enable_group_rate_limit(store,hosts)
    if not init_group_rate_limit_success then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"load  plugin[" .. plugin_name .. "] 's  group rate limit data error."))
    end
end

function group_rate_limit_handler:init_worker_ext_timer()
    ngx.log(ngx.DEBUG,"in group_rate_limit init_worker_ext_timer  ============")
    err_resp_template_utils.init_2_redis(plugin_name,self.app_context.store,self.app_context.cache_client)
end


return group_rate_limit_handler
