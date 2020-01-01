---
--- route_matcher
--- Created by Go Go Easy Team.
--- DateTime: 2018/11/8 下午1:56
---
local str_sub = string.sub
local str_find = string.find
local str_len = string.len
local dao_config = require("core.dao.config")
local ngr_cache = require("core.cache.local.global_cache_util")
local api_router_config = require("plugins.api_router.config")
local _M={}

-- 参数整形
-- 以非"/"开头
-- 以"/"结尾
local function parame_shaping(param)
    local len =str_len(param);
    if len >1 then
        local prefix = str_sub(param,1,1);
        local postfix = str_sub(param,len);
        if prefix == "/" then
            param = str_sub(param,2)
        end
        if postfix ~= "/" then
            param = param .."/"
        end
    end

    return param;
end

local function _match(uri,group_contexts)
    if group_contexts and #group_contexts > 0 then
        for _, group_context in ipairs(group_contexts) do
            local indx = str_find(parame_shaping(uri),parame_shaping(group_context),1,true)
            if indx and indx == 1 then
                return group_context;
            elseif group_context == dao_config.default_group_context then
                return dao_config.default_group_context
            end
        end
    end
    return nil
end

function _M.match(uri,host)
    local group_contexts = ngr_cache.get_json(api_router_config.build_cache_group_context_key(host));
    return _match(uri,group_contexts);
end


return _M;