### GROUP-RATE-LIMIT 

API组限流器插件： 基于后端不同服务组进行限流，后端组可以自身服务容量合理设置亦在保护自己系统的流量限制值

API组限流配置存在GROUP_RATE_LIMIT CONF表中：
- RATE_LIMIT_COUNT 限流计数值
- RATE_LIMIT_PERIOD 限流计数时周期，枚举值：1s,1m(60s),1h(60*60s),1d(60*60*24s)
