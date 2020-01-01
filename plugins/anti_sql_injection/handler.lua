---
--- waf handler
--- Created by Go Go Easy Team.
--- DateTime: 2018/4/11 上午10:42
---

local base_handler = require("plugins.base_handler")
local base_dao = require("core.dao.base_dao")
local api_router_dao = require("core.dao.api_router_dao")
local ngr_cache = require("core.cache.local.global_cache_util")
local config = require("plugins.anti_sql_injection.config")
local PRIORITY = require("plugins.handler_priority")
local var_plastic = require("core.req.req_var_plastic")
local var_extractor = require("core.req.req_var_extractor")
local log_config = require("core.utils.log_config")
local stringy = require("core.utils.stringy")
local param_type = require("core.constants.param_type")
local plugin_name = config.plugin_name
local ngx = ngx
local ngx_log = ngx.log
local ERR = ngx.ERR
local str_format = string.format
local str_upper = string.upper


local asi_handler = base_handler:extend()

asi_handler.PRIORITY = PRIORITY.anti_sql_injection

local function comparePath(asiPath,path,uri)
    if not path then
        path = "/"
    end
    if not asiPath then
        asiPath = "/"
    end

    if not stringy.startswith(asiPath,"/") then
        asiPath = "/"..asiPath
    end

    if not stringy.startswith(path,"/") then
        path = "/"..path
    end

    if not stringy.startswith(uri,"/") then
        uri = "/"..uri
    end

    if asiPath == path or asiPath == uri then
        return true
    end
    return false
end

local function param_plastic(anti_sql_injections,req_info)
    for _ , asi in ipairs(anti_sql_injections) do
        -- asi.path == req_info.uri 表示支持group_context 为 -default-的情况
        if comparePath(asi.path,req_info.path,req_info.uri) then
            local database_type = asi.database_type
            local property_list = asi.property_list
            for _, obj in pairs(property_list or {}) do
                var_plastic.plastic_req_param_by_type_and_name(obj.property_type,obj.property_name,database_type)

                -- 因为在调用 req_var_extractor.extract_req_uri 时把结果缓存了， 经过SQL防控器时，需要把
                -- 处理过后的query_string 替换
                if str_upper(obj.property_type) == str_upper(param_type.TYPE_QUERY_STRING) then
                    local args = ngx.req.get_uri_args()
                    if args then
                        req_info.query_string = ngx.encode_args(args)
                        ngx.ctx.ctx_req_info = req_info
                    end
                end
            end
        end
    end
end


function asi_handler:new(app_context)
    asi_handler.super.new(self, plugin_name)
    self.app_context = app_context
end



function asi_handler:access()
    ngx.log(ngx.DEBUG,"in anti sql injection ======= start")

    local req_info = var_extractor.extract_req_uri()

    local api_group_info = api_router_dao.get_api_group_by_group_context(req_info.req_host, req_info.api_group_context)
    if not api_group_info then
        ngx.log(ngx.DEBUG,"【anti_sql_injection】api group info is null")
        return
    end

    local append_key = config.build_cache_asi_host_and_group_context_key(req_info.req_host,api_group_info.group_context)
    local anti_sql_injections = ngr_cache.get_json(config.build_cache_anti_sql_injection_key(append_key))
    local json = require("cjson")
    if anti_sql_injections then
        local ok, e
        ok = xpcall(function ()
            param_plastic(anti_sql_injections,req_info)
        end, function()
            e = debug.traceback()
        end)
        if not ok or e then
            local msg = "anti sql injection plastic error:" .. e;
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,msg))
        end
    end
    ngx.log(ngx.DEBUG,"in anti sql injection ======= end")
end

function asi_handler: init_worker_timer()
    local hosts = self.app_context.config.application_conf.hosts

    if not hosts and #hosts < 1 then
        local msg = "load  plugin[" .. plugin_name .. "]  hosts must be configured!.";
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,msg))
        return
    end

    base_dao.init_anti_sql_injection(self.app_context.store,hosts)
end

return asi_handler
