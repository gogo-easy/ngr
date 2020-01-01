local cjson = require("cjson")
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local utils = require("core.utils.utils")
local user_log = require("core.log.user_log")
local _M = {}

function _M.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select id,limit_count from c_host where id = ?",
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

function _M.query_host_by_host_name(host, store)
    local _, results, err = store:query({
        sql = "select * from c_host where host = ?",
        params = {host}
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when query host error:", err)
        return false, nil
    end

    if results and type(results) == "table"  then
        return true, results
    end

    return false,nil
end


function _M.query_rate_limit_by_host(host, store)
    local _, results, err = store:query({
        sql = "select a.id host_id,a.gateway_id,a.limit_count host_limit_count,a.limit_period host_limit_period,b.limit_count gateway_limit_count,b.limit_period gateway_limit_period,b.gateway_code from c_host a join c_gateway b on a.gateway_id=b.id where a.host=?",
        params = {host}
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when query rate limit by host error:", err)
        return false, nil
    end

    if results and type(results) == "table"  then
        return true, results
    end

    return false,nil

end

function _M.query_host(req_host, store)
    local select_sql = [[
        select
          a.*,
          b.gateway_code,
          b.gateway_desc,
          c.content_type,
          c.message,
          c.http_status
        from c_host a
          join c_gateway b on a.gateway_id = b.id

    ]];
    local suffix = " left join c_err_resp_template c on a.id = c.biz_id and c.plugin_name = 'host'"

    -- 根据参数动态组装SQL
    local sql,params = dynamicd_build:build_and_condition_like_sql(select_sql,req_host)
    sql = sql .. suffix
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

function _M.insert_host(host_table, store)
    ngx.log(ngx.INFO,"insert_host...param【"..cjson.encode(host_table).."】")
    return store:insert({
        sql = "insert into c_host(gateway_id, host, host_desc,enable, limit_count, limit_period) values(?,?,?,?,?,?)",
        params={
            utils.trim(host_table.gateway_id),
            utils.trim(host_table.host),
            utils.trim(host_table.host_desc),
            utils.trim(host_table.enable or 0),
            utils.trim(host_table.limit_count ),
            utils.trim(host_table.limit_period or 1)
        }
    })
end

function _M.delete_host(id, store)
    local res = store:delete({
        sql = "delete from c_host where id = ?",
        params={id}
    })
    return res;
end

function _M.update_host(host_table, store)
    ngx.log(ngx.INFO,"update_host...param【"..cjson.encode(host_table).."】")
    local res = store:update({
        sql = "UPDATE c_host set gateway_id=?,host=?,host_desc=? where id = ?",
        params={
            host_table.gateway_id,
            host_table.host,
            host_table.host_desc,
            host_table.id
        }
    })
    return res;
end

function _M.update_host_limit_count(host_table, store)
    ngx.log(ngx.INFO,"update_host...param【"..cjson.encode(host_table).."】")

    user_log.print_log(store,user_log.module.host.. "-修改",
            "host_dao",host_table)

    local res = store:update({
        sql = "UPDATE c_host set host_desc=?, limit_count=? where id = ?",
        params={
            host_table.host_desc or "",
            host_table.limit_count,
            host_table.id
        }
    })
    return res;
end

function _M.update_host_enable(host_table, store)
    ngx.log(ngx.INFO,"update_host...param【"..cjson.encode(host_table).."】")
    local res = store:update({
        sql = "UPDATE c_host set enable=? where id = ?",
        params={
            host_table.enable,
            host_table.id
        }
    })
    return res;
end

return _M