---
--- Http Client utils package
--- Created by jacobs.
--- DateTime: 2018/5/2 下午6:53
---

local upper = string.upper
local http = require("resty.http")
local Object = require("core.framework.classic")
local Http_Client =Object:extend()

---
--http client constructor
--@parameter timeout socket timeout(ms)
--@parameter max_idle_timeout max idle connection timeout
--@parameter pool_size connection pool' size
--
function Http_Client : new(options)


    Http_Client.super.new(self)
    local httpc = http.new()

    if options and options.max_idle_timeout then
        self.max_idle_timeout = options.max_idle_timeout
    end
    if options and options.pool_size then
        self.pool_size = options.pool_size
    end
    if options and options.timeout then
        self.timeout = options.timeout
        httpc:set_timeout(self.timeout)
    end
    self.httpc = httpc
end


---
-- send http request method, req parameter including uri,method, header,body
--
--
function Http_Client :send(req)
    local err_msg
    if not req then
        err_msg = "request options is nil."
        return nil, err_msg
    end
    local uri = req.uri
    if not uri then
        err_msg = "request url is nil."
        return nil, err_msg
    end
    local method = req.method
    if not method then
        err_msg = "request method is nil."
        return nil, err_msg
    end
    method = upper(method)
    if method ~= "POST" and method ~= "GET" and method ~= "DELETE" and method ~= "PUT" then
        err_msg = "request method " ..  method .. " do not support."
        return nil,err_msg
    end
    local headers = req.headers
    if not headers then
        err_msg = "request headers is nil."
        return nil, err_msg
    end
    local resp, err = self.httpc:request_uri(uri, {
        method = method,
        headers = headers,
        body = req.body
    })
    if not resp then
        err_msg = "http response error: " .. err
        ngx.log(ngx.ERR,err_msg)
        return nil,err_msg
    end
    return resp, err_msg
end

---
-- http client close method
--
--
function Http_Client:close()
    local res,err = self.httpc :set_keepalive(self.max_idle_timeout,self.pool_size)
    if not res then
        ngx.log(ngx.ERR,"http client closed error: ", err)
    end
    -- res == 1 or res == 2
    return res,err
end

return Http_Client
