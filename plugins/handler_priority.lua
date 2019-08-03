---
--- plugins' handler execute priority definition
--- Created by jacobs Lei.
--- DateTime: 2018/5/9 上午11:41
---
return {
    global_access_control = 3000,
    global_rate_limit = 2000,
    property_rate_limit = 1999,
    waf = 1998,
    group_rate_limit = 1997,
    anti_sql_injection=1996,
    api_router = 1995,
    stat_dashboard = 1000,
    statsd_metrics = 999
}
