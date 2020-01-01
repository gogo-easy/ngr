---
---
--- Created by Go Go Easy Team.
--- DateTime: 2019/1/8 2:13 PM
---


local shared_name = require("core.constants.shard_name")
local shared = ngx.shared
local cache = shared[shared_name.stat_dashboard]


local _M = {}

_M.DEFAULT_EXPIRE = 172800 -- 2 天，单位 s


function _M.add(key,value)
    return cache:add(key,value)
end

function _M.get(key)
    return cache:get(key)
end

function _M.set(key, value, expired)
    return cache:set(key, value, expired or 0)
end

function _M.incr(key,value,exptime)
    local v = _M.get(key)
    value = tonumber(value)
    if not v then
        cache:set(key,value, exptime or _M.DEFAULT_EXPIRE)
    else
        cache:incr(key,value)
    end
end


return _M;