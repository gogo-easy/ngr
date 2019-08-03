---
--- 自定义response 头信息
--- Created by yusai.
--- DateTime: 2019/2/28 10:58 AM
---

local _M={}

-- ngr process latency time
_M.PROXY_LATENCY = "X-Ngr-Proxy-Latency"

-- upstream server process latency
_M.UPSTREAM_LATENCY = "X-Ngr-Upstream-Latency"

-- upstream balance lantency time
_M.BALANCER_LATENCY = "X-Ngr-Balancer-Latency"

_M.SERVER = "Server"

_M.VIA = "Via"

_M.SERVER_PROFILE = "X-Ngr-Profile"

_M.PLUGIN_INTERCEPT = "X-Ngr-Intercept"

function _M.add_header_to_ctx(key,value)
    local add_headers = ngx.ctx.add_headers
    if not add_headers then
        add_headers = {}
   end
    add_headers[key] = value
    ngx.ctx.add_headers = add_headers
end

function _M.get_add_headers()
    return ngx.ctx.add_headers
end

return _M;