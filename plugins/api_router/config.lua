local _M = {}

-- 插件名称
_M.plugin_name = "api_router"

-- 认证（auth）服务 域名
_M.auth_server_domain_name = "AUTH_SERVER_DOMAIN_NAME";

-- 认证（auth）服务给悟空配置的 app_id
_M.auth_server_ngr_app_id = "AUTH_SERVER_NGR_APP_ID";

-- 认证（auth）服务给悟空配置的 app_key
_M.auth_server_ngr_app_key = "AUTH_SERVER_NGR_APP_KEY";

-- group_context old all 缓存key
_M.api_group_context_old_all_key = "API_GROUP_CONTEXT_AND_HOST_OLD_ALL";
-- group_context 缓存key
_M.api_group_context_key = "API_GROUP_CONTEXT_AND_HOST";

_M.build_cache_group_context_key = function(append_key)
    return _M.api_group_context_key .. append_key
end

_M.auth_api={
    login = "/app/login", -- 获取token
    get_login_info = "/app/getLoginInfo" -- 校验token ，目前就是获取用户信息
}

-- error retries count
_M.balance_retries_count_key = "BALANCE_RETRIES_COUNT"
_M.balance_connection_timeout_key = "BALANCE_CONNECTION_TIMEOUT"
_M.balance_send_timeout_key =  "BALANCE_SEND_TIMEOUT"
_M.balance_read_timeout_key = "BALANCE_READ_TIMEOUT"

_M.small_error_types = {
    sys =  {
        type_auth_conf_error = "api.auth_conf_error",
        type_auth_invoke_error = "api.auth_ivk_error",
        type_balancer_execute_error = "api.balancer_execute_error"
    },
    biz = {
        type_service_not_found = "api.no_service",
        type_req_method_not_support = "api.med_not_support",
        type_token_error = "api.token_error",
        type_no_available_balancer = "api.no_available_balancer"
    }
}


return _M