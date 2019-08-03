---
--- Ngr helper methods to send HTTP responses to clients.
--- Copyright (c) 2016 - 2018 www.mwee.cn & Jacobs Lei 
--- Author: Jacobs Lei
--- Date: 2018/4/9
--- Time: 下午7:18

local server_info = require("core.server_info")
local err_resp_template_utils = require("core.utils.err_resp_template_utils")
local custom_header = require("core.utils.custom_headers")
local server_header = server_info.full_name
local format = string.format
local find = string.find
local ngx = ngx
local ngx_req = ngx.req
local INFO = ngx.INFO
local ERR = ngx.ERR
local ngx_log = ngx.log

local TYPE_PLAIN = "text/plain; charset=utf-8"
local TYPE_JSON = "application/json; charset=utf-8"
local TYPE_XML = "application/xml; charset=utf-8"
local TYPE_HTML = "text/html; charset=utf-8"

local text_template = "error_code:%s,error_message:%s."
local json_template = '{"error_code":"%s",error_message":"%s"}'
local xml_template = '<?xml version="1.0" encoding="UTF-8"?>\n<error>\n<error_code>%s</error_code>\n<error_message>%s</error_message>\n</error>'
local html_template = '<html><head><title>Ngr Error</title></head><body><h1>Ngr Error</h1><p>error_code:%s,error_message:%s.</p></body></html>'

--- Define the most common HTTP status codes for sugar methods.
-- Each of those status will generate a helper method (sugar)
-- attached to this exported module prefixed with `send_`.
-- Final signature of those methods will be `send_<status_code_key>(message, headers)`. See @{send} for more details on those parameters.
-- @field HTTP_OK 200 OK
-- @field HTTP_CREATED 201 Created
-- @field HTTP_NO_CONTENT 204 No Content
-- @field HTTP_BAD_REQUEST 400 Bad Request
-- @field HTTP_UNAUTHORIZED 401 Unauthorized
-- @field HTTP_FORBIDDEN 403 Forbidden
-- @field HTTP_NOT_FOUND 404 Not Found
-- @field HTTP_METHOD_NOT_ALLOWED 405 Method Not Allowed
-- @field HTTP_CONFLICT 409 Conflict
-- @field HTTP_UNSUPPORTED_MEDIA_TYPE 415 Unsupported Media Type
-- @field HTTP_INTERNAL_SERVER_ERROR Internal Server Error
-- @field HTTP_SERVICE_UNAVAILABLE 503 Service Unavailable
-- @field HTTP_GATEWAY_REJECTED 502
-- @usage return responses.send_HTTP_OK()
-- @usage return responses.HTTP_CREATED("Entity created")
-- @usage return responses.HTTP_INTERNAL_SERVER_ERROR()
-- @table status_codes
-- @table errors
local _M = {
    status_codes = {
        HTTP_OK = 200,
        HTTP_CREATED = 201,
        HTTP_NO_CONTENT = 204,
        HTTP_BAD_REQUEST = 400,
        HTTP_UNAUTHORIZED = 401,
        HTTP_FORBIDDEN = 403,
        HTTP_NOT_FOUND = 404,
        HTTP_METHOD_NOT_ALLOWED = 405,
        HTTP_CONFLICT = 409,
        HTTP_UNSUPPORTED_MEDIA_TYPE = 415,
        HTTP_INTERNAL_SERVER_ERROR = 500,
        HTTP_GATEWAY_REJECTED = 502,
        HTTP_SERVICE_UNAVAILABLE = 503,
        HTTP_SERVICE_TIME_OUT = 504
    },
    --网关错误码定义，正常情况不会返回
    errors = {
        -- 2xxxx gateway system error
        GATEWAY_ERROR={CODE=20001,MESSAGE="[Ngr]Internal error"},
        -- 3xxxx gateway rejected
        REQUEST_REJECTED={CODE=30001,MESSAGE="[Ngr]Gateway reject the request"},

        --4xxxx service error
        SERVICE_NOT_FOUND={CODE=40004,MESSAGE="[Ngr]Illegal Request, The host or api group had not been found"},
        SERVICE_UNAUTHORIZED={CODE=40001,MESSAGE="[Ngr]Upstream service's unauthorized"},

        UPSTREAM_ERROR={CODE=50001,MESSAGE="[Ngr]Upstream service is not available"}
    }
}


--- Define some default response bodies for some status codes.
-- Some other status codes will have response bodies that cannot be overriden.
-- Example: 204 MUST NOT have content, but if 404 has no content then "Not found" will be set.
-- @field status_codes.HTTP_UNAUTHORIZED Default: Unauthorized
-- @field status_codes.HTTP_NO_CONTENT Always empty.
-- @field status_codes.HTTP_NOT_FOUND Default: Not Found
-- @field status_codes.HTTP_UNAUTHORIZED Default: Unauthorized
-- @field status_codes.HTTP_INTERNAL_SERVER_ERROR Always "Internal Server Error"
-- @field status_codes.HTTP_METHOD_NOT_ALLOWED Always "Method not allowed"
-- @field status_codes.HTTP_SERVICE_UNAVAILABLE Default: "Service unavailable"
local response_default_content = {
    [_M.status_codes.HTTP_UNAUTHORIZED] = function(content)
        return content or "Unauthorized"
    end,
    [_M.status_codes.HTTP_NO_CONTENT] = function(content)
        return nil
    end,
    [_M.status_codes.HTTP_NOT_FOUND] = function(content)
        return content or "Not found"
    end,
    [_M.status_codes.HTTP_INTERNAL_SERVER_ERROR] = function(content)
        return "An unexpected error occurred"
    end,
    [_M.status_codes.HTTP_METHOD_NOT_ALLOWED] = function(content)
        return "Method not allowed"
    end,
    [_M.status_codes.HTTP_SERVICE_UNAVAILABLE] = function(content)
        return content or "Service unavailable"
    end,
    [_M.status_codes.HTTP_GATEWAY_REJECTED] = function()
        return "An invalid response was received from the upstream server"
    end,
    [_M.status_codes.HTTP_SERVICE_TIME_OUT] = function()
        return "The upstream server is timing out"
    end,
}


---send errors response to client by ngr
-- @parameters status_code HTTP STATUS CODE
-- @parameters error_code error code defined by ngr api gateway
local function say_error_response(error_code, error_msg,status_code)
    local accept_header = ngx_req.get_headers()["accept"]
    local template, message, content_type
    if accept_header == nil then
        accept_header = TYPE_JSON
    end

    if find(accept_header, TYPE_HTML, nil, true) then
        template = html_template
        content_type = TYPE_HTML
    elseif find(accept_header, TYPE_JSON, nil, true) then
        template = json_template
        content_type = TYPE_JSON
    elseif find(accept_header, TYPE_XML, nil, true) then
        template = xml_template
        content_type = TYPE_XML
    else
        template = text_template
        content_type = TYPE_PLAIN
    end
    local message = format(template,error_code,error_msg)
    ngx_log(INFO,"say error response: ", message)
    ngx.header["Server"] = server_header
    ngx.status = status_code
    ngx.say(message)
    ngx.exit(status_code or _M.status_codes.HTTP_OK)
end

--- send gateway error response to client
function _M.say_response_GATEWAY_ERROR()
    say_error_response(_M.errors.GATEWAY_ERROR.CODE,_M.errors.GATEWAY_ERROR.MESSAGE,_M.status_codes.HTTP_INTERNAL_SERVER_ERROR)
end

function _M.say_response_UPSTREAM_ERROR(msg)

    local msg = msg or _M.errors.UPSTREAM_ERROR.MESSAGE

    say_error_response(_M.errors.UPSTREAM_ERROR.CODE,msg,_M.status_codes.HTTP_GATEWAY_REJECTED)
end

--- send request rejected response to client
function _M.say_response_REQUEST_REJECTED()
    say_error_response(_M.errors.REQUEST_REJECTED.CODE,_M.errors.REQUEST_REJECTED.MESSAGE,_M.status_codes.HTTP_GATEWAY_REJECTED)
end

--- send not found service response to client
function _M.say_response_SERVICE_NOT_FOUND()
    say_error_response(_M.errors.SERVICE_NOT_FOUND.CODE,_M.errors.SERVICE_NOT_FOUND.MESSAGE,_M.status_codes.HTTP_NOT_FOUND)
end

function _M.say_response_SERVICE_UNAUTHORIZED(msg)
    say_error_response(_M.errors.SERVICE_UNAUTHORIZED.CODE,msg or _M.errors.SERVICE_UNAUTHORIZED.MESSAGE,_M.status_codes.HTTP_UNAUTHORIZED)
end

-- 响应自定义错误信息
function _M.say_customized_response_by_template(plugin_name, biz_id, status, cache_client)

    if plugin_name == 'waf' then
        custom_header.add_header_to_ctx(custom_header.PLUGIN_INTERCEPT,"w")
    elseif plugin_name == 'gateway' or plugin_name == 'host' then
        custom_header.add_header_to_ctx(custom_header.PLUGIN_INTERCEPT,"grl")
    elseif plugin_name == 'group_rate_limit' then
        custom_header.add_header_to_ctx(custom_header.PLUGIN_INTERCEPT,"gpl")
    elseif plugin_name == 'property_rate_limit' then
        custom_header.add_header_to_ctx(custom_header.PLUGIN_INTERCEPT,"prl")
    end

    ngx_log(INFO,"say_customized_response_by_template plugin_name = ",plugin_name," ,biz_id=",biz_id)

    local err_resp_template = err_resp_template_utils.get_err_resp_template(plugin_name,biz_id,cache_client)
    if not err_resp_template then
        return _M.say_response_REQUEST_REJECTED()
    end

    ngx_log(INFO,"customized ngr response by template,http status[" ..status .. "]")
    ngx.header["Content-Type"] = err_resp_template.content_type
    ngx.header["Server"] = server_header
    if err_resp_template.http_status and err_resp_template.http_status ~="" then
        status = err_resp_template.http_status
    end
    ngx.status = status
    ngx.say(err_resp_template.message)
    ngx.exit(status)
end

function _M.say_upstream_interval_error_response(ngx, default_content_type, default_message, plugin_name, biz_id, cache_client)

    local resp_message = default_message;
    local resp_content_type = default_content_type;

    local err_resp_template = err_resp_template_utils.get_err_resp_template(plugin_name,biz_id,cache_client)
    if err_resp_template then
        resp_content_type = err_resp_template.content_type
        resp_message = err_resp_template.message
        if err_resp_template.http_status and err_resp_template.http_status ~="" then
            ngx.status = err_resp_template.http_status
        end
    end

    ngx_log(ERR,"upstream error ngr response,http status[" ..ngx.status .. "],http content-type[" .. resp_content_type .."],response message["..resp_message.."]")
    ngx.header["Content-Type"] = resp_content_type
    ngx.header["Server"] = server_header
    ngx.say(resp_message)
    ngx.exit(ngx.status)
end

function _M.say_upstream_custom_error(ngx,plugin_name,biz_id,cache_client)
    local err_resp_template = err_resp_template_utils.get_err_resp_template(plugin_name,biz_id,cache_client)
    if err_resp_template then
        local status_code = err_resp_template.http_status
        if not status_code then
            status_code = ngx.status
        end
        ngx_log(ERR,"upstream error ngr response,http status[" ..status_code .. "],http content-type[" .. resp_content_type .."],response message["..resp_message.."]")
        ngx.header["Content-Type"] = err_resp_template.content_type
        ngx.header["Server"] = server_header
        ngx.say(err_resp_template.message)
        ngx.exit(status_code)
    end
end

return _M

