local cjson = require("cjson")
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local utils = require("core.utils.utils")
local user_log = require("core.log.user_log")

local _M = {}

local function get_current_time()
    local current_time = os.date('*t', ngx.now())
    current_time = current_time.year..'-'..current_time.month..'-'..current_time.day..' '..current_time.hour..':'..current_time.min..':'..current_time.sec
    return current_time
end

function _M.register_renew_instance(gateway_id, address, store)
    local _, results, err = store:query({
        sql = "select id from c_gateway_instance where address=?",
        params ={
            address
        }
    })
    local current_time = get_current_time()
    if results and #results >0 then
        local _, results, err = store:query({
            sql = "update c_gateway_instance set renew_time=? where address=?",
            params ={
                current_time,
                address
            }
        })
    else
        local _, results, err = store:query({
            sql = "insert into c_gateway_instance (gateway_id, address, register_time, renew_time) VALUES (?,?,?,?)",
            params ={
                gateway_id,
                address,
                current_time,
                current_time
            }

        })
    end
end

function _M.unregister_instance(cluster_name, address, store)
    local _, results, err = store:query({
        sql = "delete from c_gateway_instance where gateway_id=?, address=?",
        params = {
            cluster_name,
            address
        }
    })
end

function _M.check_timeout_instance(store)
    local _, results, err = store:query({
        sql = "delete from c_gateway_instance where renew_time < ?"
    })
end

-- query instance details
-- @param store
-- @param gateway_id
-- @return a list of instances detail of the specified gateway_id, including gateway_id, address of instance, register_time, renew_time, status 
-- field 'status' doesn't include in db, it depends on register interval, status=0 if current_time >= 2*register_interval + renew_time else status=1
function _M.instances(gateway_id, store)
end

return _M