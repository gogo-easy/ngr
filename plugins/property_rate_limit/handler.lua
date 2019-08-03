---
--- Property rate limit plugin' handler
--- Created by jacobs.
--- DateTime: 2018/4/18 上午11:28
---

local base_handler = require("plugins.base_handler")
local base_dao = require("core.dao.base_dao")
local global_cache = require("core.cache.local.global_cache_util")
local global_cache_prefix = require("core.cache.local.global_cache_prefix")
local judger = require("core.req.param_judger")
local utils = require("core.utils.utils")
local cache_keys = require("core.constants.cache_keys")
local resp = require("core.resp.resp_utils")
local rate_limit_utils = require("core.utils.redis_rate_limit_utils")
local config = require("plugins.property_rate_limit.config")
local PRIORITY = require("plugins.handler_priority")
local error_utils = require("core.utils.error_utils")
local err_resp_template_utils = require("core.utils.err_resp_template_utils")
local req_var_extractor = require("core.req.req_var_extractor")
local log_config = require("core.utils.log_config")

local error_type_biz = error_utils.types.ERROR_BIZ.name
local error_type_sys = error_utils.types.ERROR_SYSTEM.name
local pairs = pairs
local type = type
local tonumber= tonumber
local xpcall = xpcall
local debug = debug
local ngx = ngx
local ERR = ngx.ERR
local ngx_log = ngx.log
local str_format = string.format
local timer_at = ngx.timer.at

local plugin_name = config.plugin_name
local blocked_key_prefix = config.blocked_key_prefix


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

--- added block list to statistics
local function add_blocked_record(premature,cache_client,record)
    if premature then
        return
    end

    local ok,e
    ok = xpcall(function()
        local current_day_blocked_key = config.blocked_recored_key(record.gateway_id,record.host_id,record.day)
        local blocked_record = {
            name = record.name,
            host = record.host,
            gateway_code = record.gateway_code,
            blocked_date = record.day,
            blocked_time = record.time,
            rate_limit_count=record.rate_limit_count,
            rate_limit_period = record.rate_limit_period,
            property_detail = record.property_detail

        }

        local exist,err = cache_client :exists(current_day_blocked_key)
        if not exist or exist ==  0 then
            cache_client : add_json(current_day_blocked_key,blocked_record)
            cache_client : expire(current_day_blocked_key, config.blocked_record_expire_days * 24 *3600)
        else
            cache_client :add_json(current_day_blocked_key,blocked_record)
        end
    end, function()
            e = debug.traceback()
    end)
    if not ok or e then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"added blocked record error: ".. e))

        error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_property_added_blocked_error)
    end

end

--- add limit record list
local function add_limit_record(premature,cache_client,record)
    if premature then
        return
    end

    local ok, e
    ok = xpcall(function ()
        local current_day_limit_record_key = config.build_limit_recored_key(record.gateway_id,record.host_id,record.day)
        local limit_record = {
            name = record.name,
            host = record.host,
            gateway_code = record.gateway_code,
            limit_date = record.day,
            limit_time = record.time,
            rate_limit_count=record.rate_limit_count,
            rate_limit_period = record.rate_limit_period,
            property_detail = record.property_detail
        }

        local exist,err = cache_client :exists(current_day_limit_record_key)
        if not exist or exist ==  0 then
            cache_client : add_json(current_day_limit_record_key,limit_record)
            cache_client : expire(current_day_limit_record_key, config.limit_record_expire_days * 24 *3600)
        else
            cache_client :add_json(current_day_limit_record_key,limit_record)
        end
    end, function()
        e = debug.traceback()
    end)
    if not ok or e then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"added limit record error: ".. e))
        error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_property_added_limit_error)
    end
end

local function  build_hit_record(time,day,item,values)
    local record = {
        gateway_code=item.gateway_code,
        host = item.host,
        gateway_id=item.gateway_id,
        host_id = item.host_id,
        name=item.name,
        rate_limit_count = item.rate_limit_count,
        rate_limit_period = item.rate_limit_period,
        time = time,
        day = day,
        property_detail = values
    }
    return record
end


local function build_property_value(propertys)
    if not propertys then
        return nil
    end
    local values={}
    for _, item in ipairs(propertys) do
        local flag,actual_value = judger.judge_exist(item.property_type,item.property_name)
        if flag and actual_value then
            local property_value = {
                property_type = item.property_type,
                property_name = item.property_name,
                actual_value = actual_value
            }
            table.insert(values,property_value)
        end
    end
    return values
end

local function build_postfix_key(values)
    local key
    for _, item in ipairs(values) do
        local value
        if type(item.actual_value) then
            local json = require("core.utils.json")
             value = json.encode(item.actual_value)
        else
            value = item.actual_value
        end
        if key then
            key = key.."-" .. item.property_type..cache_keys.separator..item.property_name..cache_keys.separator..value
        else
            key = item.property_type..cache_keys.separator..item.property_name..cache_keys.separator..value
        end
    end
    return key
end

local function check_rate_limit(values,period_type,time_key,item,cache_client)
    local limit_count = item.rate_limit_count
    local limit_key_postfix = build_postfix_key(values)..time_key
    local limit_key = item.host_id .."_" .. plugin_name .. limit_key_postfix

    local  pass = rate_limit_utils.check_rate_limit(cache_client,limit_key,limit_count,period_type)
    return pass
end

local function process(item,cache_client)
    local property_detail = item.property_detail
    -- 获取所有特征的具体值
    local values = build_property_value(item.property_detail)

    -- 请求满足所有特征
    if values and #values == #property_detail then
        local current_timetable = utils.current_timetable()
        local limit_period = tonumber(item.rate_limit_period)
        local period_type = get_limit_type(limit_period)
        local time_key =  current_timetable[period_type]
        local is_blocked = item.is_blocked

        --- 是否需要防刷
        if is_blocked and tonumber(is_blocked) == 1 then
            local blocked_key = item.host_id .. "_" .. blocked_key_prefix .. build_postfix_key(values)
            local res,err = cache_client:get(blocked_key)
            -- 还在拒绝请求时期内
            if res and not err then
                error_utils.add_error_2_ctx(error_type_biz,config.small_error_types.biz.type_property_reject)
                resp.say_customized_response_by_template(config.plugin_name,item.id,resp.status_codes.HTTP_GATEWAY_REJECTED,cache_client)
                return
            else

                local pass = check_rate_limit(values,period_type,time_key,item,cache_client)

                if not pass then
                    local block_time = tonumber(item.block_time ) * 60
                    local res,err  = cache_client : setex(blocked_key,is_blocked, block_time)
                    if not res or err then
                        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"Ngr set property blocked [" .. blocked_key .."] error :"..err))
                        error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_property_set_blocked_error)
                    end
                    ngx.ctx.blocked_record = build_hit_record(utils.current_second(),utils.current_day(),item,values)

                    error_utils.add_error_2_ctx(error_type_biz,config.small_error_types.biz.type_property_reject)
                    resp.say_customized_response_by_template(config.plugin_name,item.id,resp.status_codes.HTTP_GATEWAY_REJECTED,cache_client)
                    return
                end
            end

        else

            local pass = check_rate_limit(values,period_type,time_key,item,cache_client)

            if not pass then
                -- 记录
                ngx.ctx.limit_record = build_hit_record(utils.current_second(),utils.current_day(),item,values)

                error_utils.add_error_2_ctx(error_type_biz,config.small_error_types.biz.type_property_reject)
                resp.say_customized_response_by_template(config.plugin_name,item.id,resp.status_codes.HTTP_GATEWAY_REJECTED,cache_client)
                return
            end
        end
    end

end

local function is_execute(effect_s_time,effect_e_time)
    if not effect_s_time or not effect_e_time then
        return false
    end
    local current_day = utils.current_day()

    local start_time = current_day.." "..utils.trim(effect_s_time)
    local end_time = current_day.." "..utils.trim(effect_e_time)
    return utils.check_current_time_interval(start_time,end_time)
end


local property_rate_limit_handler = base_handler:extend()
property_rate_limit_handler.PRIORITY = PRIORITY.property_rate_limit


function property_rate_limit_handler:new(app_context)
    property_rate_limit_handler.super.new(self, plugin_name)
    self.app_context = app_context
    self.store = app_context.store
    self.cache_client = app_context.cache_client
end


function property_rate_limit_handler:access()
    property_rate_limit_handler.super.access(self)
    local host = req_var_extractor.extract_http_host()
    if not host then
        return
    end
    local property_rate_key = config.build_property_rate_limit_key(host)
    local config_data = global_cache.get_json(property_rate_key)
    if not config_data or type(config_data) ~= "table" or #config_data == "0" then
        return
    end

    for _, item in pairs(config_data) do
        -- 特征生效区间判断
        local rate_type = item.rate_type or 0
        local is_exe = true
        if tonumber(rate_type) == 1 then -- 时段
            is_exe = is_execute(item.effect_s_time,item.effect_e_time)
        end
        -- 处理特征
        if is_exe then
            xpcall(function ()
                process(item,self.app_context.cache_client)
            end,function()
                ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"property rate limit access process err:"..debug.traceback()))
            end)
        end
    end
end

function property_rate_limit_handler:log()
    property_rate_limit_handler.super.log(self)
    local limit_record = ngx.ctx.limit_record
    local blocked_record = ngx.ctx.blocked_record

    if limit_record then
        local ok, err = timer_at(0, add_limit_record,self.app_context.cache_client,limit_record)
        if not ok then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"property rate limit handler add_limit_record error: "..err))
        end
    end

    if blocked_record then
        local ok, err = timer_at(0, add_blocked_record,self.app_context.cache_client,blocked_record)
        if not ok then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"property rate limit handler add_blocked_record error: "..err))
        end
    end

end

function property_rate_limit_handler:init_worker_timer()
    local store = self.store
    local hosts = self.app_context.config.application_conf.hosts

    if not hosts and #hosts < 1 then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"load  plugin[" .. plugin_name .. "]  hosts must be configured!."))
        return
    end
    local init_property_rate_limit_success = base_dao.init_property_rate_limit(store,hosts)
    if  not init_property_rate_limit_success then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"load  plugin[" .. plugin_name .. "]  configuration data error."))
    end
end

function property_rate_limit_handler:init_worker_ext_timer()
    err_resp_template_utils.init_2_redis(plugin_name,self.app_context.store,self.app_context.cache_client)
end

return property_rate_limit_handler