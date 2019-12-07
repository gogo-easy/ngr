local pl_stringio = require "pl.stringio"
local pl_stringx = require "pl.stringx"
local pl_config = require "pl.config"
local io = require "core.utils.io"
local pl_file = require "pl.file"
local pl_path = require "pl.path"
local tablex = require "pl.tablex"
local logger = require "bin.utils.logger"
local json = require("core.utils.json")
local unpack = unpack


local PREFIX_PATHS = {
  nginx_pid = {"pids", "nginx.pid"},
  nginx_err_logs = {"logs", "error.log"},
  nginx_acc_logs = {"logs", "access.log"},
  nginx_conf = {"conf/nginx.conf"}
  ;
}

-- By default, all properties in the configuration are considered to
-- be strings/numbers, but if we want to forcefully infer their type, specify it
-- in this table.
-- Also holds "enums" which are lists of valid configuration values for some
-- settings.
-- See `typ_checks` for the validation function of each type.
--
-- Types:
-- `boolean`: can be "on"/"off"/"true"/"false", will be inferred to a boolean
-- `ngx_boolean`: can be "on"/"off", will be inferred to a string
-- `array`: a comma-separated list
local CONF_INFERENCES = {
  -- forced string inferences (or else are retrieved as numbers)
  proxy_listen = {typ = "array"},
  admin_listen = {typ = "array"},
  db_update_frequency = { typ = "number" },
  db_update_propagation = { typ = "number" },
  db_cache_ttl = { typ = "number" },
  nginx_user = {typ = "string"},
  worker_processes_count = {typ = "string"},
  event_mode={typ = "string"},
  upstream_keepalive = {typ = "number"},
  server_tokens = {typ = "boolean"},
  latency_tokens = {typ = "boolean"},
  trusted_ips = {typ = "array"},
  real_ip_header = {typ = "string"},
  real_ip_recursive = {typ = "ngx_boolean"},
  client_max_body_size = {typ = "string"},
  client_body_buffer_size = {typ = "string"},
  error_default_type = {enum = {"application/json", "application/xml",
                                "text/html", "text/plain"}},
  dns_resolver = {typ = "array"},
  dns_resolver_valid = {typ = "string"},
  resolver_timeout = {typ = "string"},
  dns_hostsfile = {typ = "string"},
  dns_order = {typ = "array"},
  dns_stale_ttl = {typ = "number"},
  dns_not_found_ttl = {typ = "number"},
  dns_error_ttl = {typ = "number"},
  dns_no_sync = {typ = "boolean"},

  access_log = {typ = "string"},
  error_log = {typ = "string"},
  admin_access_log = {typ = "string"},
  admin_error_log = {typ = "string"},
  log_level = {enum = {"debug", "info", "notice", "warn",
                       "error", "crit", "alert", "emerg"}},
  custom_plugins = {typ = "array"},
  anonymous_reports = {typ = "boolean"},
  nginx_daemon = {typ = "ngx_boolean"},
  nginx_optimizations = {typ = "boolean"},
  worker_connections = {typ = "number"},
  worker_rlimit={typ ="number"},

  lua_ssl_verify_depth = {typ = "number"},
  lua_socket_pool_size = {typ = "number"},
  global_config_cache_data_size = {typ = "string"},
  stat_dashboard_data_size = {typ = "string"},
  shared_dict_lock_data_size = {typ = "string"},
  worker_events_data_size = {typ ="string"},
  healthchecks_data_size = {typ ="string"},
  rate_limit_counter_cache_data_size = {typ = "string"},
  lua_max_pending_timers = {typ = "number"},
  lua_max_running_timers = {typ = "number"},
  lua_socket_log_errors = {typ = "string"},
  default_upstream = {typ = "string"},
  service_type = {typ = "string"},
  server_name_80 = {typ = "string"},
  listen_port = {typ = "string"},
  open_ssl = {typ = "boolean"},
  ssl_certificate = {typ = "string"},
  ssl_certificate_key = {typ = "string"},
  add_headers = {typ = "array"},
  hosts = {typ = "array"},
  hosts_conf={typ = "array"},
  error_page_switch={typ = "string"},
  proxy_intercept_errors={typ = "string"},
  error_page_code={typ = "string"},
  upstream_keepalive={typ = "number"},
  proxy_http_version = {typ = "string"},
  include_directives = {typ = "string"},
}

local typ_checks = {
  array = function(v) return type(v) == "table" end,
  string = function(v) return type(v) == "string" end,
  number = function(v) return type(v) == "number" end,
  boolean = function(v) return type(v) == "boolean" end,
  ngx_boolean = function(v) return v == "on" or v == "off" end
}

-- Validate properties (type/enum/custom) and infer their type.
-- @param[type=table] conf The configuration table to treat.
local function check_and_infer(conf)
  local errors = {}

  for k, value in pairs(conf) do
    local v_schema = CONF_INFERENCES[k] or {}
    local typ = v_schema.typ

    if type(value) == "string" then

      -- remove trailing comment, if any
      -- and remove escape chars from octothorpes
      value = string.gsub(value, "[^\\]#.-$", "")
      value = string.gsub(value, "\\#", "#")

      value = pl_stringx.strip(value)
    end

    -- transform {boolean} values ("on"/"off" aliasing to true/false)
    -- transform {ngx_boolean} values ("on"/"off" aliasing to on/off)
    -- transform {explicit string} values (number values converted to strings)
    -- transform {array} values (comma-separated strings)
    if typ == "boolean" then
      value = value == true or value == "on" or value == "true"
    elseif typ == "ngx_boolean" then
      value = (value == "on" or value == true) and "on" or "off"
    elseif typ == "string" then
      value = tostring(value) -- forced string inference
    elseif typ == "number" then
      value = tonumber(value) -- catch ENV variables (strings) that should be numbers
    elseif typ == "array" and type(value) == "string" then
      -- must check type because pl will already convert comma
      -- separated strings to tables (but not when the arr has
      -- only one element)
      value = setmetatable(pl_stringx.split(value, ","), nil) -- remove List mt

      for i = 1, #value do
        value[i] = pl_stringx.strip(value[i])
      end
    end

    if value == "" then
      -- unset values are removed
      value = nil
    end

    typ = typ or "string"
    if value and not typ_checks[typ](value) then
      errors[#errors+1] = k .. " is not a " .. typ .. ": '" .. tostring(value) .. "'"
    elseif v_schema.enum and not tablex.find(v_schema.enum, value) then
      errors[#errors+1] = k .. " has an invalid value: '" .. tostring(value)
                          .. "' (" .. table.concat(v_schema.enum, ", ") .. ")"
    end

    conf[k] = value
  end

  if not conf.lua_package_cpath then
    conf.lua_package_cpath = ""
  end

  return #errors == 0, errors[1], errors
end

--- Load ngr configuration
-- @param[type=string] conf_path (optional) Path to a configuration file.
-- @treturn table A table holding a valid configuration.
local function load(conf_path,prefix,daemon)

  ---------------------
  -- Configuration file
  ---------------------
  local from_file_conf = {}
  local read_err
  if conf_path and not pl_path.exists(conf_path) then
    -- file conf has been specified and must exist
    return nil, "no file at: " .. conf_path
  end

  if not conf_path then
    logger:error("no config file, skipping loading")
    return nil,"no config file"
  else

    logger:info("Reading config file at %s", conf_path)

    if pl_stringx.endswith(conf_path,".json") then
      local json_conf = io.read_file(conf_path)
      if json_conf then
        json_conf = json.decode(json_conf)
        from_file_conf = json_conf.application_conf
      end
    else
      local f, err = pl_file.read(conf_path)
      if not f then
        return nil, err
      end
      local s = pl_stringio.open(f)
      from_file_conf, read_err = pl_config.read(s, {
        smart = false,
        list_delim = "_blank_" -- mandatory but we want to ignore it
      })
      s:close()
    end

    if not from_file_conf then
      return nil, read_err or "file format is wrong"
    end
  end

  -- validation
  local ok, err, errors = check_and_infer(from_file_conf)
  if not ok then
    return nil, err, errors
  end

local conf = from_file_conf
  -----------------------------
  -- Additional injected values
  -----------------------------

  conf.prefix = prefix
  conf.ngr_conf = conf_path
  conf.daemon = daemon

  -- attach prefix files paths
  for property, t_path in pairs(PREFIX_PATHS) do
    conf[property] = pl_path.join(conf.prefix, unpack(t_path))
  end

  return setmetatable(conf, nil) -- remove Map mt
end

return setmetatable({
  load = load,
}, {
  __call = function(_, ...)
    return load(...)
  end
})
