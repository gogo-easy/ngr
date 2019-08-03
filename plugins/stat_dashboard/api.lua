---
---  stat_dashboard api
--- Created by jacobs.
--- DateTime: 2018/4/26 上午11:32
---
local API = {}
local json = require("cjson")
local gateway_dao = require("core.dao.gateway_dao")


local function get_target(config,service_name)
    local targets={}
    local httpc = require("core.utils.http_client")({
        timeout=2000,
        max_idle_timeout=6000,
        pool_size=100
    })

    local req={}
    local headers ={}
    headers["content-type"] = "application/json"
    headers["Accept"] = "application/json"
    req["uri"] = config.application_conf.cmdb_url .."/api/host/host/?service_name="..service_name.."&env="..config.application_conf.cmdb_env
    req["headers"] = headers
    req["method"] = "GET"

    local resp,err = httpc:send(req)

    if not resp then
        ngx.log(ngx.ERR,"cmdb get target failed:",err)
        return targets
    end
    local body = json.decode(resp.body)
    if body and body.results then
        for _, v in ipairs(body.results) do
            table.insert(targets,v.ip)
        end
    end
    if httpc then
        httpc:close()
    end
    return targets
end
---
-- show all the dashboard statistics properties
--
API["/dashboard/show"] = {
    GET = function(store,cache_client,config)
        return function(req, res, next)
            local flag,services = gateway_dao.query_gateway_code(store)
            local result={}
            if flag then
                local stat = require("plugins.stat_dashboard.stats")(cache_client)
                local stat_result = stat:stat(services)

                if stat_result and stat_result.base_infos then
                    --for _, base_info in ipairs(stat_result.base_infos) do
                    --    local targets = get_target(config,base_info.service_name)
                    --
                    --    if targets and #targets > 0 then
                    --        base_info.targets = string.gsub(json.encode(targets),"\"","")
                    --    end
                    --end
                end

                return res:json({success=true,data=stat_result})
            else
                return res:json({success=false,msg="operation failed"})
            end


            res:json(result)
        end
    end
}

return API