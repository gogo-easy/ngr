---
---  Stats metrics configuration
--- Created by Jacobs Lei.
--- DateTime: 2018/5/8 下午9:03
---

local service_context_metrics = {
    {
        name        = "request_count",
        stat_type   = "counter",
        sample_rate = 1,
    },
    {
        name  = "error_count",
        stat_type   = "counter",
        sample_rate = 1,
    },
    {
        name        = "status_count",
        stat_type   = "counter",
        sample_rate = 1,
    },
    --{
    --    name       = "unique_users",
    --    stat_type  = "set"
    --},
    --{
    --    name        = "request_per_user",
    --    stat_type   = "counter",
    --    sample_rate = 1
    --},
    --{
    --    name     = "status_count_per_user",
    --    stat_type  = "counter",
    --    sample_rate = 1
    --},
    --{
    --    name      = "request_size",
    --    stat_type = "timer",
    --},
    --{
    --    name      = "response_size",
    --    stat_type = "timer"
    --},
    {
        name      = "upstream_latency",
        stat_type = "timer",
    },
    {
        name      = "ngr_latency",
        stat_type = "timer",
    },
    {
        name      = "latency",
        stat_type = "timer",
    },

}

local global_metrics = {
    {
        name = "global_request_count",
        stat_type   = "counter",
        sample_rate = 1,
    },
    {
        name      = "global_latency",
        stat_type = "timer",
    },
    {
        name  = "global_error_total",
        stat_type   = "counter",
        sample_rate = 1,
    },
    {
        name  = "global_error_detail",
        stat_type   = "counter",
        sample_rate = 1,
    },
}


return {
    service_context_metrics = service_context_metrics,
    global_metrics = global_metrics,
    plugin_name = "statsd_metrics"
}
