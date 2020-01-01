---
--- request times counter implemeatation
--- Copyright (c) GoGo Easy Team & Jacobs Lei
--- Author: Jacobs Lei
--- Date: 2018/4/9
--- Time: 下午5:51

local rate_limit_utils = require("core.utils.redis_rate_limit_utils")
local Object = require("core.framework.classic")
local _M = Object:extend()

---
-- Counter constructor
-- @param cache_client cache client which store counter key
--
function _M:new(cache_client)
    self.super.new(self)
    self.cache = cache_client
end


function _M:check_rate_limit(key, limit_count, period)
    return rate_limit_utils.check_rate_limit(self.cache,key, limit_count, period)
end

return _M
