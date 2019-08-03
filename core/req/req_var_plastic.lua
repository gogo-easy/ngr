---
--- Created by yusai.
--- DateTime: 2018/9/12 下午4:21
---

local _plastic = {}

local str_find = string.find
local str_upper = string.upper
local cjson = require("core.utils.json")
local param_type = require("core.constants.param_type")
local ngx_req = ngx.req
local quote_sql_str = ngx.quote_sql_str
local DEBUG = ngx.DEBUG
local ngx_log = ngx.log
local ERR = ngx.ERR


local function injection_translation(value,database_type)
    if not database_type or database_type ~= 'POSTGRESQL' then
        local v = quote_sql_str(value)
        if v then
            return string.sub(v,2,string.len(v)-1)
        end
    else
        local v = ndk.set_var.set_quote_pgsql_str(value)
        return string.sub(v,3,string.len(v)-1);
    end


end

local function param_quote_sql_str(args,param_name,database_type)
    if args then
        for k, v in pairs(args) do
            if type(v) ~= 'table' then
                if k == param_name then
                    args[k] = injection_translation(v,database_type)
                end
            else
                param_quote_sql_str(v,param_name,database_type)
            end
        end
    end
end


function _plastic.plastic_query_string(param_name,database_type)
    local args = ngx_req.get_uri_args()
    param_quote_sql_str(args,param_name,database_type)
    ngx_req.set_uri_args(args)
end

function _plastic.plastic_post_param(param_name,database_type)
    local headers = ngx_req.get_headers()
    if not headers then
        ngx_log(ERR, "【req_var_plastic】headers is null")
        return
    end

    local content_type = headers['Content-Type']

    if not content_type then
        ngx_log(DEBUG, "【req_var_plastic】 Content-Type is null")
        return
    end

    ngx_req.read_body()
    -- 1、content_type:x-www-form-urlencoded
    local is_x_www_form_urlencoded = str_find(content_type,"x-www-form-urlencoded",1,true)
    if is_x_www_form_urlencoded and is_x_www_form_urlencoded > 0  then
        local args,err = ngx_req.get_post_args()
        if not args or err then
            ngx_log(ERR, "【req_var_plastic】 failed to get post args: ", err)
            return
        end
        param_quote_sql_str(args,param_name,database_type)
        ngx_req.set_body_data(ngx.encode_args(args))
    end

    -- 2、content_type:application/json
    local is_application_json = str_find(content_type,"application/json",1,true)
    if is_application_json and is_application_json > 0 then
        local  body_data = ngx_req.get_body_data()
        if not body_data  then
            ngx_log(ERR, "【req_var_plastic】 failed to get post args (application/json).")
            return
        end
        local decode_body_data = cjson.decode(body_data)
        param_quote_sql_str(decode_body_data,param_name,database_type)
        ngx_req.set_body_data(cjson.encode(decode_body_data))
    end

    -- 3、content_type:application/json
    local is_multipart = str_find(content_type, "multipart")
    if is_multipart and is_multipart > 0 then
        local raw_body = ngx_req.get_body_data()
        if not raw_body  then
            ngx_log(ERR, "[Extract multipart request body Variable] failed.")
            return
        end
        local multipart = require("core.utils.multipart")
        local multipart_data = multipart(raw_body,content_type)
        local args = multipart_data:get_all()

        if args then
            for k, v in pairs(args) do
                if type(v) ~= 'table' then
                    if k == param_name then
                        multipart_data:set_simple(param_name,injection_translation(v,database_type))
                    end
                end
            end
        end
        ngx_req.set_body_data(multipart_data:tostring())
    end
end

function _plastic.plastic_header_param(param_name,database_type)
    local headers = ngx_req.get_headers()
    if not headers then
        return
    end
    for key, v in pairs(headers) do
        if key == param_name then
            if type(v) == 'table' then
                for i, _v in ipairs(v) do
                    v[i] = injection_translation(_v,database_type)
                end
            else
                v = injection_translation(v,database_type)
            end
            ngx_req.set_header(param_name,v)
        end
    end
end

function _plastic.plastic_req_param_by_type_and_name(property_type,property_name,database_type)
    if str_upper(property_type) == str_upper(param_type.TYPE_HEADER) then
        _plastic.plastic_header_param(property_name,database_type)
    end
    if str_upper(property_type) == str_upper(param_type.TYPE_QUERY_STRING) then
        _plastic.plastic_query_string(property_name,database_type)
    end
    if str_upper(property_type) == str_upper(param_type.TYPE_POST_PARAM) then
        _plastic.plastic_post_param(property_name,database_type)
    end
    if str_upper(property_type) == str_upper(param_type.TYPE_JSON_PARAM) then
        _plastic.plastic_post_param(property_name,database_type)
    end
end

return _plastic

