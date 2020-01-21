---
--- Stats metrics' plugin handler
--- Created by Jacobs Lei.
--- DateTime: 2018/5/8 下午9:02
---


local BasePlugin       = require ("plugins.base_handler")
local basic_serializer = require ("core.utils.log_basic_serializer")
local statsd_logger    = require ("plugins.statsd_metrics.statsd_logger")
local config = require("plugins.statsd_metrics.config")
local PRIORITY = require("plugins.handler_priority")
local log_config = require("core.utils.log_config")
local shard_name = require("core.constants.shard_name")
local new_shared = ngx.shared
local ngx_timer_at  = ngx.timer.at
local pairs         = pairs
local ERR = ngx.ERR
local ngx_log = ngx.log
local string_format = string.format

local StatsdHandler = BasePlugin:extend()
StatsdHandler.PRIORITY = PRIORITY.statsd_metrics

--local function format_consumer_id(message)
--    local consumer_type = message.consumer_id_type
--    local consumer_id = message.consumer_id
--    return consumer_type .. "_" .. consumer_id
--end

local metrics = {
    status_count = function (service_context, message, metric_config, logger,req_host)
        local fmt = string_format("S.%s.%s.req.status",req_host, service_context)
        logger:send_statsd(string_format("%s.%s.count", fmt, message.response.status), 1, logger.stat_types.counter, metric_config.sample_rate)
        -- logger:send_statsd(string_format("%s.%s.count", fmt, "total"), 1, logger.stat_types.counter, metric_config.sample_rate)
    end,
    --unique_users = function (service_context, message, metric_config, logger)
    --    local consumer_id = format_consumer_id(message)
    --    if consumer_id then
    --        local stat = string_format("S.%s.user.uniques", service_context)
    --        logger:send_statsd(stat, consumer_id, logger.stat_types.set)
    --    end
    --end,
    --request_per_user = function (service_context, message, metric_config, logger)
    --    local consumer_id  =  format_consumer_id(message)
    --    if consumer_id then
    --        local stat = string_format("S.%s.user.%s.req.count", service_context, consumer_id)
    --        logger:send_statsd(stat, 1, logger.stat_types.counter, metric_config.sample_rate)
    --    end
    --end,
    --status_count_per_user = function (service_context, message, metric_config, logger)
    --    local consumer_id = format_consumer_id(message)
    --    if consumer_id then
    --        local fmt = string_format("S.%s.user.%s.req.status", service_context, consumer_id)
    --        logger:send_statsd(string_format("%s.%s.count", fmt, message.response.status), 1, logger.stat_types.counter, metric_config.sample_rate)
    --        logger:send_statsd(string_format("%s.%s.count", fmt,  "total"), 1, logger.stat_types.counter,metric_config.sample_rate)
    --    end
    --end,
    error_count = function(service_context, message,metric_config,logger,req_host)
        local fmt = string_format("S.%s.%s.error.%s",req_host, service_context,message.error_type)
        logger:send_statsd(string_format("%s.%s", fmt, message.error_detail), 1, logger.stat_types.counter, metric_config.sample_rate)
        --logger:send_statsd(string_format("%s.%s", fmt, "total"), 1, logger.stat_types.counter, metric_config.sample_rate)
    end
}


local function log(premature, conf, message,req_host)
    if premature then
        return
    end
    local stat_name  = {}
    stat_name.global_request_count = "G.req.count"
    stat_name.global_latency="G.latency"

    local stat_value = {}
    stat_value.global_request_count = 1
    stat_value.global_latency = message.latencies.request
    local gac_reject  = message.gac_reject

    local service_context = message.service_context
    if gac_reject == true and not service_context then
        local prefix = "G.error.".. message.error_type .. "."
        stat_name.global_error_detail = prefix .. message.error_detail
        stat_value.global_error_detail = 1
    else
        service_context = service_context or "empty"
        --stat_name.request_size     = "S." .. service_context .. ".req.size"
        --stat_name.response_size    = "S." .. service_context .. ".resp.size"
        stat_name.latency          = "S."..req_host.."." .. service_context .. ".latency"
        stat_name.upstream_latency = "S."..req_host.."." .. service_context .. ".upstream_latency"
        stat_name.ngr_latency   = "S."..req_host.."." .. service_context .. ".ngr_latency"
        stat_name.request_count    = "S."..req_host.."." .. service_context .. ".req.count"
        --
        --stat_value.request_size     = message.request.size
        --stat_value.response_size    = message.response.size
        stat_value.latency          = message.latencies.request
        stat_value.upstream_latency = message.latencies.proxy
        stat_value.ngr_latency   = message.latencies.ngr
        stat_value.request_count    = 1
    end

    local logger, err = statsd_logger:new(conf)
    if err then
        ngx_log(ERR,string_format(log_config.sys_error_format,log_config.ERROR,"failed to create Statsd logger: ".. err))
        return
    end

    if service_context then
        for _, metric_config in pairs(conf.service_context_metrics) do
            local metric_name = metric_config.name
            -- status_count  error_count
            local metric = metrics[metric_name]
            if metric then
                if metric_name ~= "error_count"  then
                    metric(service_context, message, metric_config, logger,req_host)
                else
                    -- only error exists, metric error logger
                    local error_type = message.error_type
                    if error_type then
                        metric(service_context, message, metric_config, logger,req_host)
                    end
                end
            else
                local stat_name = stat_name[metric_config.name]
                local stat_value = stat_value[metric_config.name]
                logger:send_statsd(stat_name, stat_value, logger.stat_types[metric_config.stat_type], metric_config.sample_rate)
            end
        end
    end

    for _, metric_config in pairs(conf.global_metrics) do
        local stat_name = stat_name[metric_config.name]
        local stat_value = stat_value[metric_config.name]
        if stat_name and stat_value then
            logger:send_statsd(stat_name, stat_value, logger.stat_types[metric_config.stat_type], metric_config.sample_rate)
        end
    end
    logger:close_socket()
end


function StatsdHandler:new(app_context)
    StatsdHandler.super.new(self, config.plugin_name)
    self.config = config
    local app_config = app_context.config
    local metric_config = app_config.metrics_conf
    self.config.host = metric_config.host
    self.config.port = metric_config.port
    self.config.prefix = metric_config.prefix
end


function StatsdHandler:log()
    StatsdHandler.super.log(self)
    local conf = self.config
    local message = basic_serializer.serialize(ngx)
    local req_host = ngx.var.http_host
    if  not req_host then
        return
    end
    if req_host then
        req_host = string.gsub(req_host,"%.","_")
    end
    local ok, err = ngx_timer_at(0, log, conf, message,req_host)
    if not ok then
        ngx_log(ERR,string_format(log_config.sys_error_format,log_config.ERROR,"failed to create timer: ".. err))
    end
end

-- shard free space
local function stats_shared_dict_free_space(logger)
    for _, name in pairs(shard_name) do
        local shard = new_shared[name]
        local free_value = shard:free_space()/1024/1024
        local stat_value = string_format("%.2f",free_value)
        logger:send_statsd("nginx_shard."..name..".free_space", stat_value, "g", nil)
    end
end

function StatsdHandler:init_worker_ext_timer()
    local logger, err = statsd_logger:new(self.config)
    stats_shared_dict_free_space(logger)
end

return StatsdHandler
