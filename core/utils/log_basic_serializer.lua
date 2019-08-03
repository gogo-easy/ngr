---
--Nginx request information serialize utils
-- created by Jacobs Lei
-- DateTime: 2018/5/9 上午11:41
--

local req_var_extractor = require("core.req.req_var_extractor")

local _M = {}

function _M.serialize(ngx)
    local service_context = ngx.ctx.service_context
    local gac_reject = ngx.ctx.GLOBAL_ACCESS_CONTROL_REJECT
    if not gac_reject then
        gac_reject = false
    end
    local consumer_id_type = ngx.ctx.consumer_id_type
    local consumer_id = ngx.ctx.consumer_id
    if not consumer_id_type then
        consumer_id_type = "ip"
        consumer_id = req_var_extractor.extract_IP()
    end

    local has_error = ngx.ctx.error
    local error_type
    local error_detail
    if has_error then
        error_type = ngx.ctx.error_type
        error_detail = ngx.ctx.error_detail
    end

    return {
        request = {
            uri = ngx.var.request_uri or "/",
            url = ngx.var.scheme .. "://" .. ngx.var.host .. ":" .. ngx.var.server_port .. ( ngx.var.request_uri or "/"),
            query_string = ngx.req.get_uri_args(), -- parameters, as a table
            method = ngx.req.get_method(), -- http method
            headers = ngx.req.get_headers(),
            size = ngx.var.request_length
        },
        upstream_uri = ngx.var.upstream_uri,
        response = {
            status = ngx.status,
            headers = ngx.resp.get_headers(),
            size = ngx.var.bytes_sent
        },
        latencies = {
            -- ngr process time
            ngr = (ngx.ctx.NGR_ACCESS_TIME or 0) +
            (ngx.ctx.NGR_RECEIVE_TIME or 0) ,
            -- upstream process time
            proxy = ngx.ctx.NGR_WAITING_TIME or -1,
            -- request time
            request = ngx.var.request_time * 1000
        },

        -- upstrem service context
        service_context = service_context,

        consumer_id = consumer_id,
        consumer_id_type = consumer_id_type,

        --error
        gac_reject = gac_reject,
        error_type = error_type,
        error_detail = error_detail,

        started_at = ngx.req.start_time() * 1000
    }
end

return _M
