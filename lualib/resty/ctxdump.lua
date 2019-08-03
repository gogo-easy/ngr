-- Copyright (C) UPYUN, Inc.
-- Copyright (C) Alex Zhang

local tonumber = tonumber
local _M = { _VERSION = "0.03" }
local memo = {}
local FREE_LIST_REF = 0


local function ref_in_table(tb, key)
    if key == nil then
        return -1
    end

    local ref = tb[FREE_LIST_REF]
    if ref and ref ~= FREE_LIST_REF then
        tb[FREE_LIST_REF] = tb[ref]
    else
        ref = #tb + 1
    end

    tb[ref] = key

    return ref
end


function _M.stash_ngx_ctx()
    local ctx_ref = ref_in_table(memo, ngx.ctx)
    return ctx_ref
end


function _M.apply_ngx_ctx(ref)
    ref = tonumber(ref)
    if not ref or ref <= FREE_LIST_REF then
        return nil, "bad ref value"
    end

    local old_ngx_ctx = memo[ref]

    -- dereference
    memo[ref] = memo[FREE_LIST_REF]
    memo[FREE_LIST_REF] = ref

    return old_ngx_ctx
end


return _M
