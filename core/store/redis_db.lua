---
--- Created by Go Go Easy Team.
--- DateTime: 2018/4/3 下午3:31
---
local redis_client = require("utils.redis_client");

local _REDIS ={};

local mt = { __index = _REDIS }

function _REDIS:new(config)
        local red = redis_client:new(config);
        self.red = red;
    return setmetatable(self,mt);
end


--[[
    功能：带过期时间的 set 函数，
    key : 键
    val : 值
    timeout : 过期时间,单位 秒
    res：设置成功，返回 ok
]]
function _REDIS:setex(key,val,timeout)
    return self.red:exec(function (r)
        if timeout then
            return r:setex(key,timeout,val);
        else
            return r:set(key,val);
        end
    end);
end


--[[
    功能：，只有在 key 不存在时设置 key 的值
    key : 键
    val : 值
    res：设置成功，返回 1 。 设置失败，返回 0
]]
function _REDIS:setnx(key,val)
    return self.red:exec(function (r)
        r:setnx(key,val);
    end)
end

--[[
    功能：set 函数，
    key : 键
    val : 值
]]
function _REDIS:set(key,val)
    return self.red:exec(function (r)
        return r:set(key,val);
    end);
end


--[[
    功能：get 函数，
    key : 键
]]
function _REDIS:get(key)
    return self.red:exec(function (r)
        return r:get(key);
    end);
end


--[[
    功能：del 函数，删除存在的key返回 1，否则返回0
    key : 键
]]
function _REDIS:del(key)
    return self.red:exec(function (r)
        return r:del(key);
    end);
end

--[[
    功能：incr 函数，将 key 中储存的数字值增一
    key : 键
]]
function _REDIS:incr(key)
    return self.red:exec(function (r)
        return r:incr(key);
    end);
end

--[[
    功能：incr 函数，将 key 中储存的数字加上指定的增量值
    key : 键
]]
function _REDIS:incr(key,val)
    return self.red:exec(function (r)
        return r:incrby(key,val);
    end);
end

--[[
    功能：exists 函数，检查key是否存在
    key : 键
]]
function _REDIS:exists(key)
    return self.red:exec(function (r)
        return r:exists(key);
    end);
end

-- 测试redis 是否启动，启动返回 pong
function _REDIS:ping()
    return self.red:exec(function (r)
        return r:ping();
    end)
end

return _REDIS;