local type = type
local setmetatable = setmetatable
local string_gsub = string.gsub
local auth = require("admin_api.auth")
local admin_server_info = require("admin_api.admin_server_info")
local user_log = require("core.log.user_log")
local lor = require("lor.index")

local function auth_failed(res)
    res:set_header('WWW-Authenticate','Basic realm="Login Required"')
    res:status(401):json({
        success = false,
        msg = "Not Authorized."
    })
end

local _M = {}

function _M:new(config, store,cache_client)
    local instance = {}
    instance.config = config
    instance.store = store
    instance.cache_client = cache_client
    instance.app = lor()

    setmetatable(instance, { __index = self })
    instance:build_app()
    return instance
end

function _M:build_app()
    local config = self.config
    local store = self.store
    local cache_client = self.cache_client
    local app = self.app
    local router = require("admin_api.router")

    -- basic-auth middleware
    app:use(function(req, res, next)

        local path = req.path
        if not path or path == "/" then -- 健康检查，不做basic-auth
            next()
            return
        else
            local authorization = req.headers["Authorization"]
            if type(authorization) == "string" and authorization ~= "" then
                local encoded_credential = auth:get_encoded_credential(authorization)
                local flag = auth:check_password(store,encoded_credential)
                if flag then
                    next()
                    return
                end
            end

            auth_failed(res)
        end
    end)

    -- 设置header
    app:use(function(req, res, next)
        res:set_header('Server',admin_server_info.full_name)
        next()
        return
    end)

    -- routes
    app:use(router(config, store,cache_client)())

    -- 记录日志
    app:use(function(req, res, next)
        local username = ngx.ctx.username
        if username then
            user_log.log_to_db(store,username,req.path,req.body)
        end
        next()
        return
    end)

    -- error handle middleware
    app:erroruse(function(err, req, res, next)
        if req.method ~= "OPTIONS" then
            ngx.log(ngx.ERR, err)
        end

        if req:is_found() ~= true then
            -- AJAX中出现两次请求，OPTIONS请求和GET请求
            -- https://blog.csdn.net/cc1314_/article/details/78272329
            if req.method == 'OPTIONS' or req.method == 'options' then
                return  res:status(200)
            else
                return res:status(404):json({
                    success = false,
                    msg = "404! sorry, not found."
                })
            end
        end
        -- 500 单独设置跨域标示
        res:set_header('Access-Control-Allow-Origin',admin_server_info.Access_Control_Allow_Origin)
        res:set_header('Access-Control-Allow-Methods',admin_server_info.Access_Control_Allow_Methods)
        res:set_header('Access-Control-Allow-Headers',admin_server_info.Access_Control_Allow_Headers)
        return res:status(500):json({
            success = false,
            msg = "500! server error."
        })
    end)
end

function _M:get_app()
    return self.app
end

return _M
