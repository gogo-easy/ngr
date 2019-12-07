local ngx_handle = require("bin.utils.ngx_handle")
local logger = require("bin.utils.logger")
local pl_path = require "pl.path"

local _M = {}


_M.help = [[
Usage: NgrRouter stop [OPTIONS]

Stop NgrRouter with configurations(prefix/ngr_conf).

Options:
 -p,--prefix  (optional string) override prefix directory
 -c,--conf (optional string) NgrRouter configuration file
 -h,--help (optional string) show help tips

Examples:
 ngr stop  #use `/usr/local/ngr` as workspace with `/usr/local/ngr/conf/ngr.json` & `/usr/local/ngr/conf/nginx.conf`
 ngr stop --prefix=/opt/ngr  #use the `prefix` as workspace with ${prefix}/conf/ngr.json & ${prefix}/conf/nginx.conf
 ngr stop --conf=/opt/ngr/conf/ngr.conf --prefix=/opt/ngr
 ngr stop -h --help #just show help tips
]]

function _M.execute(origin_args)

    -- format and parse args
    local args = {
        ngr_conf = origin_args.conf,
        prefix = origin_args.prefix
    }
    for i, v in pairs(origin_args) do
        if i ~= "c" and i ~= "p" and i ~= "conf" and i ~= "prefix" and i ~= "d" and i ~= "daemon" then
            logger:error("Command stop option[%s=%s] do not support.", i,v)
            return
        end
        if i == "c" and not args.ngr_conf then
            args.ngr_conf = v

        end
        if i == "p" and not args.prefix then
            args.prefix = v
        end
    end

    -- use default args if not exist /usr/local/ngr
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
    local pids_path = args.prefix .. "/pids"
    local pid_path = pids_path .. "/nginx.pid"
    if not pl_path.exists(pid_path ) then
        logger:info("\t ngr had stopped before, do not need execute stop command again.")
        return
    end
    local err
    xpcall(function()
        local handler = ngx_handle:new(args)
        local result = handler:stop()
        if result  then
            logger:success("NgrRouter stopped.")
        else
            os.exit(1)
        end
    end, function(e)
        logger:error("Could not stop NgrRouter, error: %s", e)
        err = e
    end)

    if err then
        error(err)
        os.exit(1)
    end
end


return _M
