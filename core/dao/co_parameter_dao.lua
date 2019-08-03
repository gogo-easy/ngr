---
--- Created by yusai.
--- DateTime: 2018/9/10 上午10:14
---

local _M = {}

local utils = require("core.utils.utils")
local cjson = require("cjson")
local user_log = require("core.log.user_log")

function _M.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select * from c_co_parameter where id = ?",
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

function _M.load_co_parameter_by_bizid(biz_id,plugin_name,store)
    local flag,parameter_list = store:query({
        sql = "select id,plugin_name,biz_id,property_type,property_name from c_co_parameter where biz_id = ? and plugin_name = ?",
        params ={biz_id,plugin_name}
    })
    return parameter_list
end


function _M.load_co_parameter_info(property_type,property_name,biz_id,plugin_name,store)
    local flag,property_list = store:query({
        sql = "select id,biz_id,property_type,property_name from c_co_parameter where biz_id = ? and property_type=? and property_name = ? and plugin_name =?",
        params ={biz_id,
                 property_type,
                 property_name,
                 plugin_name
        }
    })
    return property_list
end


function _M.count_property_detail(prl_id,plugin_name,store)
    local flag,_count = store:query({
        sql = "select count(1) as rows from c_co_parameter where biz_id = ? and plugin_name =? ",
        params ={prl_id,plugin_name }
    })
    if _count and #_count > 0 then
        return _count[1].rows
    end
    return nil
end


function _M.insert_co_parameter(plugin_name,biz_id,property_type,property_name,store)
    ngx.log(ngx.DEBUG,"insert c_co_parameter...param["..cjson.encode(co_parameter).."]")
    local res,id = store:insert({
        sql = "INSERT INTO `c_co_parameter`(`plugin_name`,biz_id,`property_type`,`property_name`) VALUES(?,?,?,?)",
        params={
            plugin_name,
            utils.trim(biz_id),
            utils.trim(property_type),
            utils.trim(property_name)
        }
    })

    user_log.print_log(store,plugin_name .. "关联参数-新增",nil,{
        plugin_name = plugin_name,
        biz_id = biz_id,
        property_type = property_type,
        property_name = property_name
    })

    return res,id
end

function _M.update_co_parameter(plugin_name,co_parameter,store)
    ngx.log(ngx.DEBUG,"update c_co_parameter...param["..cjson.encode(co_parameter).."]")

    user_log.print_log(store,plugin_name .. "关联参数-修改","co_parameter_dao",co_parameter)

    local res = store : update ({
        sql = "UPDATE `c_co_parameter` SET `property_type` = ?,`property_name` = ?,biz_id = ?,update_at =sysdate()  WHERE `id` = ?",
        params = {
            co_parameter.property_type,
            co_parameter.property_name,
            co_parameter.biz_id,
            co_parameter.id
        }
    })
    return res
end


function _M.delete_co_parameter(id,store)
    ngx.log(ngx.DEBUG,"delete c_co_parameter...param["..id.."]")

    user_log.print_log(store,"关联参数-删除","co_parameter_dao",{id=id})

    local res = store : delete ({
        sql = "delete from `c_co_parameter` where `id` = ?",
        params = {id }
    })
    return res
end

function _M.delete_co_parameter_by_bizid(biz_id,plugin_name,store)
    ngx.log(ngx.DEBUG,"delete c_co_parameter...param[biz_id:"..biz_id..",plugin_name:"..plugin_name.."]")
    user_log.print_log(store,"关联参数-删除",nil,{biz_id=biz_id})
    local res = store : delete ({
        sql = "delete from `c_co_parameter` where `biz_id` = ? and plugin_name = ?",
        params = {biz_id,plugin_name }
    })
    return res
end



return _M