--[[
    Nginx Shard DiCT Cache operation utils
--]]

local cjson = require("core.utils.json")
local shared_name = require("core.constants.shard_name")
local shared = ngx.shared
local cache_data = shared[shared_name.global_cache]

local _Cache = {}

function _Cache._get(key)
    return cache_data:get(key)
end

function _Cache.get_json(key)
    local value, flags = _Cache._get(key)
    if value then
        value = cjson.decode(value)
    end
    return value, flags
end

function _Cache.get(key)
    return _Cache._get(key)
end

function _Cache._set(key, value)
    -- success, err, forcible
    return cache_data:set(key, value)
end

function _Cache._add(key,value)
    -- success, err, forcible
    return cache_data:add(key,value)
end


function _Cache.set_json(key, value)
    if value then
        value = cjson.encode(value)
    end
    return _Cache._set(key, value)
end

function _Cache.set(key, value)
    -- success, err, forcible
    return _Cache._set(key, value)
end

function _Cache.add(key,value)
    -- success, err, forcible
    return _Cache._add(key,value)
end

function _Cache.add_json(key,value )
    if value then
        value = cjson.encode(value)
    end
    return _Cache._add(key,value)
end

function _Cache.incr(key, value)
    return cache_data:incr(key, value)
end

function _Cache.delete(key)
    return cache_data:delete(key)
end


function _Cache.delete_all()
    cache_data:flush_all()
    cache_data:flush_expired()
end

return _Cache
