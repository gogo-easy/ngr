---
--- Copyright (c) 2016-2018 www.mwee.cn & Jacobs Lei 
--- Author: chenghao
--- Date: 2018/09/01
--- Time: 下午6:36
local cjson = require("cjson")
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local utils = require("core.utils.utils")
local selector_dao = require("core.dao.selector_dao")
local group_target_dao = require("core.dao.group_target_dao")
local condition_dao = require("core.dao.selector_condition_dao")
local user_log = require("core.log.user_log")

local ngx = ngx

local _M = {}

function _M.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select * from c_gray_divide where id = ?",
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

function _M.get_gray_divide_by_group_id(group_id, store)
    local _, results, err = store:query({
        sql = "select a.id,a.gray_divide_name,a.gray_domain,a.selector_id,a.seq_num from c_gray_divide a where a.enable=1 and a.group_id=? order by a.seq_num",
        params = {group_id}
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when query gray divide error:", err)
        return false, nil
    end

    if results and type(results) == "table" and #results > 0 then

        for _,result in ipairs(results) do
            local gray_divide = result
            local selector = selector_dao.load_selector_by_pk(store,gray_divide.selector_id)
            gray_divide.selector = selector or {}
        end
        return true, results
    end

    return false,nil
end

function _M.query_gray_divide(gray_divide_table, store)
    local select_sql = [[select
          a.id,
          a.gray_divide_name,
          a.group_id,
          a.gray_domain,
          a.selector_id,
          a.enable,
          a.seq_num,
          b.group_context,
          b.enable_balancing,
          b.host_id,
          c.gateway_id,
          c.host,
          d.gateway_code,
          e.selector_type
        from c_gray_divide a
          join c_api_group b on a.group_id = b.id
          join c_host c on b.host_id = c.id
          join c_gateway d on c.gateway_id = d.id
          join c_selector e on a.selector_id = e.id
        where 1 = 1]];

    -- 根据参数动态组装SQL
    local sql,params = dynamicd_build:build_and_condition_like_sql(select_sql,gray_divide_table)
    sql  = sql .. ' order by update_at desc';

    local _, results, err = store:query({
        sql = sql,
        params = params
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when query gray divide error:", err)
        return false, nil
    end

    if results and type(results) == "table" and #results > 0 then
        return true, results
    end

    return false,nil
end

function _M.query_gray_divide_by_id(id, store)
    local sql = "select id,gray_divide_name,group_id,gray_domain,selector_id,enable from c_gray_divide where id=?"

    local _, results, err = store:query({
        sql = sql,
        params = {id}
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when query gray divide error:", err)
        return false, nil
    end

    if results and type(results) == "table" and #results > 0 then
        return true, results[1]
    end

    return false,nil

end

function _M.query_gray_divide_and_targets_and_conditions(gray_divide_table, store)
    local flag, results = _M.query_gray_divide(gray_divide_table,store)
    if results then
        for _, v in ipairs(results) do
            local _, group_targets = group_target_dao.query_target_by_gray_divide_id(v.id,store)
            v["group_targets"] = group_targets or {}
            local conditions = condition_dao.load_condition_by_selector_id(store,v.selector_id)
            v["conditions"] = conditions or {}
        end
        return true, results
    end
    return false,nil
end


function _M.insert_gray_divide(gray_divide, store)
    ngx.log(ngx.INFO,"insert_api_group...param【"..cjson.encode(gray_divide).."】")

    user_log.print_log(store,user_log.module.gray_divide .."-新增",nil,gray_divide)

    return store:insert({
        sql = "insert into c_gray_divide(gray_divide_name,group_id,gray_domain,selector_id,enable,seq_num)values (?,?,?,?,?,?)",
        params={
            utils.trim(gray_divide.gray_divide_name),
            utils.trim(gray_divide.group_id),
            utils.trim(gray_divide.gray_domain) or '',
            utils.trim(gray_divide.selector_id),
            utils.trim(gray_divide.enable) or 0,
            utils.trim(gray_divide.seq_num) or 0
        }
    })
end

function _M.updated_gray_divide(gray_divide, store)
    ngx.log(ngx.DEBUG,'updated_gray_divide param:',cjson.encode(gray_divide))

    user_log.print_log(store,user_log.module.gray_divide .."-修改","gray_divide_dao",gray_divide)

    local flag,res = store:query({
        sql = "update c_gray_divide set gray_divide_name=?,group_id=?,gray_domain=?,selector_id=?,enable=?,seq_num=? where id=?",
        params ={gray_divide.gray_divide_name,
                 gray_divide.group_id,
                 gray_divide.gray_domain,
                 gray_divide.selector_id,
                 gray_divide.enable,
                 gray_divide.seq_num or 0,
                 gray_divide.id
        }
    })
    return res
end

function _M.delete_gray_divide_by_id(store, gray_divide_id)

    user_log.print_log(store,user_log.module.gray_divide .."-删除","gray_divide_dao",{id=gray_divide_id})

    local flag,res = store:query({
        sql = "delete from c_gray_divide where id=?",
        params ={gray_divide_id}
    })
    return res
end

function _M.enable_gray_divide(store, data)
    local res = store:update({
        sql = "UPDATE c_gray_divide set enable=? where id = ?",
        params={
            data.enable,
            data.id
        }
    })

    user_log.print_log(store,user_log.module.gray_divide .. (data.enable == "1" and "启用" or "禁用"),
            nil,{id=data.id,enable=data.enable})

    return res;
end


return _M