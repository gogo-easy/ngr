---
--- Copyright (c) 2016-2018 www.mwee.cn & Jacobs Lei 
--- Author: chenghao
--- Date: 2018/07/27
--- Time: 下午6:36
local cjson = require("cjson")
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local utils = require("core.utils.utils")
local user_log = require("core.log.user_log")


local _M = {}

function _M.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select id,limit_count from c_gateway where id = ?",
        params ={
            id
        }
    })
    if info and #info >0 then
        return info[1]
    else
        return nil
    end
end

function _M.query_gateway_by_code(gateway_code, store)
    local _, results, err = store:query({
        sql = "select * from c_gateway where gateway_code = ?",
        params = {gateway_code}
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when query gateway error:", err)
        return false, nil
    end

    if results and type(results) == "table"  then
        return true, results
    end

    return false,nil
end

function _M.query_gateway(req_gateway, store)

    local select_sql = [[
        select
          a.*,
          b.content_type,
          b.message,
          b.plugin_name,
          b.http_status
        from c_gateway a left join c_err_resp_template b on a.id = b.biz_id and b.plugin_name = 'gateway' where 1=1
    ]];
    -- 根据参数动态组装SQL
    local sql,params = dynamicd_build:build_and_condition_like_sql(select_sql,req_gateway)
    local _, results, err = store:query({
        sql = sql,
        params = params
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when query gateway error:", err)
        return false, nil
    end

    if results and type(results) == "table" and #results > 0 then
        return true, results
    end

    return false,nil
end

function _M.insert_gateway(gateway, store)
    ngx.log(ngx.INFO,"insert_gateway...param【"..cjson.encode(gateway).."】")
    return store:insert({
        sql = "insert into c_gateway(gateway_code,gateway_desc) values(?,?)",
        params={
            utils.trim(gateway.gateway_code),
            utils.trim(gateway.gateway_desc)
        }
    })
end

function _M.delete_gateway(id, store)
    local res = store:delete({
        sql = "delete from c_gateway where id = ?",
        params={id}
    })
    return res;
end

function _M.update_gateway_limit(gateway_table,store)
    ngx.log(ngx.INFO,"update_gateway...param【"..cjson.encode(gateway_table).."】")

    user_log.print_log(store,user_log.module.gateway.. "-修改",
            "gateway_dao",gateway_table)

    local res = store:update({
        sql = "UPDATE c_gateway set limit_count =? where id = ?",
        params={
            gateway_table.limit_count,
            gateway_table.id
        }
    })
    return res;
end

function _M.query_gateway_code(store)

    local _, results, err = store:query({
        sql = "select gateway_code from c_gateway"
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when query query_gateway_code error:", err)
        return false, nil
    end

    if results and type(results) == "table" and #results > 0 then
        return true, results
    end

    return false,nil
end

return _M