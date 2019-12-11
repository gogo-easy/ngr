---
--- Request information extractor:
---  extract variable including：
---     Header K/V
---     Query K/V
---     Post Params K/V
---     Host
---     URI
---     IP
---     Method ....and so on
--- Created by jacobs.
--- DateTime: 2018/4/11 下午3:18
---


local str_find = string.find
local str_sub = string.sub
local str_len = string.len
local str_upper = string.upper
local str_gsub = string.gsub
local require = require
local cjson =require("core.utils.json")
local DEBUG = ngx.DEBUG
local ngx_log = ngx.log
local ERR = ngx.ERR
local ngx_req = ngx.req
local ngx_var = ngx.var
local param_type = require("core.constants.param_type")
local route_matcher = require("core.utils.route_matcher")
local stringy = require("core.utils.stringy")
local dao_config = require("core.dao.config")


local _extractor = {}

local function extract_post_param()
    local headers = ngx_req.get_headers()

    if not headers then
        ngx_log(ERR, "[Extract Variable] headers is null")
        return nil
    end

    local content_type = headers['Content-Type']
    ngx_log(DEBUG, "[Extract Variable] Content-Type:", content_type)

    if not content_type then
        ngx_log(DEBUG, "[Extract Variable] Content-Type is null")
        return nil
    end

    ngx_req.read_body()
    local is_multipart = str_find(content_type, "multipart")
    if is_multipart and is_multipart > 0 then
        local raw_body = ngx_req.get_body_data()
        if not raw_body  then
            ngx_log(ERR, "[Extract multipart request body Variable] failed.")
            return nil
        end
        local multipart = require("core.utils.multipart")
        local multipart_data = multipart(raw_body,content_type)
        return multipart_data:get_all()
    end
    local is_x_www_form_urlencoded = str_find(content_type,"x-www-form-urlencoded",1,true)
    if is_x_www_form_urlencoded and is_x_www_form_urlencoded > 0  then
        local post_params, err = ngx_req.get_post_args()
        if not post_params or err then
            ngx_log(ERR, "[Extract x-www-form-urlencoded body Variable] failed to get post args: ", err)
            return nil
        end
        ngx_log(DEBUG,"[Extract x-www-form-urlencoded body Variable] post args : ", cjson.encode(post_params))
        return post_params
    end
    local is_application_json = str_find(content_type,"application/json",1,true)
    if is_application_json and is_application_json > 0 then
        local  body_data = ngx_req.get_body_data()
        if not body_data  then
            ngx_log(ERR, "[Extract application/json body Variable] failed.")
            return nil
        end
        ngx_log(DEBUG,"[Extract application/json body] post args : ", body_data)
        return cjson.decode(body_data)
    end
    ngx_log(ERR, "[Extract Variable]failed， only support post content-type: x-www-form-urlencoded & application/json.")
    return nil
end

local function get_by_key(tab,key)
    local value
    if not tab then
        return value
    end

    for k, v in pairs(tab) do
        if k == key then
            return v
        else
            if type(v) == "table" then
                value = get_by_key(v,key)
                if value then
                    return value
                end
            end
        end
    end
end

local function replace_slash(uri)
    if not uri or str_len(uri) < 2 then
        return uri;
    end
    local tmp_uri,number = str_gsub(uri,"//","/")
    if number > 0 then
        return replace_slash(tmp_uri)
    else
        return tmp_uri
    end
end
--
--extract path(using this method, the group_context must be starter of uri)
-- return path string exclude group_context
-- 返回的path不带"/"
--
local function extract_path(uri,group_context)
    if ( group_context ==  dao_config.default_group_context ) then
        return uri
    end
    if not stringy.startswith(uri,"/") then
        uri = "/" .. uri
    end

    if not stringy.startswith(group_context,"/") then
        group_context = "/" .. group_context
    end
    if stringy.endswith(group_context,"/") then
        group_context = str_sub(group_context, 1,str_len(group_context) -1)
    end
    local start_idx, end_idx = str_find(uri, group_context, 1, true)
    local path = str_sub(uri, end_idx + 1, str_len(uri))
    if not path then
        return ""
    end
    if str_len(path) > 0 and str_find(path,"/",1,true) ==1  then
        path = str_sub(path, 2, str_len(path))
    end
    return path
end



---
--- extract request uri[http_scheme://host:port/api_group_context/path?query_string]
--- result.full_uri  /api_group_context/path?query_string *
--- result.uri  /api_group_context/path
--- result.query_string  ?之后部分
--- result.req_host host:port  类似：http://localhost:80/xxx --> localhost:80
--- result.api_group_context
--- result.path
---@return result
---
---
function _extractor.extract_req_uri()

    -- 从ctx 获取
    if ngx.ctx.ctx_req_info then
        return ngx.ctx.ctx_req_info;
    end
    -- 提取
    local result = {}
    local full_uri = ngx_var.request_uri or "/"
    local req_host = _extractor.extract_http_host()
    result.req_host = req_host
    if not req_host then
        return result
    end
    result.full_uri = full_uri
    local uri, query_string
    do
        local idx = str_find(full_uri, "?", 2, true)
        if idx then
            uri = str_sub(full_uri, 1, idx - 1)
            local args = ngx_req.get_uri_args()
            if args then
                query_string =ngx.encode_args(args)
            end
        else
            uri = full_uri
        end
    end
    uri = replace_slash(uri)
    result.uri= uri
    result.query_string = query_string
    result.api_group_context = route_matcher.match(uri,req_host)
    if not result.api_group_context then
        return result;
    end
    result.path = extract_path(uri,result.api_group_context)

    ngx_log(DEBUG,"extract_req_uri result:",cjson.encode(result))
    -- 放入ctx
    ngx.ctx.ctx_req_info = result

    return result
end

-- 如果该组group_context参与路由，那么req_info里面的path需要加上group_context
-- req_info.path = req_info.api_group_context .."/" .. req_info.path
-- req_info.api_group_context=""
function _extractor.deal_req_info_for_group_context(api_group_info, req_info)

    if(api_group_info and api_group_info.enable_rewrite and tonumber(api_group_info.enable_rewrite) == 1) then
        if(not stringy.endswith(req_info.rewrite_to,"/")
                and req_info.path and req_info.path ~= "" ) then
            req_info.api_group_context = req_info.rewrite_to .. "/"
        end

        if(req_info.path and req_info.path ~= "") then
            req_info.path = req_info.api_group_context .. req_info.path
        else
            req_info.path = req_info.api_group_context
        end
    end
end

function _extractor.split_full_uri(url)
    ngx_log(DEBUG,"split_full_uri...url["..url.."]")
    if not url then
        return nil
    end

    local result = {}

    local idx_start ,idx_end=  str_find(url,"://",2,true)

    local exclude_scheme_url

    if idx_start and idx_end then
        result.scheme = str_sub(url,1,idx_start-1)
        exclude_scheme_url = str_sub(url,idx_end+1,str_len(url))
    else
        result.scheme = ngx_var.scheme
        exclude_scheme_url = url
    end

    if exclude_scheme_url then
        local idx_h = str_find(exclude_scheme_url,"/",2,true)
        local idx_q = str_find(exclude_scheme_url,"?",2,true)

        if not idx_h and not idx_q then
            result.host = exclude_scheme_url
        else

            if idx_q then
                result.query_string = str_sub(exclude_scheme_url,idx_q+1,str_len(exclude_scheme_url))
                result.host = str_sub(exclude_scheme_url,1,idx_q-1)
            end

            if idx_h then
                result.host = str_sub(exclude_scheme_url,1,idx_h-1)
            end
        end

        local idx_p = str_find(result.host,":",2,true)
        if idx_p then
            result.port = str_sub(result.host,idx_p+1,str_len(result.host))
        end

    end
    ngx_log(DEBUG,"split_full_url result:",cjson.encode(result))
    return result
end

---
---extract http request method
---
function _extractor.extract_method()
    local method = ngx_req.get_method()
    return str_upper(method)
end

---
---extract query string
---
function _extractor.extract_query_param(param_name)
    local query = ngx_req.get_uri_args()
    if not query then
        return nil
    end
    return query[param_name]
end

---
---extract header parameter value by name
---
function _extractor.extract_header_param(param_name)
    local headers = ngx_req.get_headers()
    if not headers then
        return nil
    end
    local result = headers[param_name]
    return result
end

function _extractor.extract_headers()
    local headers, err = ngx.req.get_headers()
    local table_headers = {}

    if err == "truncated" then
        return table_headers;
    end

    for k, v in pairs(headers) do
        table_headers[k] = v;
    end
    ngx_log(DEBUG,'request headers' .. cjson.encode(table_headers))
    return table_headers;
end

---
--- extract post request's body parameter
--- only support body's content type: x-www-form-urlencoded & application/json & multipart/form-data
function _extractor.extract_post_param_all()
    return extract_post_param()
end

---
--- extract post request's body parameter value by name
--- only support body's content type: x-www-form-urlencoded & application/json & multipart/form-data
---
function _extractor.extract_post_param(param_name)
    local method = _extractor.extract_method()
    if method == "get" then
        return nil
    end
    local post_params = extract_post_param()
    if post_params then
       -- return post_params[param_name]
        return get_by_key(post_params,param_name)
    end
    return nil
end

--- extract remote client ip
function _extractor.extract_IP()
    return ngx_var.remote_addr
end

--- extract remote client http_host
function _extractor.extract_http_host()
    local req_host = ngx_var.http_host
    if not req_host then
        return nil
    end
    local scheme = ngx_var.scheme
    local server_port = ngx_var.server_port
    local index = str_find(req_host, ":", 1, true) or 0
    if index > 1 then
        if (scheme == 'http' or scheme == 'HTTP') and server_port == '80' then
            req_host = str_gsub(req_host,":80","")
        elseif (scheme == 'https' or scheme == 'HTTPS') and server_port =='443' then
            req_host = str_gsub(req_host,":443","")
        end
    end
    return req_host
end


--- extract user agent
function _extractor.extract_UA()
    return ngx_var.http_user_agent
end

--- extract htto referer
function _extractor.extract_referer()
    return ngx_var.http_referer
end

---
--
function _extractor.extract_param_by_type_and_name(extracted_param_type,extracted_param_name)
    local actual
    if str_upper(extracted_param_type) == str_upper(param_type.TYPE_IP) then
        actual = _extractor.extract_IP()
    end
    if str_upper(extracted_param_type) == str_upper(param_type.TYPE_URI) then
        actual = _extractor.extract_req_uri().uri
    end
    if str_upper(extracted_param_type) == str_upper(param_type.TYPE_REFERER) then
        actual  = _extractor.extract_referer()
    end
    if str_upper(extracted_param_type) == str_upper(param_type.TYPE_UA) then
        actual = _extractor.extract_UA()
    end
    if str_upper(extracted_param_type) == str_upper(param_type.TYPE_HEADER) then
        actual = _extractor.extract_header_param(extracted_param_name)
    end
    if str_upper(extracted_param_type) == str_upper(param_type.TYPE_HOST) then
        actual = _extractor.extract_http_host()
    end
    if str_upper(extracted_param_type) == str_upper(param_type.TYPE_QUERY_STRING) then
        actual = _extractor.extract_query_param(extracted_param_name)
    end
    if str_upper(extracted_param_type) == str_upper(param_type.TYPE_POST_PARAM) then
        actual = _extractor.extract_post_param(extracted_param_name)
    end
    if str_upper(extracted_param_type) == str_upper(param_type.TYPE_JSON_PARAM) then
        actual = _extractor.extract_post_param(extracted_param_name)
    end
    local param_name =  extracted_param_name or extracted_param_type
    if not actual then
        ngx_log(DEBUG, "request var extract failed,parameter_type[",extracted_param_type,"] parameter_name[", param_name,"]")
        return false,nil
    end
    ngx_log(DEBUG, "request var extracted,parameter_type[",extracted_param_type,"] parameter_name[", param_name,"] value:",actual)
    return true,actual
end

return _extractor