---
--- Nginx upstream load balancing utils
---
--- Copyright (c)GoGo Easy Team & Jacobs Lei
--- Author: Jacobs Lei
--- Date: 2018/6/20
--- Time: 下午4:35

local require = require
local tonumber = tonumber
local ipairs = ipairs
local global_cache = require("core.cache.local.global_cache_util")
local req_var_extractor = require("core.req.req_var_extractor")
local ngx = ngx
local hash = ngx.crc32_long
local ngx_ERR = ngx.ERR
local ngx_DEBUG = ngx.DEBUG
local ngx_INFO = ngx.INFO
local ngx_log = ngx.log
local str_format = string.format
local log_config = require("core.utils.log_config")

local resty_lock = require "resty.lock"
local balancer_round_robin_lock_key_prefix = "balancer_round_robin_group_lock_key"
local shard_name = require("core.constants.shard_name")
local json = require("core.utils.json")

local healthchecker_helper = require("core.router.healthcheck_helper")
local is_half_close_circuit_break_target = healthchecker_helper.is_half_close_circuit_break_target

---
-- @field ROUND_ROBIN 轮询
-- @field IP_HASH  IP哈希
--
local LB_ALGO = {
    ROUND_ROBIN = 1,
    IP_HASH = 2
}


local GLOBAL_CACHE_KEY_CURRENT_ROUND_ROBIN_INDEX = "balancer_current_round_robin_index"

---
--- get peer from targets  using round-robin
-- @param group_id  api group's id
-- @param targets  api group's being selected targets
-- @param balancer_wheel_size  round-robin wheel's size
-- @return ip, port, unhealthy node's half_open status
-- @return 返回节点的ip和port， 第三个返回参数如果是true则表示节点为非健康节点且开启半开状态
local function get_peer_using_round_robin(group_id,targets,balancer_wheel_size)
    local lock = resty_lock:new(shard_name.lock)
    local lock_key = balancer_round_robin_lock_key_prefix .. group_id
    local elapsed, err = lock:lock(lock_key)
    if not elapsed then
        ngx_log(ngx_ERR,"failed to acquire the lock: ", err)
        return nil, nil
    end
    ngx_log(ngx_DEBUG,"execute round-robin: wheel_size=",balancer_wheel_size)
    local current_idx = tonumber(global_cache.get(GLOBAL_CACHE_KEY_CURRENT_ROUND_ROBIN_INDEX .. group_id )) or 1
    -- current loop index greater than  balancer wheel size, set current index to 1
    if current_idx > balancer_wheel_size then
        current_idx = 1
    end

    ngx.log(ngx.DEBUG,"get_peer_using_round_robin current_idx=",current_idx)

    local selected_target
    local begin_index = current_idx
    for _, target in ipairs(targets) do
        local end_idx = target.end_idx
        if current_idx <= end_idx then
            selected_target = target
            ngx_log(ngx_INFO,"execute round-robin: selected_target_index=",current_idx,
                ",ip=", target.host, ", port=",target.port,", health status=",selected_target.health)
            if selected_target.health == true or selected_target.health == nil  then
                global_cache.set(GLOBAL_CACHE_KEY_CURRENT_ROUND_ROBIN_INDEX .. group_id, current_idx + 1)
                local ok, err = lock:unlock()
                if not ok then
                    ngx.log(ngx.ERR, "failed to  release the lock: ",err )
                end
                return selected_target.host, selected_target.port
            else
                -- if the selected_target is not in unhealthy collection, then  marks the unhealthy target half open status and return.
                if is_half_close_circuit_break_target(group_id,selected_target.host,selected_target.port) then -- half_open

                    ngx.log(ngx.INFO,"in half close - host=",selected_target.host,"port=",selected_target.port)

                    global_cache.set(GLOBAL_CACHE_KEY_CURRENT_ROUND_ROBIN_INDEX .. group_id, current_idx + 1)

                    local ok, err = lock:unlock()
                    if not ok then
                        ngx.log(ngx.ERR, "failed to  release the lock: ",err )
                    end
                    return selected_target.host, selected_target.port,true
                end
                -- selected target is unhealth, change to other target
                current_idx = end_idx + 1
            end
        end
    end

    -- if current index greater then  balancer wheel size
    if current_idx > balancer_wheel_size then
        current_idx = 1
    end

    ngx.log(ngx.DEBUG,"get_peer_using_round_robin current_idx=",current_idx)


    for _, target in ipairs(targets) do
        local end_idx = target.end_idx
        if current_idx <= end_idx then
            selected_target = target
            ngx_log(ngx_INFO,"execute round-robin: selected_target_index=",current_idx,
                    ",ip=", target.host, ", port=",target.port,", health status=",selected_target.health)
            if selected_target.health == true or selected_target.health == nil then
                global_cache.set(GLOBAL_CACHE_KEY_CURRENT_ROUND_ROBIN_INDEX ..  group_id, current_idx + 1)
                local ok, err = lock:unlock()
                if not ok then
                    ngx.log(ngx.ERR, "failed to  release the lock: ",err )
                end
                return selected_target.host, selected_target.port
            else
                -- if the selected_target is not in unhealthy collection, then  marks the unhealthy target half open status and return.
                if is_half_close_circuit_break_target(group_id,selected_target.host,selected_target.port) then -- half_open

                    global_cache.set(GLOBAL_CACHE_KEY_CURRENT_ROUND_ROBIN_INDEX ..  group_id, current_idx + 1)

                    local ok, err = lock:unlock()
                    if not ok then
                        ngx.log(ngx.ERR, "failed to  release the lock: ",err )
                    end
                    return selected_target.host, selected_target.port,true
                end
                -- selected target is unhealth, change to other target
                current_idx = end_idx + 1
                -- last time of loop, break
                if current_idx > begin_index then
                    break
                end
            end
        end
    end
    local ok, err = lock:unlock()
    if not ok then
        ngx.log(ngx.ERR, "failed to  release the lock: ",err )
    end
    local msg = "getting ip or port fails,targets:"..json.encode(targets)
    ngx_log(ngx_ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

    return nil, nil

end

---
--  get peer from all the targets by remote client ip's hash value
-- @param targets the targets will be selected from
--
local function get_peer_using_remote_ip_hash(group_id,targets)
    local remote_ip = req_var_extractor.extract_IP()
    local targets_count = #targets
    local key = hash(remote_ip)
    local index = key % targets_count+1
    for i = index, targets_count do
        local selected_target = targets[i]
        ngx_log(ngx_INFO,"execute ip hash: ip=", selected_target.host, ", port=",selected_target.port,", health status=",selected_target.health)
        if selected_target.health == true then
            return selected_target.host, selected_target.port
        else
            if is_half_close_circuit_break_target(group_id,selected_target.host,selected_target.port) then -- half_open
                return selected_target.host, selected_target.port,true
            end
        end
    end
    for i = 1, index-1 do
        local selected_target = targets[i]
        ngx_log(ngx_INFO,"execute ip hash: ip=", selected_target.host, ", port=",selected_target.port,", health status=",selected_target.health)
        if selected_target.health == true then
            return selected_target.host, selected_target.port
        else
            if is_half_close_circuit_break_target(group_id,selected_target.host,selected_target.port) then -- half_open
                return selected_target.host, selected_target.port,true
            end
        end
    end
    return nil, nil
end

local function get_peer(lb_algo, group_id,targets, balancer_wheel_size)
    lb_algo = tonumber(lb_algo) or 1
    if lb_algo == LB_ALGO.ROUND_ROBIN then
        return get_peer_using_round_robin(group_id,targets,balancer_wheel_size)
    elseif lb_algo == LB_ALGO.IP_HASH then
        return get_peer_using_remote_ip_hash(group_id,targets)
    else
        ngx_log(ngx_ERR,str_format(log_config.biz_error_format,log_config.ERROR,"balancer execute error, just support round-robin and ip-hash algorithm."))
        return nil, nil
    end
end

--===========================================================
-- Main entry point when resolving
--===========================================================

-- Resolves the balancer_addr structure in-place (field `ip`, port).
--
-- If the hostname matches an 'upstream' pool, then it must be balanced in that pool,
-- in this case any port number provided will be ignored, as the pool provides it.
--
-- @param balancer_addr the data structure as defined in `core.access` phase where it is created
-- @return success + nil, failed + error_information
local function execute(balancer_addr)
    local group_id = balancer_addr.group_id
    local targets = balancer_addr.targets
    ngx_log(ngx_DEBUG,"balancer  targets :",json.encode(targets))
    local balance_algo = balancer_addr.balance_algo
    local balancer_wheel_size = balancer_addr.wheel_size

    if not targets or #targets==0 then
        return false, "targets are empty"
    end

    local ip, port,half_open = get_peer(balance_algo,group_id,targets,balancer_wheel_size)
    ngx.log(ngx.INFO,"perr ip:",ip ,"port:", port,"half_open:",half_open)
    balancer_addr.ip = ip
    balancer_addr.port = port
    balancer_addr.half_open = half_open
    if not ip or not port then
        local msg = "group_id:" .. group_id .. ",targets:" .. json.encode(targets) .. ",balance_algo:" .. balance_algo
        if balancer_wheel_size then
            msg = msg .. ",balancer_wheel_size:" .. balancer_wheel_size
        end
        ngx_log(ngx_ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))
        -- 无可用节点，取第 1个节点
        balancer_addr.ip = targets[1].host
        balancer_addr.port = targets[1].port
       -- return false, "there is no available balancer node which can be selected."
    end
    return true,nil
end

return {
    execute = execute
}
