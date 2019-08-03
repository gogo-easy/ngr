---
--- 本地限流
--- Created by yusai.
--- DateTime: 2019/1/7 4:57 PM
---

local ngx  = ngx
local ngx_log = ngx.log
local ERR = ngx.ERR
local str_format = string.format
local log_config = require("core.utils.log_config")
local resty_lock = require("resty.lock")
local shard_name = require("core.constants.shard_name")
local counter_cache_util = require("core.cache.local.counter_cache_util")
local Object = require("core.framework.classic")
local _M = Object:extend()


---
-- Counter constructor
-- @param cache_client cache client which store counter key
--
function _M:new(cache_client)
    self.super.new(self)
end

function _M:check_rate_limit(key, limit_count, period)
    ngx.log(ngx.INFO, 'check_rate_limit params:', key, limit_count, period)
    local lock = resty_lock:new(shard_name.lock,{exptime = 5,timeout = 2})

    -- 1、加锁
    local lock_flag = true
    xpcall(function ()
        local elapsed, lock_err = lock:lock(key)
        if not elapsed then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,key .."failed to acquire the lock: "..lock_err))
            lock_flag = false
        end
    end,function(err)
        ngx.log(ngx.ERR, "check_rate_limit lock:unlock  error: ", debug.traceback(err))
        lock_flag = false
    end)

    if not lock_flag then -- 加锁失败，直接返回true
        return true
    end

    -- 2、 限流计数
    local ok,flag = true
    ok = xpcall(function ()
        local current_stat = counter_cache_util.get(key) or 0
        if current_stat >= limit_count then
            local msg = "ngr check_rate_limit do not pass , current_stat =" .. current_stat .. ",limit_count=" .. limit_count
            ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))
            flag = false -- 达到限流阈值
        else
            counter_cache_util.incr(key,1,period)
            flag = true
        end
    end,function(err)
        -- 限流计数异常，返回 true
        ngx.log(ngx.ERR, "check_rate_limit  error: ", debug.traceback(err))
        flag = true
    end)

    -- 3、释放锁
    xpcall(function ()
        lock:unlock()
    end ,function (err)
        ngx.log(ngx.ERR, "check_rate_limit lock:unlock  error: ", debug.traceback(err))
        flag = true
    end)

    return flag
end

return _M
