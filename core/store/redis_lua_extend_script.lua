---
--- 功能：redis lua 脚本
--- Created by: Go Go Easy Team.
--- DateTime: 2018/4/23
---

local _M = {}

_M.lget=[[
    local key = KEYS[1]
    local len = tonumber(redis.call('llen', key))
    if len >0 then
        return redis.call('lrange',key,0,len)
    end
    return nil
]]

return _M