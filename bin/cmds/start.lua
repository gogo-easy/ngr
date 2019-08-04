local ngx_handle = require("bin.utils.ngx_handle")
local logger = require("bin.utils.logger")
local init_conf = require("bin.initconf.init_conf")
local pl_path = require("pl.path")

local function new_handler(args)
    args.necessary_dirs ={ -- runtime nginx conf/pid/logs dir
        tmp = args.prefix .. '/tmp',
        logs = args.prefix .. '/logs',
        pids = args.prefix .. '/pids'
    }

    return ngx_handle:new(args)
end


local _M = {}


_M.help = [[
Usage: NgrRouter start [OPTIONS]

Start NgrRouter with configurations(prefix/ngr_conf/ngx_conf).

Options:
 -p,--prefix  (optional string) override prefix directory
 -c,--conf (optional string) ngr(ngr.json) configuration file
 -h,--help (optional string) show help tips

Examples:
 ngr start  #use `/usr/local/ngr` as workspace with `/usr/local/ngr/conf/ngr.json`
 ngr start --prefix=/opt/ngr  #use the `prefix` as workspace with ${prefix}/conf/ngr.json & ${prefix}/conf/nginx.conf
 ngr start --conf=/opt/ngr/conf/ngr.json --prefix=/opt/ngr
 ngr start -h  #just show help tips
]]

function _M.execute(origin_args)

    -- format and parse args
    local args = {
        ngr_conf = origin_args.conf,
        prefix = origin_args.prefix
    }
    for i, v in pairs(origin_args) do
        if i ~= "c" and i ~= "p" and i ~= "conf" and i ~= "prefix" then
            logger:error("Command Start option[name=%s] do not support.", i)
            return
        end
        if i == "c" and not args.ngr_conf then
            args.ngr_conf = v

        end
        if i == "p" and not args.prefix then
            args.prefix = v
        end
    end

    -- use default args if not exist
    if not args.prefix then
        args.prefix = "/usr/local/ngr"
    end
    if not args.ngr_conf then
        args.ngr_conf = args.prefix .. "/conf/ngr.json"
    end
    args.ngx_conf = args.prefix .. "/conf/nginx.conf"

    if args then
        logger:info("args:")
        for i, v in pairs(args) do
            logger:info("\t %s:%s", i, v)
        end
    end

    local err
    xpcall(function()
        local ok, err= init_conf(args)
        if not ok or err then
            logger:error("NgrRouter started failed.err:%s", err)
            os.exit(1)
        end
        local handler = new_handler(args)
        local result = handler:start()
        if result then
            logger:success("NgrRouter started.")
        else
            os.exit(1)
        end
    end, function(e)
        logger:error("Could not start NgrRouter, stopping it")
        pcall(pcall(function()
            local handler = new_handler(args)
            handler:stop()
        end))
        err = e
        logger:warn("Stopped NgrRouter")
    end)

    if err then
        error(err)
        os.exit(1)
    end
end


return _M
