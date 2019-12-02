local user_dao = require("core.dao.admin_user_dao")
local decode_base64 = ngx.decode_base64
local resty_sha256 = require("resty.sha256")
local str = require("resty.string")
local pwd_secret ="e5wkxfu73z2rc3tydn6613mmviicbbpq"

local string_gsub = string.gsub

local _M ={}

local function encode(s)
    local sha256 = resty_sha256:new()
    sha256:update(s)
    local digest = sha256:final()
    return str.to_hex(digest)
end

local function split(str, delimiter)
    local result = {}
    if not str or not delimiter then
        return result
    end
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        if match then
            table.insert(result, match)
        end
    end
    return result
end

local function parseHeader(authorization)
    local data = split(decode_base64(authorization), ":")
    return data[1], data[2]
end

function _M:get_login_username(authorization)
    local username = parseHeader(authorization);
    return username
end

function _M:sha_password(pwd)
    return encode(pwd.."#"..pwd_secret)
end

function _M:check_password(store,authorization)

    local username,password = parseHeader(authorization)
    if not username or not password then
        return false
    end
    -- 把username 放入ngx ctx 中，在记录操作日志时使用
    ngx.ctx.username = username
    local sha_password = encode(password.."#"..pwd_secret)
    ngx.log(ngx.INFO,"sha_password===:",sha_password)
    local user = user_dao.load_user_by_user_pwd(store,username,sha_password)
    if user and #user>0 then
        return true,user.is_admin
    else
        return false
    end
end

function _M:get_encoded_credential(origin)
    local result = string_gsub(origin, "^ *[B|b]asic *", "")
    result = string_gsub(result, "( *)$", "")
    return result
end

return _M