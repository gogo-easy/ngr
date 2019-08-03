---
--- API服务组请求速率限制管理 RESTFUL API
--- Copyright (c) 2016 - 2018 www.mwee.cn & Jacobs Lei 
--- Author: Jacobs Lei
--- Date: 2018/4/7
--- Time: 上午10:45

local BaseAPI = require("plugins.base_api")
local common_api = require("plugins.common_api")
local group_rate_limit_dao = require("core.dao.group_rate_limit_dao")
local plugin_config =  require("plugins.group_rate_limit.config")
local err_resp_template_dao = require("core.dao.err_resp_template_dao")
local err_resp_template_utils = require("core.utils.err_resp_template_utils")

local plugin_name = plugin_config.name

local api = BaseAPI:new(plugin_name, 2)
api:merge_apis(common_api(plugin_name))

api.path_prefix = "/" .. plugin_name

--[[
    功能：获取组限流信息
    请求方式：post
    请求参数： 参考 c_group_rate_limit 表结构
]]
api:get(api.path_prefix.."/get/:group_id",function (store)
    return function(req,res,next)
        local group_id = req.params.group_id
        api:print_req_log("group_rate_limit/get/", req)
        if not group_id then
            res:json({success = false,msg="api group id is nil."})
            return
        end
        local group_rate_limit = group_rate_limit_dao.get_by_group_id(store,group_id)
        if  group_rate_limit  then
            res:json({success =true, data = group_rate_limit})
        else
            res:json({success = false, msg="api group rate limit configuration is not exist."})
        end
    end
end)

--[[
    功能：新增api group_rate_limit信息
    请求方式：post
    请求参数： 参考 c_group_rate_limit 表结构
]]
api:post(api.path_prefix.."/add",function (store)
    return function(req,res,next)
        api:print_req_log("group_rate_limit/add",req)
        local group_rate_limit = req.body
        local flag,id = group_rate_limit_dao.insert(store,group_rate_limit)
        if not flag then
            res:json({success = false,msg="insert false"})
        else
            local flag,resp_id,err = err_resp_template_utils.create(store,plugin_name,id,group_rate_limit)
            if flag then
                res:json({success = true,msg = "insert success", id = id})
            else
                group_rate_limit_dao.delete(store,id)
                res:json({success = false,msg=err or "insert false"})
            end
        end
    end
end)

--[[
    功能：修改api  group_rate_limit信息,如限流时间周期，限速大小， 禁用启用
    请求方式：post
    请求参数： 参考 c_group_rate_limit 表结构
]]
api:post(api.path_prefix.."/update",function (store)
    return function(req,res,next)
        api:print_req_log("group_rate_limit/update",req)
        local group_rate_limit = req.body

        --1、修改自定义响应信息
        local flag,old_data = err_resp_template_dao.load_err_resp_template(store,plugin_name,group_rate_limit.id)
        local result = err_resp_template_utils.update(store,plugin_name,group_rate_limit.id,group_rate_limit)
        if not result then
            res:json({success = false,msg="update false"})
            return
        end

        --2、修改组限流信息
        result = group_rate_limit_dao.update(store,group_rate_limit)
        if not result then
            if old_data then
                err_resp_template_dao.update(store,old_data,plugin_name)
            else
                err_resp_template_dao.delete(store,group_rate_limit.id,plugin_name)
            end
            res:json({success = false,msg="update false"})
        else
            res:json({success = true,msg = "update success"})
        end
    end
end)

--[[
    功能：删除api  group_rate_limit信息
    请求方式：post
    请求参数： 参考 c_group_rate_limit 表结构
]]
api:post(api.path_prefix.."/delete",function (store)
    return function(req,res,next)
        api:print_req_log("group_rate_limit/delete/",req)
        local group_id = req.body.group_id
        local group_rate_info =  group_rate_limit_dao.get_by_group_id(store,group_id)
        local flag = group_rate_limit_dao.delete(store,group_id)
        if not flag then
            res:json({success = false,msg="delete false"})
        else
            if group_rate_info then
                err_resp_template_utils.delete(store,group_rate_info.id,plugin_name)
            end
            res:json({success = true,msg = "delete success"})
        end
    end
end)


api:post(api.path_prefix.."/add_err_resp_template",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('add_err_resp_template',req)
        local body = req.body

        if not body then
            return res:json({success = false,msg="请输入必填参数"})
        end

        body["plugin_name"] = plugin_name
        local id,err = err_resp_template_utils.add(store,req.body)

        if not id then
            return res:json({success = false,msg=err})
        else
            local data ={id = id}
            return res:json({success = true,data = data})
        end
    end
end)

api:post(api.path_prefix.."/update_err_resp_template",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('update_err_resp_template',req)
        local flag = err_resp_template_dao.update(store,req.body,plugin_name)

        if not flag then
            return  res:json({success = false,msg="operation failed"})
        else
            return res:json({success = true,msg = "successful"})
        end
    end
end)


api:post(api.path_prefix.."/delete_err_resp_template",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('delete_err_resp_template',req)
        if req.body.id == "" or not req.body.id  then
            return res:json({success = false,msg="'id' Can't be empty"})
        else
            local flag = err_resp_template_dao.delete(store,req.body.id,plugin_name)
            if not flag then
                return res:json({success = false,msg="operation failed"})
            else
                return res:json({success = true,msg = "successful"})
            end
        end
    end
end)

api:get(api.path_prefix.."/query_err_resp_template",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('query_err_resp_template',req)
        local biz_id = req.query.biz_id

        if not biz_id then
            return  res:json({success = false,msg="biz_id 不能为空"})
        end

        local flag,content  = err_resp_template_dao.load_err_resp_template(store,plugin_name,biz_id)

        if not flag then
            return  res:json({success = false,msg="operation failed"})
        else
            return res:json({success = true,data = content})
        end
    end
end)


return api