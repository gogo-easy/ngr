---
--- Author: yusai
--- Date: 2018/9/12
--- Time: 上午10:45

local BaseAPI = require("plugins.base_api")
local common_api = require("plugins.common_api")
local anti_sql_injection_dao = require("core.dao.anti_sql_injection_dao")
local co_parameter_dao = require("core.dao.co_parameter_dao")
local config = require("plugins.anti_sql_injection.config")

local xpcall = xpcall
local debug = debug

local plugin_name = config.plugin_name

local api = BaseAPI:new(plugin_name, 2)
api:merge_apis(common_api(plugin_name))

api.path_prefix = "/" .. plugin_name

local function build_param(req)
    local req_param={}
    if req.query.enable then
        table.insert(req_param,{column="a.enable",value=req.query.enable,is_like=false})
    end

    if req.query.group_id and req.query.group_id ~="" then
        table.insert(req_param,{column="a.group_id",value=req.query.group_id,is_like=false})
    end

    if req.query.database_type and req.query.database_type ~="" then
        table.insert(req_param,{column="a.database_type",value=req.query.database_type,is_like=false})
    end

    if req.query.gateway_code and req.query.gateway_code ~="" then
        table.insert(req_param,{column="d.gateway_code",value=req.query.gateway_code,is_like=false})
    end

    if req.query.gateway_id and req.query.gateway_id ~="" then
        table.insert(req_param,{column="c.gateway_id",value=req.query.gateway_id,is_like=false})
    end

    if req.query.host_id and req.query.host_id ~="" then
        table.insert(req_param,{column="c.id",value=req.query.host_id,is_like=false})
    end

    if req.query.host and req.query.host ~="" then
        table.insert(req_param,{column="c.host",value=req.query.host,is_like=false})
    end
    return req_param;
end

local function only_check(group_id,path,id,store)
    local req_param={}
    table.insert(req_param,{column="a.group_id",value=group_id,is_like=false})
    table.insert(req_param,{column="a.path",value=path,is_like=false})
    local flag,contents = anti_sql_injection_dao.load_anti_sql_injection(store,req_param)

    if contents and #contents > 0 then

        if id then -- 修改时校验
            local content = contents[1]
            if tonumber(id) ~= tonumber(content.id) then
                return true
            end
        else
            return true
        end
    end
    return false
end

local function only_check_parameter(property_type,property_name,biz_id,id,store)
    local contents = co_parameter_dao.load_co_parameter_info(property_type,property_name,biz_id,"anti_sql_injection",store)
    if contents and #contents>0 then

        if id then -- 修改时校验
            local content = contents[1]
            if tonumber(id) ~= tonumber(content.id) then
                return true
            end
        else
            return true
        end
    end
    return false
end
-- 创建 sql 防控注入器
-- {"group_id":143,"path":"/tr/ss/aaa","remark":"大幅度发","enable":1}
api:post(api.path_prefix.."/create",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log(api.path_prefix.."/create",req)
        local data = req.body

        local check_res = only_check(req.body.group_id,req.body.path,req.body.id,store)
        if check_res then
            return res:json({success = false,msg="当前组下path已经存在"})
        end

        local ok,result,id
        ok = xpcall(function ()
            result,id = anti_sql_injection_dao.inster_anti_sql_injection(store,data)
        end ,function ()
            result =false
            ngx.log(ngx.ERR, "create".. api.path_prefix .." error: ", debug.traceback())
        end)
        if result then
            return res:json({success = true,data={id=id}})
        else
            return res:json({success = false,msg="operation failed"})
        end
    end
end)

-- 修改sql 防控器
-- {"group_id":143,"path":"/tr/ss/aaa","remark":"大幅度发","enable":1,"id":1}
api:post(api.path_prefix.."/update",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log(api.path_prefix.."update",req)
        local data = req.body
        if not data.id or data.id =="" then
            return res:json({success = false,msg="'id' Can't be empty"})
        end


        local check_res = only_check(req.body.group_id,req.body.path,req.body.id,store)
        if check_res then
            return res:json({success = false,msg="当前组下path已经存在"})
        end


        local result = anti_sql_injection_dao.update_anti_sql_injection(store,data)

        if not result then
            return res:json({success = false,msg="operation failed"})
        else
            return res:json({success = true,msg="successful"})
        end
    end
end)

api:post(api.path_prefix.."/delete",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log(api.path_prefix.."/delete",req)
        local id = req.body.id
        if id == "" or not id  then
            return res:json({success = false,msg="'id' Can't be empty"})
        else
            local result = anti_sql_injection_dao.delete_anti_sql_injection(store,id)

            if not result then
                return res:json({success = false,msg="operation failed"})
            end

            co_parameter_dao.delete_co_parameter_by_bizid(id,"anti_sql_injection",store)

            return res:json({success = true,msg="successful"})
        end
    end
end)

api:post(api.path_prefix.."/update_enable",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log(api.path_prefix.."/update_enable",req)
        local id = req.body.id
        local enable = req.body.enable

        if id == "" or not id  then
            return res:json({success = false,msg="'id' Can't be empty"})
        end

        if enable =="" or not enable  then
            return res:json({success = false,msg="'enable' Can't be empty"})
        end
        local result = anti_sql_injection_dao.update_enable(store,id,enable)

        if not result then
            return res:json({success = false,msg="operation failed"})
        end
        return res:json({success = true,msg="successful"})
    end
end)

api:get(api.path_prefix.."/query",function (store)
    return function(req,res,next)

        -- 记录日志
        api:print_req_log('query anti_sql_injection',req)

        local flag,content = anti_sql_injection_dao.load_anti_sql_injection(store,build_param(req))

        for _, obj in pairs(content or {}) do
            local parameter_list = co_parameter_dao.load_co_parameter_by_bizid(obj.id,"anti_sql_injection",store)
            if parameter_list and #parameter_list>0 then
                obj["parameter_list"] = parameter_list
            end
        end

        if not flag then
            res:json({success = false,msg="operation failed"})
        else
            res:json({success = true ,data = content})
        end
    end
end)

api:post(api.path_prefix.."/co_parameter/create",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log(api.path_prefix.."/co_parameter/create",req)
        local data = req.body

        local check_res = only_check_parameter(data.property_type,data.property_name,data.biz_id,data.id,store)
        if check_res then
            return res:json({success = false,msg="当前参数已经存在"})
        end

        local ok,result,id
        ok = xpcall(function ()
            result,id = co_parameter_dao.insert_co_parameter("anti_sql_injection",data.biz_id,data.property_type,data.property_name,store)
        end ,function ()
            result =false
            ngx.log(ngx.ERR, "create co_parameter".. api.path_prefix .." error: ", debug.traceback())
        end)
        if result then
            return res:json({success = true,data="successful"})
        else
            return res:json({success = false,msg="operation failed"})
        end
    end
end)

api:post(api.path_prefix.."/co_parameter/update",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log(api.path_prefix.."/co_parameter/update",req)
        local data = req.body

        local check_res = only_check_parameter(data.property_type,data.property_name,data.biz_id,data.id,store)
        if check_res then
            return res:json({success = false,msg="当前参数已经存在"})
        end

        local result = co_parameter_dao.update_co_parameter("anti_sql_injection",data,store)
        if result then
            return res:json({success = true,msg="successful"})
        else
            return res:json({success = false,msg="operation failed"})
        end
    end
end)

api:post(api.path_prefix.."/co_parameter/delete",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log(api.path_prefix.."/co_parameter/delete",req)
        local id = req.body.id
        if id == "" or not id  then
            return res:json({success = false,msg="'id' Can't be empty"})
        else
            local result = co_parameter_dao.delete_co_parameter(id,store)

            if not result then
                return res:json({success = false,msg="operation failed"})
            else
                return res:json({success = true,msg="successful"})
            end
        end
    end
end)

api:get(api.path_prefix.."/co_parameter/query",function (store)
    return function(req,res,next)

        -- 记录日志
        api:print_req_log('query co_parameter',req)

        local content = co_parameter_dao.load_co_parameter_by_bizid(req.query.biz_id,"anti_sql_injection",store)
        res:json({success = true ,data = content})
    end
end)


return api

