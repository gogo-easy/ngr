---
--- Created by yusai.
--- DateTime: 2019/1/7 3:29 PM
---

local shared_name = require("core.constants.shard_name")
local shared = ngx.shared
local cache = shared[shared_name.counter_cache]


-- default exprired time for different rate limit periods
local EXPIRE_TIME = {
    Second = 5, -- 4s+
    Minute = 70, -- 10s+
    Hour = 3610, -- 10s+
    Day = 86410 -- 10s+
}


local _M = {}


function _M.get(key)
    return cache:get(key)
end

function _M.set(key, value, expired)
    return cache:set(key, value, expired or 0)
end

-- 执行计数
--
function _M.incr(key, value, period)
    local v = _M.get(key)
    if not v then
        _M.set(key, 0, EXPIRE_TIME[period])
    end
    return cache:incr(key, value)
end


return _M;