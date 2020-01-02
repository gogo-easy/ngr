local require = require
local base_handler = require("plugins.base_handler")
local req_var_extractor = require("core.req.req_var_extractor")
local base_dao = require("core.dao.base_dao")
local api_router_dao = require("core.dao.api_router_dao")
local resp_utils = require("core.resp.resp_utils")
local config = require("plugins.api_router.config")
local json = require("core.utils.json")
local utils = require("core.utils.utils")
local PRIORITY = require("plugins.handler_priority")
local err_resp_template_utils = require("core.utils.err_resp_template_utils")
local error_utils = require("core.utils.error_utils")
local error_type_biz = error_utils.types.ERROR_BIZ.name
local error_type_sys = error_utils.types.ERROR_SYSTEM.name
local error_type_upstream = error_utils.types.ERROR_UPSTREAM.name

local healthcheck_helper = require("core.router.healthcheck_helper")
local router_initializer = require("core.router.router_initializer")
local get_healthchecker = healthcheck_helper.get_healthchecker
local keep_target_circuit_break_open_status = healthcheck_helper.keep_target_circuit_break_open_status

local selector_helper = require("core.router.selector_helper")
local log_config = require("core.utils.log_config")
local stringy = require("core.utils.stringy")
local str_len = string.len
local str_sub = string.sub
local tonumber = tonumber
local tostring = tostring
local ngx  = ngx
local ngx_log = ngx.log
local ERR = ngx.ERR
local ngx_DEBUG = ngx.DEBUG
local table = table
local TOKEN_VALIDATION = 0;
local AUTH = 1
local balancer_helper = require("core.router.balancer_helper")

local ngx_balancer = require "ngx.balancer"
local get_last_failure = ngx_balancer.get_last_failure
local set_current_peer = ngx_balancer.set_current_peer
local set_timeouts     = ngx_balancer.set_timeouts
local set_more_tries   = ngx_balancer.set_more_tries


local set_header = ngx.req.set_header
local ngx_var = ngx.var
local lower = string.lower
local str_format = string.format

--local api_group_dao = require("core.dao.api_route_dao")

local api_route_handler = base_handler:extend()

local plugin_name = config.plugin_name

api_route_handler.PRIORITY = PRIORITY.api_router

local function now_millseconds()
    return ngx.now() * 1000
end

local function concat_upstream_uri(upstream_host,upstream_path, upstream_query_string)
    local upstream_uri
    if not upstream_host then
        upstream_host = "http://default_upstream/"
    end
    upstream_uri = upstream_host
    if upstream_path then
        if stringy.endswith(upstream_host,"/")
                and stringy.startswith(upstream_path,"/") then
            upstream_path = string.gsub(upstream_path,"/","",1)
        end
        upstream_uri = upstream_uri .. upstream_path
    end
    if upstream_query_string then
        upstream_uri = upstream_uri .."?"..upstream_query_string
    end
    return upstream_uri
end

local function get_balance_param(key)
    local value =  base_dao.get_global_property_by_param_name(key)
    if value then
        return tonumber(value)
    end
    return value
end

local function add_header_of_request_id(is_gen_trace_id)
    if is_gen_trace_id == true then
        local request_id = req_var_extractor.extract_header_param("request_id")
        if not request_id or request_id == '' then
            request_id = utils.uuid()
            set_header("request_id",request_id)
            ngx.log(ngx.DEBUG,'request_id is ',request_id)
        end
    end
    ngx.var.trace_id = req_var_extractor.extract_header_param("request_id") or '-'
end

local function deal_websocket_headers()
    -- Keep-Alive and WebSocket Protocol Upgrade Headers
    if ngx_var.http_upgrade and lower(ngx_var.http_upgrade) == "websocket" then
        ngx_var.upstream_connection = "upgrade"
        ngx_var.upstream_upgrade    = "websocket"

    else
        ngx_var.upstream_connection = "keep-alive"
    end
end

-- 修改request.headers
local function deal_req_headers(api_group_info)

    ngx.log(ngx.DEBUG,'========gen_trace_id',api_group_info.gen_trace_id==1,api_group_info.gen_trace_id)
    add_header_of_request_id(api_group_info.gen_trace_id==1)
    deal_websocket_headers()

    ngx.var.request_headers = json.encode(req_var_extractor.extract_headers());
end

-- 如果匹配到灰度分流器，把gray_divide_id改为对应的id
local function match_gray_divide(api_group_info)
    local gray_divides = api_group_info.gray_divides

    if(not gray_divides or #gray_divides == 0)then
        return
    end

    for _, gray_divide in ipairs(gray_divides) do
        local is_match = selector_helper.is_match(gray_divide.selector)

        if is_match == true then
            api_group_info.gray_divide_id = gray_divide.id

            if tonumber(api_group_info.enable_balancing) == 0 then
                local upstream_domain_info = req_var_extractor.split_full_uri(api_group_info.upstream_domain_name)
                api_group_info.upstream_domain_name = upstream_domain_info.scheme .."://".. gray_divide.gray_domain
            end
            api_group_info.wheel_size = gray_divide.wheel_size
            break
        end

    end
end

---
-- set proxy pass information:
--- 1. ngr handle loadbalance: calculate the upstream node's ip and port address
--- 2. proxy to interval service's domain: calculate the upstream domain address
-- @param api_group_info  api router information has been configured in database
-- @param req_info  the current request information
--
local function set_proxy_pass_info(api_group_info, req_info)
    local upstream_url
    local enable_balancing = tonumber(api_group_info.enable_balancing) or 0
    if enable_balancing ==  1 then

        -- ngr handle upstream loading balancing
        local upstream_host = "http://default_upstream/"
        upstream_url = concat_upstream_uri(upstream_host,req_info.path,req_info.query_string)
        ngx.var.upstream_url = upstream_url
        ngx.var.upstream_scheme = "http"
        ngx.var.upstream_host = req_info.req_host
        local balancer_address = {}
        balancer_address.group_id = api_group_info.id
        balancer_address.gray_divide_id = api_group_info.gray_divide_id
        local host_group_context = api_router_dao.build_host_group_context(api_group_info.host,api_group_info.group_context)
        balancer_address.upstream_group_context = api_group_info.group_context
        balancer_address.upstream_host = req_info.req_host
        balancer_address.healthchecker = get_healthchecker(host_group_context)
        if  not  balancer_address.healthchecker then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"balancer_address.healthchecker is nil for api_group: " .. host_group_context))
        end
        balancer_address.upstream_service_id = api_group_info.upstream_service_id
        balancer_address.balance_algo = api_group_info.lb_algo
        balancer_address.wheel_size = api_group_info.wheel_size
        balancer_address.targets = router_initializer.get_targets(api_group_info, api_group_info.gray_divide_id,true)
        balancer_address.connection_timeout = get_balance_param(config.balance_connection_timeout_key) or 10000
        balancer_address.send_timeout =  get_balance_param(config.balance_send_timeout_key) or 60000
        balancer_address.read_timeout = get_balance_param(config.balance_read_timeout_key) or 60000
        balancer_address.retries_count =  get_balance_param(config.balance_retries_count_key) or 0
        balancer_address.has_tried_count = 0
        balancer_address.tries = {}
        local ok, err = balancer_helper.execute(balancer_address)
        if not ok then
            local msg = "failed to retry the dns/balancer resolver for " .. host_group_context ..  "' with: ".. tostring(err)
            ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

            error_utils.add_error_2_ctx(error_type_biz,config.small_error_types.biz.type_no_available_balancer)
            resp_utils.say_response_UPSTREAM_ERROR(tostring(err))
            return
        end
        local ip = balancer_address.ip
        local port = balancer_address.port
        if not ip or not port then
            local msg = "failed to retry the dns/balancer resolver for ".. host_group_context .. "' with: ip or host id invalid.";
            ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

            error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_balancer_execute_error)
            resp_utils.say_response_UPSTREAM_ERROR(msg)
            return
        end
        ngx.ctx.balancer_address = balancer_address
    else
        -- upstream to interval service domain
        local upstream_domain_name =api_group_info.upstream_domain_name
        local len = str_len(upstream_domain_name)
        if not (str_sub(upstream_domain_name,len) == "/") then
            upstream_url = upstream_domain_name .."/"
        else
            upstream_url = upstream_domain_name
        end
        upstream_url = concat_upstream_uri(upstream_url, req_info.path,req_info.query_string)

        ngx_log(ngx.INFO,'upstream url is:',upstream_url)

        local upstream_domain_info = req_var_extractor.split_full_uri(upstream_domain_name)
        -- 设置 proxy_pass $upstream_url upstream_scheme upstream_host
        ngx.var.upstream_url = upstream_url
        ngx.var.upstream_scheme = upstream_domain_info.scheme
        ngx.var.upstream_host = upstream_domain_info.host
    end
end

local function get_auth_service_uri(uri)
    local server_domain = base_dao.get_global_property_by_param_name(config.auth_server_domain_name)
    if not server_domain then
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,"auth_service_uri not found..."))

        error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_auth_conf_error)
        resp_utils.say_response_SERVICE_NOT_FOUND()
        return
    end

    local url
    if uri then
        url = server_domain .. uri
    else
        -- 约定访问 API Gateway 的 uri 就是auth服务的地址
        url = server_domain .. ngx.var.request_uri
    end

    return url
end

-- 生成签名
local function generateSign(signs,app_key)
    local keys = {}
    for k, v in pairs(signs) do
        table.insert(keys,k)
    end
    table.sort(keys)

    local str=""
    for _,k in ipairs(keys) do
        str = str .. k .. "=" .. signs[k] .. "&"
    end

    str = str .. "appKey=" .. app_key

    return ngx.md5(str)

end

-- 构建需要签名的参数
local function build_sign_param(app_id,app_key)
    local signs = {}
    signs["appId"]=app_id
    signs["language"]="zh-CN"
    signs["requestId"]= utils.random_string()
    signs["timeZone"]="GMT"
    signs["timestamp"]=ngx.time()--ngx.utctime()
    signs["sign"] = generateSign(signs,app_key)
    return signs
end

--TODO please fix bugs, request method must be followed auth api
local function build_auth_req_param(app_id, app_key, uri)

    local req = {}
    local method = ngx.var.request_method
    local headers = {}
    local data = {}
    local body={}
    local token,device_Id
    if method == "GET" then
        token = req_var_extractor.extract_query_param("token")
        device_Id = req_var_extractor.extract_query_param("deviceId")
    elseif method == "POST" then
        token = req_var_extractor.extract_post_param("token")
        device_Id = req_var_extractor.extract_post_param("deviceId")
    end

    if not token then
        error_utils.add_error_2_ctx(error_type_biz,config.small_error_types.biz.type_token_error)
        resp_utils.say_response_SERVICE_UNAUTHORIZED("'token' can't be empty")
        return
    end
    -- add token to ctx
    ngx.ctx.consumer_id_type = "token"
    ngx.ctx.consumer_id = token

    headers["content-type"] = "application/json"
    data["token"] = token
    if device_Id then
        data["deviceId"] = device_Id
    end
    body["data"]=data
    body["sign"]=build_sign_param(app_id,app_key)

    req["uri"] = uri
    req["headers"] = headers
    req["method"] = "POST"
    req["body"]=json.encode(body)
    return req
end

local function check_auth_token(ngr_config,url)

    local app_id = base_dao.get_global_property_by_param_name(config.auth_server_ngr_app_id)
    local app_key = base_dao.get_global_property_by_param_name(config.auth_server_ngr_app_key)

    if not app_id or not app_key then
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,"app_id or app_key is null"))

        error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_auth_conf_error)
        resp_utils.say_response_SERVICE_UNAUTHORIZED("app_id or app_key is null")
        return
    end

    local req = build_auth_req_param(app_id,app_key,url)
    local httpc = require("core.utils.http_client")(ngr_config.http_client)

    ngx_log(ngx_DEBUG,"check_auth_token req:",json.encode(req))

    local resp,err = httpc:send(req)
    if not resp then
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,"token verification failed;err:" .. err))
        error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_auth_invoke_error)
        resp_utils.say_response_SERVICE_UNAUTHORIZED(err)
        return
    end

    local body = json.decode(resp.body)
    if tonumber(body.errNo) ~= TOKEN_VALIDATION then

        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,"token verification failed.errNo:" .. body.errNo))

        error_utils.add_error_2_ctx(error_type_biz,config.small_error_types.biz.type_token_error)
        resp_utils.say_response_SERVICE_UNAUTHORIZED(nil)
        return
    end

    if httpc then
        httpc:close()
    end
end

--
--refresh balancer address information from shared cache in balancer phase
--@param address will be refresh
--
local function refresh_balancer_address(addr)
    local group_context = addr.upstream_group_context
    local host = addr.upstream_host;
    local api_group = api_router_dao.get_api_group_by_group_context(host, group_context)
    addr.targets = router_initializer.get_targets(api_group, addr.gray_divide_id,true)
end

function api_route_handler:new(app_context)
    api_route_handler.super.new(self, plugin_name)
    self.app_context = app_context
end

function api_route_handler:access()
    api_route_handler.super.access(self)
    ngx_log(ngx_DEBUG,"in api_router access start ============")
    local  req_info = req_var_extractor.extract_req_uri()

    local api_group_info = api_router_dao.get_api_group_by_group_context(req_info.req_host, req_info.api_group_context)

    if not api_group_info then -- host_group_context 不存在
        ngx_log(ngx.INFO,"host_group_context [" .. (req_info.req_host.. '-'.. req_info.api_group_context) .. "] not exist")
        error_utils.add_error_2_ctx(error_type_biz,config.small_error_types.biz.type_service_not_found)
        resp_utils.say_response_SERVICE_NOT_FOUND()
        return
    end

    -- generate upstream path, req_info.path append to group context or rewrite to
    req_var_extractor.gen_upstream_req_info_for_group_context(api_group_info,req_info)

    -- 缓存api_group_id,cache_client
    ngx.var.api_router_group_id = api_group_info.id


    ngx_log(ngx_DEBUG,"debug display current api router information:".. json.encode(api_group_info))
    -- 是否需要授权
    if tonumber(api_group_info.need_auth) == AUTH then -- 需要授权
        check_auth_token(self.app_context.config,get_auth_service_uri(config.auth_api.get_login_info))
    else
        --add remote ip to consumer id
        ngx.ctx.consumer_id_type = "ip"
        ngx.ctx.consumer_id = req_var_extractor.extract_IP()
    end

    deal_req_headers(api_group_info)

    match_gray_divide(api_group_info)

    ngx_log(ngx_DEBUG,"debug display current api router information after match gray divide:".. json.encode(api_group_info))

    set_proxy_pass_info(api_group_info,req_info)

    ngx_log(ngx_DEBUG,"in api_router access end ============")
end

function api_route_handler: init_worker_ext_timer()
    api_route_handler.super:init_worker_ext_timer()
    ngx_log(ngx_DEBUG,"in api_router init_worker_ext_timer  ============")
    err_resp_template_utils.init_2_redis(plugin_name,self.app_context.store,self.app_context.cache_client)
end

---
--  upstream balancer execute:
--  1. set currernt peer
--  2. set timeouts
--  no support for retries
--
function api_route_handler : balancer()
    api_route_handler.super: balancer()
    ngx_log(ngx_DEBUG,"in api_router balancer  ============")
    local addr = ngx.ctx.balancer_address
    addr.has_tried_count = addr.has_tried_count + 1
    ngx_log(ngx_DEBUG,"addr.has_tried_count  ============" .. addr.has_tried_count)
    local las_status_code
    local tries = addr.tries
    local current_try = {}
    tries[addr.has_tried_count] = current_try
    current_try.balancer_start = now_millseconds()
    if addr.has_tried_count > 1 then
        -- only call balancer on retry, first one is done in `access` which runs
        -- in the ACCESS context and hence has less limitations than this BALANCER
        -- context where the retries are executed

        -- collect the unhealthy target into shard dict[shard_dict_healthchecks] again
        if addr.half_open then
            keep_target_circuit_break_open_status(addr.group_id,addr.ip,addr.port)
        else
            -- record faliure data
            local previous_try = tries[addr.has_tried_count - 1]
            previous_try.state, previous_try.code = get_last_failure()
            las_status_code = previous_try.code
            -- Report HTTP status for passive health checks
            if addr.healthchecker then

                local msg = "previous_try.state: " ..  previous_try.state .. ",previous_try.code:" .. previous_try.code;
                ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

                error_utils.add_error_2_ctx(error_type_upstream,previous_try.code)
                if previous_try.state == "failed" and not previous_try.code then
                    local _, err = addr.healthchecker:report_tcp_failure(addr.ip, addr.port, nil, "passive")
                    if err then
                        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,"[healthchecks] failed reporting status: "..err))
                    end
                    ngx.log(ngx.INFO, "report upstream tcp failure,ip=", addr.ip,",port=" ,addr.port)
                else
                    local _, err = addr.healthchecker:report_http_status(addr.ip, addr.port, previous_try.code, "passive")
                    if err then
                        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,"[healthchecks] failed reporting status: "..err))
                    end
                    ngx.log(ngx.INFO, "report upstream http failure,ip=", addr.ip,",port=" ,addr.port,", http_status= ",previous_try.code)
                end
            end
        end
        -- 非幂等方法上报过后，直接退出
        local method_name = req_var_extractor.extract_method()
        if utils.is_non_idempotent(method_name) then
            las_status_code = las_status_code or 502
            ngx.exit(las_status_code)
            return
        end

        refresh_balancer_address(addr)
        local ok, err =balancer_helper.execute(addr)
        if not ok then

            local msg = "failed to retry the dns/balancer resolver for ".. addr.upstream_service_id ..  "' with: " ..  tostring(err)
            ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

            error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_balancer_execute_error)

            ngx.exit(502)
            return
        end
    else
        -- first try, so set the max number of retries
        local retries = addr.retries_count
        if retries > 0 then
            local method_name = req_var_extractor.extract_method()

            if not utils.is_non_idempotent(method_name) then
                set_more_tries(retries)
            end
        end
    end

    current_try.ip   = addr.ip
    current_try.port = addr.port
    local ip = addr.ip
    local port = addr.port
    local ok, err = set_current_peer(ip, port)
    if not ok then

        local msg = "failed to set the current peer (address: " ..  tostring(ip), " port: " .. tostring(port), "): " .. tostring(err);
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,msg))

        error_utils.add_error_2_ctx(error_type_sys,config.small_error_types.sys.type_balancer_execute_error)

        return ngx.exit(502);
    end

    ok, err = set_timeouts(addr.connection_timeout / 1000, addr.send_timeout / 1000, addr.read_timeout /1000)
    if not ok then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"could not set upstream timeouts: "..err))
    end
    -- record try-latency
    local try_latency = now_millseconds() - current_try.balancer_start
    current_try.balancer_latency = try_latency
    current_try.balancer_start = nil
end

return api_route_handler