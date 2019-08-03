local log = ngx.log
local ERR = ngx.ERR
local setmetatable = setmetatable

local _M = {}

local mt = { __index = _M }

local function error_log(...)
    log(ERR, "Redis: ", ...)
end

function _M : close(redis_connector,redis)
    local ok, err = redis_connector:set_keepalive(redis)
    if not ok then
        redis:close()
    end
end

function _M:exec(func)
    local mode = self.mode
    if not mode or  ( mode ~= "standalone" and  mode ~= "sentinel" ) then
        error_log("mode[" .. mode .. "] do not been supported.")
        return nil, ("mode[" .. mode .. "] do not been supported.")
    end
    local rc,red,connect_err
    local redis_connector = require("resty.redis.connector")
    -- mode standalone or sentinel
    if  mode == "standalone" then
        --local red = redis:new()
        --red:set_timeout(self.timeout)
        --local ok, err = red:connect(self.host, self.port)
        --if not ok then
        --    error_log("Cannot connect, host: " .. self.host .. ", port: " .. self.port)
        --    return nil, err
        --end
        --
        --red:select(self.database)
        --
        --local res, err = func(red)
        --if res then
        --    local ok, err = red:set_keepalive(self.max_idle_time, self.pool_size)
        --    if not ok then
        --        red:close()
        --    end
        --end
        --return res, err
        rc =  redis_connector.new({
            connect_timeout = self.connect_timeout,
            read_timeout = self.read_timeout,
            host = self.host,
            port = self.port,
            db = self.database,
            keepalive_poolsize = self.pool_size,
            keepalive_timeout = self.max_idle_time
        })
        red,connect_err = rc:connect()
        if not red then
            local err_msg =  "Cannot connect, host: " .. self.host .. ", port: " .. self.port.. ",cause by error: ".. connect_err
            error_log(err_msg)
            return nil, err_msg
        end
    else
        rc =  redis_connector.new({
            connect_timeout = self.connect_timeout,
            read_timeout = self.read_timeout,
            db = self.database,
            keepalive_poolsize = self.pool_size,
            keepalive_timeout = self.max_idle_time
        })
        red,connect_err = rc:connect_via_sentinel({
            master_name = self.master_name,
            sentinels = self.sentinels,
            role = "master",
            db = self.database
        })
        if not red then
            local err_msg =  "Cannot connect, sentinel master name: " .. (self.master_name or 'nil') .. ", role: " .. (self.role or 'nil').. ",cause by error: ".. connect_err
            error_log(err_msg)
            return nil, err_msg
        end
    end
    -- red is resty-redis instance
    local res, err = func(red)
    if res then
        _M:close(rc,red)
    end
    return res, err
end

function _M:new(opts)
    local config = opts or {}
    local self = {
        -- mode: sentinel or standalone
        mode = config.mode,

        -- common
        connect_timeout = config.connect_timeout or 1000,
        read_timeout = config.read_timeout or 1000,
        -- if nil, do not select
        database = config.database,
        max_idle_time = config.max_idle_time or 6000,
        pool_size = config.pool_size or 30,

        -- standalone mode
        host = config.host,
        port = config.port or 6379,

        -- sentinel mode
        master_name = config.master_name,
        sentinels = config.sentinels

    }
    return setmetatable(self, mt)
end

return _M
