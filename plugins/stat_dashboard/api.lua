---
---  stat_dashboard api
--- Created by jacobs.
--- DateTime: 2018/4/26 上午11:32
---
local API = {}
local json = require("cjson")
local gateway_dao = require("core.dao.gateway_dao")
local gateway_instance_dao = require("core.dao.gateway_instance_dao")


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

-- convert time from 'yyyy-mm-dd HH:MM:SS' to timestamp
-- @param time_str, the format of time_str is 'yyyy-mm-dd HH:MM:SS'
-- @return timestamp type int
local function toTS(time_str)
    local year = string.sub(time_str, 1, 4)
    local month = string.sub(time_str, 6, 7)
    local day = string.sub(time_str, 9, 10)
    local hour = string.sub(time_str, 12, 13)
    local min = string.sub(time_str, 15, 16)
    local sec = string.sub(time_str, 18, 19)

    return os.time({year=year, month=month, day=day, hour=hour, min=min, sec=sec})
end

local function is_health(instance, config)
    local t_renew = toTS(instance.renew_time)
    local t_now = os.time()
    local interval = nil
    if config then
        interval = config.register_interval
    else
        interval = 10
    end
    if t_now > 2*interval + t_renew then
        return false
    end
    return true
end

---
-- show all the dashboard statistics properties
--
API["/dashboard/show"] = {
    GET = function(store,cache_client,config)
        return function(req, res, next, config)
            local flag,services = gateway_dao.query_gateway_code(store)
            local result={}
            if flag then
                local stat = require("plugins.stat_dashboard.stats")(cache_client)
                local stat_result = stat:stat(services)

                if stat_result and stat_result.base_infos then
                    -- for _, base_info in ipairs(stat_result.base_infos) do
                    --    local targets = get_target(config,base_info.service_name)
                    
                    --    if targets and #targets > 0 then
                    --        base_info.targets = string.gsub(json.encode(targets),"\"","")
                    --    end
                    -- end
                    local health_count = 0
                    for _, base_info in ipairs(stat_result.base_infos) do
                        local instances = gateway_instance_dao.instances(base_info.service_name, store)
                        for _, instance in ipairs(instances) do
                            instance.is_health = is_health(instance, config)
                            instances[_] = instance
                            if instance.is_health then
                                health_count = health_count + 1
                            end
                        end
                        local gateway_status = nil
                        if health_count == #instances then
                            -- all instances is healthy
                            gateway_status = 1
                        elseif health_count == 0 then
                            -- none instance is healthy
                            gateway_status = -1
                        else
                            -- some instances but not all is healthy
                            gateway_status = 0
                        end

                        base_info.instances = instances 
                        base_info.gateway_status = gateway_status
                        stat_result.base_infos[_] = base_info
                    end
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