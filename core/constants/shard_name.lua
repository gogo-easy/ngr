---
---  Nginx shard dict  name's constants
--- Created by Jacobs.
--- DateTime: 2018/7/12 下午3:29
---

local _M = {

    -- Shard dict global local cache
    global_cache = "global_config_cache_data",

    -- worker events shard dict
    worker_events = "shard_dict_worker_events",

    -- health check shard dict
    health_check = "shard_dict_healthchecks",

    -- lock shard dict
    lock = "shard_dict_lock",

    -- stat dashboard shard dict
    stat_dashboard = "stat_dashboard_data",

    -- counter dashboard shard dict
    counter_cache = "rate_limit_counter_cache",


}

return  _M
