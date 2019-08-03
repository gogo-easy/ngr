local cjson = require("core.utils.json")
local IO = require "core.utils.io"

local _M = {}

local env_ngr_conf_path = os.getenv("NGR_CONF_PATH")

_M.default_ngr_conf_path = env_ngr_conf_path or ngx.config.prefix() .."/conf/ngr.json"

function _M.load(config_path)
    config_path = config_path or _M.default_ngr_conf_path
    local config_contents = IO.read_file(config_path)

    if not config_contents then
        ngx.log(ngx.ERR, "No configuration file at: ", config_path)
        os.exit(1)
    end

    local config = cjson.decode(config_contents)
    return config, config_path
end

return _M