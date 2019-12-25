---
--- redis + lua request rate limiting utils
--- Copyright (c) GoGo Easy Team & Jacobs Lei
--- Author: Jacobs Lei
--- Date: 2018/4/10
--- Time: 下午12:36

-- default exprired time for different rate limit periods
local EXPIRE_TIME = {
    Second = 60, -- 59s+
    Minute = 180, -- 120s+
    Hour = 3720, -- 120s+
    Day = 86520 -- 120s+
}

local _M = {}

local ngx  = ngx
local ngx_log = ngx.log
local ERR = ngx.ERR
local str_format = string.format
local log_config = require("core.utils.log_config")

--redis eval lua script for rate limiting
_M.redis_lua_script = [[
local key = KEYS[1]
local limit = tonumber(ARGV[1])
local period_expire_time = tonumber(ARGV[2])
local current = tonumber(redis.call('get', key) or "0")
if current + 1 > limit then
   return 0
else
   redis.call("INCRBY", key,"1")
   redis.call("expire", key,period_expire_time)
   return 1
end
]]


function  _M.check_rate_limit(cache_client,key, limit_count, period_type)
    ngx.log(ngx.INFO, 'check_rate_limit params:', cache_client, key, limit_count, period_type)
    local ok,flag
    ok = xpcall(function ()
        local res,err = cache_client:eval(_M.redis_lua_script,1,key,limit_count,EXPIRE_TIME[period_type])
        if err then
            ngx.log(ngx.ERR,"check_rate_limit error",err)
            --TODO statsd, cache err, ignore
            flag = true
        end
        if (res and res == 0 ) then
            flag = false

            local msg = "ngr check_rate_limit do not pass , res=" .. res
            ngx_log(ERR,str_format(log_config.biz_error_format,log_config.INFO,msg))

        else
            flag =  true
        end
    end,function()
        ngx.log(ngx.ERR, "check_rate_limit  error: ", debug.traceback())
        --TODO statsd, cache err, ignore
        flag = true
     end)
    return flag
end

return _M

