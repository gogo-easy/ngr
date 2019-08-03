---
--- waf handler
--- Created by yusai.
--- DateTime: 2018/4/11 上午10:42
---

local base_handler = require("plugins.base_handler")
local base_dao = require("core.dao.base_dao")
local ngr_cache = require("core.cache.local.global_cache_util")
local utils = require("core.utils.utils")
local judger = require("core.req.param_judger")
local config = require("plugins.waf.config")
local resp_utils = require("core.resp.resp_utils")
local PRIORITY = require("plugins.handler_priority")
local err_resp_template_utils = require("core.utils.err_resp_template_utils")
local req_var_extractor = require("core.req.req_var_extractor")
local selector_helper = require("core.router.selector_helper")

local error_utils = require("core.utils.error_utils")
local error_type_biz = error_utils.types.ERROR_BIZ.name
local error_type_sys = error_utils.types.ERROR_SYSTEM.name
local log_config = require("core.utils.log_config")

local str_format = string.format
local plugin_name = config.plugin_name

local timer_at = ngx.timer.at
local tonumber = tonumber
local table = table
local xpcall = xpcall
local ngx = ngx
local ERR = ngx.ERR
local ngx_log = ngx.log


local waf_handler = base_handler:extend()

waf_handler.PRIORITY = PRIORITY.waf

local function judge(cond)
    return judger.judge(cond.param_type,cond.param_name,cond.param_value,cond.condition_opt_type)
end

local function build_judge_conditions(judge_conditions,cond,actual_value,is_allowed)
    table.insert(judge_conditions,{
        param_type = cond.param_type,
        condition_opt_type = cond.condition_opt_type,
        param_name = cond.param_name,
        param_value = cond.param_value,
        actual_value = actual_value,
        is_allowed = is_allowed
    })
end

--- add waf hit list
local function add_hit_record(premature, cache_client, waf, conditions)

    if premature then
        return
    end

    local ok, e
    ok = xpcall(function ()
        local current_day = utils.current_day()
        local current_second = utils.current_second()
        local current_day_waf_hit_record_key = config.build_waf_hit_record_key(waf.gateway_id,waf.host_id,current_day)

        local jude_record = {
            current_day = current_day,
            current_second = current_second,
            waf_id = waf.id,
            waf_name = waf.name,
            host = waf.host,
            gateway_code = waf.gateway_code,
            selector_name = waf.selector.selector_name,
            selector_type = waf.selector.selector_type,
            conditions = conditions
        }

        local exist,err = cache_client:exists(current_day_waf_hit_record_key)
        if not exist or exist ==  0 then
            cache_client:add_json(current_day_waf_hit_record_key,jude_record)
            cache_client:expire(current_day_waf_hit_record_key, config.waf_judge_record_expire_days * 24 *3600)
        else
            cache_client :add_json(current_day_waf_hit_record_key,jude_record)
        end
    end, function()
        e = debug.traceback()
    end)
    if not ok or e then
        error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_waf_add_hit_error)
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"added waf judge record error: ".. e))
    end
end

local function set_hit_to_ctx(waf,hit_conditions)
    -- 写入ctx在log阶段执行
    ngx.ctx.waf = waf
    ngx.ctx.hit_conditions = hit_conditions
end

-- 执行拒绝
local function exe_reject(waf,app_context)
    ngx.log(ngx.DEBUG," waf access waf_id["..waf.id.."] rejected end===")
    error_utils.add_error_2_ctx(error_type_biz,config.small_error_types.biz.type_waf_hit)
    resp_utils.say_customized_response_by_template(plugin_name,waf.id,resp_utils.status_codes.HTTP_GATEWAY_REJECTED,app_context.cache_client)
end


local function exe_waf(waf,app_context)

    local flag,hit_conditions = selector_helper.is_intercept_with_intercept_type(waf.selector,waf.is_allowed)

    if flag then
        set_hit_to_ctx(waf,hit_conditions)
        return exe_reject(waf,app_context)
    end
end

local function exe(app_context)
    -- 1、从缓存中获取所有生效防火墙
    local host = req_var_extractor.extract_http_host()
    if not host then
        return
    end
    local wafs = ngr_cache.get_json(config.build_cache_waf_key(host))
    if not wafs or #wafs < 1 then
        ngx.log(ngx.DEBUG," not added waf ...")
        return
    end

    -- 2、遍历并执行防火墙
    for _, waf in ipairs(wafs) do

        ngx.log(ngx.DEBUG," waf access waf_id["..waf.id.."] start===")

        -- 3、获取配置了条件的防火墙
        if waf and waf.selector and tonumber(waf.enable) == 1 then
            -- 执行防火墙
            exe_waf(waf,app_context)
        else
            ngx.log(ngx.DEBUG," waf access waf_id["..waf.id.."] unexecuted ===")
        end
        ngx.log(ngx.DEBUG," waf access waf_id["..waf.id.."] end===")
    end
end

function waf_handler:new(app_context)
    waf_handler.super.new(self, plugin_name)
    self.app_context = app_context
end

function waf_handler:access()
    waf_handler.super.access(self)
    ngx.log(ngx.DEBUG,"in waf access start ============")
    local ok,e
    ok = xpcall(function ()
        exe(self.app_context)
    end,function ()
        e = debug.traceback()
    end)

    if e then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"waf access error...err:".. e))
        error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_waf_exe_error)
    end
    ngx.log(ngx.DEBUG,"in waf access end ============")
end

function waf_handler:log()
    waf_handler.super.log(self)
    ngx.log(ngx.DEBUG,"in waf log start ============")

    local waf = ngx.ctx.waf
    local hit_conditions = ngx.ctx.hit_conditions
    local cache_client = self.app_context.cache_client

    if waf and hit_conditions and #hit_conditions >0 then
        local ok, err = timer_at(0, add_hit_record,cache_client,waf,hit_conditions)
        if not ok then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"waf add_judge_record error: ".. err))
        end
    end

    ngx.log(ngx.DEBUG,"in waf log end ============")
end

function waf_handler: init_worker_timer()
    local hosts = self.app_context.config.application_conf.hosts

    if not hosts and #hosts < 1 then
        ngx.log(ngx.ERR, "load  plugin[" .. plugin_name .. "]  hosts must be configured!.")
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"load  plugin[" .. plugin_name .. "]  hosts must be configured!."))
        return
    end

    base_dao.init_waf(self.app_context.store,hosts)
end

function waf_handler:init_worker_ext_timer()
    ngx.log(ngx.DEBUG,"in waf init_worker_ext_timer  ============")
    err_resp_template_utils.init_2_redis(plugin_name,self.app_context.store,self.app_context.cache_client)
end

return waf_handler
