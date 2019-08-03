---
--- 全局控制(校验)
--- Created by yusai.
--- DateTime: 2018/5/16 下午5:58
---

local base_handler = require("plugins.base_handler")
local PRIORITY = require("plugins.handler_priority")
local config = require("plugins.global_access_control.config")
local req_var_extractor = require("core.req.req_var_extractor")
local api_router_dao = require("core.dao.api_router_dao")
local resp_utils = require("core.resp.resp_utils")
local error_utils = require("core.utils.error_utils")
local log_config = require("core.utils.log_config")
local error_type_gac = error_utils.types.ERROR_GAC.name
local ngx = ngx
local ERR = ngx.ERR
local ngx_var = ngx.var
local ngx_log = ngx.log
local str_format = string.format
--
--add global access control error
--
local function add_gac_error(big_type, small_type)
    ngx.ctx.GLOBAL_ACCESS_CONTROL_REJECT = true
    error_utils.add_error_2_ctx(big_type,small_type)
end


local plugin_name = config.name

local global_control_handler = base_handler:extend()

global_control_handler.PRIORITY = PRIORITY.global_access_control

function global_control_handler:new(app_context)
    global_control_handler.super.new(self, plugin_name)
    self.app_context = app_context
end

-- group_context 校验
local function check_group_context(req_info)

    local api_group_info
    if req_info then
        api_group_info = api_router_dao.get_api_group_by_group_context(req_info.req_host,req_info.api_group_context)
    end

    if not api_group_info then
        local msg = " service not found uri[" .. ngx_var.request_uri .. "]，api group context[" .. req_info.api_group_context.."]."
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

        add_gac_error(error_type_gac,config.small_error_types.gac.type_service_not_found)
        resp_utils.say_response_SERVICE_NOT_FOUND()
        return
    else
        -- added service_context to ngx.ctx
        ngx.ctx.service_context = req_info.api_group_context
    end
end

local function check_host(app_config,req_info)
    local hosts = app_config.application_conf.hosts
    if req_info and hosts then
        for _, host in ipairs(hosts or {}) do
            if host == req_info.req_host then
                return
            end
        end
        local msg = "host is not defined uri[" .. (ngx_var.request_uri or "/").."] host[".. (req_info.req_host or "/") .."] api group context[" .. (req_info.api_group_context or "/") .."].";

        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

        add_gac_error(error_type_gac,config.small_error_types.gac.type_host_error)
        resp_utils.say_response_SERVICE_NOT_FOUND()
    end
end

function global_control_handler:access()
    global_control_handler.super.access(self)
    local  req_info = req_var_extractor.extract_req_uri()

    if not req_info or not req_info.req_host or not req_info.api_group_context then
        local msg = "Gateway service can not been found,maybe the host or api group or api had not been defined uri:[" .. (ngx_var.request_uri or "/").."] host[".. (req_info.req_host or "/") .."] api group context[" .. (req_info.api_group_context or "/") .."].";
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))
        add_gac_error(error_type_gac,config.small_error_types.gac.type_host_error)
        resp_utils.say_response_SERVICE_NOT_FOUND()
    else
        -- added service_context to ngx.ctx
        ngx.ctx.service_context = req_info.api_group_context
    end
    -- 1、host 校验
    -- check_host(self.app_context.config,req_info)

    -- 2、group_context 校验
    -- check_group_context(req_info)


end

return global_control_handler
