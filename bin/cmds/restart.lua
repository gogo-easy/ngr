local start_cmd = require("bin.cmds.start")
local stop_cmd = require("bin.cmds.stop")
local logger = require("bin.utils.logger")


local _M = {}


_M.help = [[
Usage: NgrRouter restart [OPTIONS]

Restart NgrRouter with configurations(prefix/ngr_conf).

Options:
 -p,--prefix  (optional string) override prefix directory
 -c,--conf (optional string) NgrRouter configuration file
 -h,--help (optional string) show help tips

Examples:
 ngr restart  #use `/usr/local/ngr` as workspace with `/usr/local/ngr/conf/ngr.json`
 ngr restart --prefix=/opt/ngr  #use the `prefix` as workspace with ${prefix}/conf/ngr.json & ${prefix}/conf/nginx.conf
 ngr restart --conf=/opt/ngr/conf/ngr.conf --prefix=/opt/ngr
 ngr restart -h  #just show help tips
]]

function _M.execute(origin_args)
    logger:info("Stop NgrRouter...")
    pcall(stop_cmd.execute, origin_args)

    logger:info("Start NgrRouter...")
    pcall(start_cmd.execute,origin_args)
end


return _M
