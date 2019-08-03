### GLOBAL-RATE-LIMIT 

全局访问速率限制是指限制访问API Gateway的请求速率，用于保护API Gateway系统本身以及后端路由的服务。

全局限流配置存在全局配置字典中：
- GLOBAL_RATE_LIMIT_COUNT 全局限流计数值
- GLOBAL_RATE_LIMIT_PERIOD 全局限流计数时周期，枚举值：1s,1m,1h,1d
