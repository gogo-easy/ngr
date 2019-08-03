

local find = string.find
local format = string.format
local req_var_extractor = require("core.req.req_var_extractor")
local resp_utils = require("core.resp.resp_utils")
local error_utils = require("core.utils.error_utils")
local api_router_config = require("plugins.api_router.config")
local TYPE_PLAIN = "text/plain; charset=utf-8"
local TYPE_JSON = "application/json; charset=utf-8"
local TYPE_XML = "application/xml; charset=utf-8"
local TYPE_HTML = "text/html; charset=utf-8"

local text_template = "error_code:%s,error_message:%s."
local json_template = '{"error_code":"%s","error_message":"%s"}'
local xml_template = '<?xml version="1.0" encoding="UTF-8"?>\n<error><error_code>%s</error_code><error_message>%s</error_message></error>'
local html_template = '<html><head><title>Ngr Error</title></head><body><h1>Ngr Error</h1><p>error_code:%s,error_message:%s.</p></body></html>'


local BODIES = {
  s400 = "upstream service error:Bad request",
  s404 = "upstream service error:Not found",
  s408 = "upstream service error:Request timeout",
  s411 = "upstream service error:Length required",
  s412 = "upstream service error:Precondition failed",
  s413 = "upstream service error:Payload too large",
  s414 = "upstream service error:URI too long",
  s417 = "upstream service error:Expectation failed",
  s494 = "upstream service error:Request Header Or Cookie Too Large",
  s500 = "upstream service error:An unexpected error occurred",
  s502 = "upstream service error:An invalid response was received from the upstream server",
  s503 = "upstream service error:The upstream server is currently unavailable",
  s504 = "upstream service error:The upstream server is timing out",
  default = "upstream service error:The upstream server responded with %d"
}

local function handle_consumer(ngx)
  ngx.ctx.service_context = req_var_extractor.extract_req_uri().api_group_context
  ngx.ctx.consumer_id_type = "ip"
  ngx.ctx.consumer_id = req_var_extractor.extract_IP()
end

local function handle_error(ngx)
  ngx.ctx.error = true
  ngx.ctx.error_type = error_utils.types.ERROR_UPSTREAM.name
  ngx.ctx.error_detail = ngx.status
end

return function(ngx,cache_client)

  local accept_header = ngx.req.get_headers()["accept"]
  local template, message, content_type, error_code

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

  local status = ngx.status
  message = BODIES["s" .. status] or format(BODIES.default, status)
  --6xxxx upstream error
  error_code = "60" .. status

  handle_consumer(ngx)

  handle_error(ngx)

  ngx.log(ngx.INFO,"say_upstream_server_interval_error_response,http status[" ..status .. "]")
  --1、自定义错误信息处理。
  -- 获取api_group_id
  local api_group_id = ngx.var.api_router_group_id

  resp_utils.say_upstream_interval_error_response(ngx,content_type,format(template, error_code,message), api_router_config.plugin_name,api_group_id,cache_client)
end
