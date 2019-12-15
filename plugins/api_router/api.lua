local BaseAPI = require("plugins.base_api")
local api_route_dao = require("core.dao.api_router_dao")
local err_resp_template_utils = require("core.utils.err_resp_template_utils")
local err_resp_template_dao = require("core.dao.err_resp_template_dao")
local group_target_dao = require("core.dao.group_target_dao")
local config = require("plugins.api_router.config")
local table = table
local plugins_config = require("plugins.plugins_config")
local c_gateway_dao = require("core.dao.gateway_dao")
local c_host_dao = require("core.dao.host_dao")
local gray_divide_dao = require("core.dao.gray_divide_dao")
local selector_dao = require("core.dao.selector_dao")
local condition_dao = require("core.dao.selector_condition_dao")
local xpcall = xpcall
local cjson = require("cjson")

local err_msg ="operation failed";
local success_msg ="successful";

local plugin_name = config.plugin_name

local api = BaseAPI:new(plugin_name, 2)

local function build_param(req)
    local req_param={}
    if req.query.group_context then
        table.insert(req_param,{column="group_context",value=req.query.group_context,is_like=true})
    end

    if req.query.group_name and req.query.group_name ~="" then
        table.insert(req_param,{column="group_name",value=req.query.group_name,is_like=true})
    end

    if req.query.id and req.query.id ~="" then
        table.insert(req_param,{column="c_api_group.id",value=req.query.id,is_like=false})
    end

    if req.query.enable and req.query.enable ~="" then
        table.insert(req_param,{column="c_api_group.enable",value=req.query.enable,is_like=false})
    end

    if req.query.host_id and req.query.host_id ~="" then
        table.insert(req_param,{column="host_id",value=req.query.host_id,is_like=false})
    end

    if req.query.gateway_id and req.query.gateway_id ~="" then
        table.insert(req_param,{column="c_host.gateway_id",value=req.query.gateway_id,is_like=false})
    end


    return req_param;
end

local function build_gateway_param(req)
    local req_param={}
    if req.query.gateway_code then
        table.insert(req_param,{column="gateway_code",value=req.query.gateway_code,is_like=true})
    end

    if req.query.gateway_desc and req.query.gateway_desc ~="" then
        table.insert(req_param,{column="gateway_desc",value=req.query.gateway_desc,is_like=true})
    end
    return req_param;
end

local function build_host_param(req)
    local req_param={}
    if req.query.id and req.query.id ~="" then
        table.insert(req_param,{column="a.id",value=req.query.id,is_like=false})
    end

    if req.query.gateway_id then
        table.insert(req_param,{column="gateway_id",value=req.query.gateway_id,is_like=false})
    end

    if req.query.host and req.query.host ~="" then
        table.insert(req_param,{column="host",value=req.query.host,is_like=true})
    end

    if req.query.host_desc and req.query.host_desc ~="" then
        table.insert(req_param,{column="host_desc",value=req.query.host_desc,is_like=true})
    end

    if req.query.enable and req.query.enable ~="" then
        table.insert(req_param,{column="enable",value=req.query.enable,is_like=false})
    end

    if req.query.gateway_code and req.query.gateway_code ~= ""then
        table.insert(req_param,{column="gateway_code",value=req.query.gateway_code,is_like=false})
    end

    if req.query.gateway_desc and req.query.gateway_desc ~= ""then
        table.insert(req_param,{column="gateway_desc",value=req.query.gateway_desc,is_like=true})
    end

    return req_param;
end

local function build_gray_divide_param(req)
    local req_param={}

    if req.query.gray_divide_name then
        table.insert(req_param,{column="gray_divide_name",value=req.query.gray_divide_name,is_like=true})
    end

    if req.query.gateway_id then
        table.insert(req_param,{column="gateway_id",value=req.query.gateway_id,is_like=false})
    end

    if req.query.host_id then
        table.insert(req_param,{column="host_id",value=req.query.host_id,is_like=false})
    end

    if req.query.group_id then
        table.insert(req_param,{column="group_id",value=req.query.group_id,is_like=false})
    end

    if req.query.enable and req.query.enable ~="" then
        table.insert(req_param,{column="a.enable",value=req.query.enable,is_like=false})
    end

    return req_param;
end

local function build_selector_params(data)
    local selector_params={
        selector_name = data.selector_name,
        selector_type = data.selector_type,
        -- 防火墙关联选择器，选择器enable 肯定为有效
        enable = 1
    }
    return selector_params
end

-- return
-- 存在：true
-- 不存在：false
local function only_check(host_id,group_context,id,store)
    local req_param={}
    table.insert(req_param,{column="group_context",value=group_context,is_like=false})
    table.insert(req_param,{column="host_id",value=host_id,is_like=false})

    local flag,contents = api_route_dao.load_api_group_info(req_param,store)

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


-- return
-- 存在：true
-- 不存在：false
local function only_check_target(group_id,host,port,id,store)
    local flag,contents = group_target_dao.query_target(group_id,host,port,store)

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

-- return
-- 存在：true
-- 不存在：false
local function check_gateway_unique(gateway_code,store)
    local flag,contents = c_gateway_dao.query_gateway_by_code(gateway_code,store)

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

local function check_host_unique(host,id,store)
    local flag,contents = c_host_dao.query_host_by_host_name(host,store)

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


local function build_result(result,res)
    if result then
        return res:json({success = true,msg="successful"})
    else
        return res:json({success = false,msg="operation failed"})
    end
end

--[[
    功能：根据传入条件，查询api group信息
    请求方式：get
    请求参数：
        group_name  API组名称/服务名 (非必传)
        group_context  API组上下文（非必传）
        enable 是否启用（1 启用，0 未启用）
        id
    -- 例如：
    --    查询所有：http://localhost:7777/api_router/query_api_group
    --    按ID查询：http://localhost:7777/api_router/query_api_group?id=1
    --    按code查询：http://localhost:7777/api_router/query_api_group?group_name=test
    --    按code及context查询：http://localhost:7777/api_router/query_api_group?group_name=test&group_context=mytest
]]
api:get("/api_router/query_api_group",function (store)
    return function(req,res,next)

        -- 记录日志
        api:print_req_log('query_api_group',req)

        local flag,content = api_route_dao.load_api_group_info(build_param(req),store)

        if not flag then
            res:json({success = false,msg=err_msg})
        else
            res:json({success = true ,data = content})
        end
    end
end)

api:get("/api_router/query_simple_group_info",function (store)
    return function(req,res,next)

        -- 记录日志
        api:print_req_log('query_simple_group_info',req)

        local flag,content = api_route_dao.query_simple_group_info(store,req)

        if not flag then
            res:json({success = false,msg=err_msg})
        else
            res:json({success = true ,data = content})
        end
    end
end)

--[[
    功能：根据传入条件，查询api group信息,包含group_rate_limit信息
    请求方式：get
    请求参数：
        group_name  API组名称/服务名 (非必传)
        group_context  API组上下文（非必传）
        enable 是否启用（1 启用，0 未启用）
        id
    -- 例如：
    --    查询所有：http://localhost:7777/api_router/query_api_group
    --    按ID查询：http://localhost:7777/api_router/query_api_group?id=1
    --    按code查询：http://localhost:7777/api_router/query_api_group?group_name=test
    --    按code及context查询：http://localhost:7777/api_router/query_api_group?group_name=test&group_context=mytest
]]
api:get("/api_router/query_api_group_rate_limit",function (store)
    return function(req,res,next)

        -- 记录日志
        api:print_req_log('query_api_group_rate_limit',req)

        local flag,content = api_route_dao.load_api_group_and_rate_limit(build_param(req),store,req.query.ip)

        if not flag then
            return res:json({success = false,msg=err_msg})
        else
            return res:json({success = true ,data = content})
        end
    end
end)

--[[
    功能：新增api group信息
    请求方式：post
    请求参数： 参考 c_api_group 表结构
]]
api:post("/api_router/add_api_group",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('query_api_group',req)

        -- 唯一性
        local check_res = only_check(req.body.host_id,req.body.group_context,req.body.id,store)

        if check_res then
            -- 前端要求这种格式
            return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="group_context已存在"})
        end

        local flag,id = api_route_dao.insert_api_group(req.body,store)

        if not flag then
            res:json({success = false,msg=err_msg})
        else
            local err
            flag,_,err = err_resp_template_utils.create(store,plugin_name,id,req.body)
            if flag then
                local data ={id = id}
               return res:json({success = true,data = data})
            else
                return res:json({success = false,msg=err or err_msg})
            end
        end
    end
end)

--[[
    功能：修改api group信息
    请求方式：post
    请求参数： 参考 c_api_group 表结构
]]
api:post("/api_router/update_api_group",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('update_api_group',req)

        if not req.body.id then
            res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="id 字段不能为空"})
        else

            -- 唯一性
            local check_res = only_check(req.body.host_id,req.body.group_context,req.body.id,store)

            if check_res then
                -- 前端要求这种格式
                return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="group_context已存在"})
            end
            -- 1、修改自定义错误信息
            local flag,old_data =err_resp_template_dao.load_err_resp_template(store,plugin_name,req.body.id)

           flag = err_resp_template_utils.update(store,plugin_name,req.body.id,req.body)
            if not flag then
                return res:json({success = false,msg=err_msg})
            end
            --2、修改api group 信息
            local flag = api_route_dao.update_api_group(req.body,store)

            if not flag then
                if old_data then
                    err_resp_template_dao.update(store,old_data,plugin_name)
                else
                    err_resp_template_dao.delete(store,req.body.id,plugin_name)
                end
                res:json({success = false,msg=err_msg})
            else
                res:json({success = true,msg = success_msg})
            end

        end
    end
end)

--[[
    功能：删除api group信息
    请求方式：post
    请求参数：id 主键
]]
api:post("/api_router/delete_api_group",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('delete_api_group',req)
        if req.body.id == "" or not req.body.id  then
            return res:json({success = false,msg="'id' Can't be empty"})
        else
            local flag = api_route_dao.delete_api_group(req.body.id,store)
            if not flag then
                return res:json({success = false,msg=err_msg})
            else
                err_resp_template_utils.delete(store,req.body.id,plugin_name)
                return res:json({success = true,msg = success_msg})
            end
        end
    end
end)

api:post("/api_router/enable_api_group",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('enable api group',req)

        local body = req.body

        local flag = api_route_dao.update_api_group_enable(body, store)

        if flag then
            return res:json({success = true,msg = success_msg})
        else
            return res:json({success = false,msg=err_msg})
        end
    end
end)

api:post("/api_router/add_target",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('add_target',req)

        local body = req.body
        if only_check_target(body.group_id,body.host,body.port,body.id,store) then
            return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="target信息已存在"})
        end

       local flag,id = group_target_dao.insert(body,store)

        if flag then
            return res:json({success = true,data = {id = id}})
        else
            return res:json({success = false,msg=err_msg})
        end
    end
end)

api:post("/api_router/update_target",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('update_target',req)

        local body = req.body
        if only_check_target(body.group_id,body.host,body.port,body.id,store) then
            return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="target信息已存在"})
        end

        local flag = group_target_dao.update(body,store)

        if flag then
            return res:json({success = true,msg = success_msg})
        else
            return res:json({success = false,msg=err_msg})
        end
    end
end)

api:post("/api_router/delete_target",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('delete_target',req)
        local id = req.body.id

        if not id then
            return res:json({success = false,msg="'id' Can't be empty"})
        end

        local flag,results = group_target_dao.query_rel_gray_target_by_target_id(id, store)

        if flag ==true then
            if #results ==0 then
                flag = group_target_dao.delete(id,store)
            else
                return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="请先在AB分流器中删除"})
            end
        end

        if flag then
            return res:json({success = true,msg = success_msg})
        else
            return res:json({success = false,msg=err_msg})
        end
    end
end)

api:get("/api_router/query_target",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('query_target',req)
        local group_id = req.query.group_id

        if not group_id then
            return res:json({success = false,msg="'group_id' Can't be empty"})
        end

        local flag,data = group_target_dao.query_target_and_gray_divide_count_by_group_id(group_id,store)

        if flag then
            return res:json({success = true,data =data})
        else
            return res:json({success = false,msg=err_msg})
        end
    end
end)

api:post("/api_router/enable_target",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('enable target',req)

        local body = req.body
        local flag,results
        if tonumber(body.enable) == 0 then
           flag,results = group_target_dao.query_rel_gray_target_by_target_id(body.id, store)
            if flag ==true then
                if #results ==0 then
                    flag = group_target_dao.update_target_enable(body, store)
                else
                    return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="请先在AB分流器中删除"})
                end
            end
        else
            flag = group_target_dao.update_target_enable(body, store)
        end

        if flag then
            return res:json({success = true,msg = success_msg})
        else
            return res:json({success = false,msg=err_msg})
        end
    end
end)

api:post("/api_router/add_err_resp_template",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('add_err_resp_template',req)
        local body = req.body

        if not body then
            return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="请输入必填参数"})
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

api:post("/api_router/update_err_resp_template",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('update_err_resp_template',req)
        local flag = err_resp_template_dao.update(store,req.body,plugin_name)

        if not flag then
            return  res:json({success = false,msg=err_msg})
        else
            return res:json({success = true,msg = success_msg})
        end
    end
end)


api:post("/api_router/delete_err_resp_template",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('delete_err_resp_template',req)
        if req.body.id == "" or not req.body.id  then
            return res:json({success = false,msg="'id' Can't be empty"})
        else
            local flag = err_resp_template_dao.delete(store,req.body.id,plugin_name)
            if not flag then
                return res:json({success = false,msg=err_msg})
            else
                return res:json({success = true,msg = success_msg})
            end
        end
    end
end)

api:get("/api_router/query_err_resp_template",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('query_err_resp_template',req)
        local biz_id = req.query.biz_id

        if not biz_id then
            return  res:json({success = false,msg="biz_id 不能为空"})
        end

        local flag,content  =  err_resp_template_dao.load_err_resp_template(store,plugin_name,biz_id)

        if not flag then
            return  res:json({success = false,msg=err_msg})
        else
            return res:json({success = true,data = content})
        end
    end
end)


api:get("/gateway/query",function (store)
    return function(req,res,next)

        -- 记录日志
        api:print_req_log('query gateway',req)

        local flag,content = c_gateway_dao.query_gateway(build_gateway_param(req),store)

        if not flag then
            res:json({success = false,msg=err_msg})
        else
            res:json({success = true ,data = content})
        end
    end
end)

api:post("/gateway/add",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('add gateway',req)
        -- 唯一性
        local check_res = check_gateway_unique(req.body.gateway_code,store)

        if check_res then
            -- 前端要求这种格式
            return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="网关编码已存在"})
        end

        local body = req.body
        if not body.limit_count then
            return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="QPS限流阀值不能为空!"})
        end

        local flag,id = c_gateway_dao.insert_gateway(body, store)
        if not flag then
            res:json({success = false,msg=err_msg})
        else
            local err
            flag,_,err = err_resp_template_utils.create(store,"gateway",id,body)
            if flag then
                local data ={id = id}
                return res:json({success = true,data = data})
            else
                return res:json({success = false,msg=err or err_msg})
            end
        end
    end
end)

api:post("/gateway/set_limit_count",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('update gateway',req)

        local body = req.body
        if not body.limit_count then
            return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="QPS限流阀值不能为空!"})
        end

        local flag = c_gateway_dao.update_gateway_limit(body,store)
        if not flag then
            return res:json({success = false,msg=err_msg})
        else
            local err
            flag,_,err = err_resp_template_utils.update(store,"gateway",body.id,req.body)
            if flag then
                return res:json({success = true,msg = success_msg})
            else
                return res:json({success = false,msg=err or err_msg})
            end
        end
    end
end)

api:post("/gateway/delete",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('delete gateway',req)
        if req.body.id == "" or not req.body.id  then
            return res:json({success = false,msg="'id' Can't be empty"})
        else

            local flag = c_gateway_dao.delete_gateway(req.body.id,store)
            if not flag then
                return res:json({success = false,msg=err_msg})
            else
                return res:json({success = true,msg = success_msg})
            end
        end
    end
end)

api:get("/host/query",function (store)
    return function(req,res,next)

        -- 记录日志
        api:print_req_log('query host',req)

        local flag,content = c_host_dao.query_host(build_host_param(req),store)

        if not flag then
            res:json({success = false,msg=err_msg})
        else
            res:json({success = true ,data = content})
        end
    end
end)

api:post("/host/add",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('add host',req)
        -- 唯一性
        local check_res = check_host_unique(req.body.host,store)

        if check_res then
            -- 前端要求这种格式
            return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="主机域名已存在"})
        end

        local flag,id = c_host_dao.insert_host(req.body, store)

        if not flag then
            res:json({success = false,msg=err_msg})
        else
            return res:json({success = true, data = {id = id}})
        end
    end
end)

api:post("/host/set_limit_count",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('set_limit_count host',req)

        local body = req.body
        if not body.limit_count then
            return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="QPS不能为空"})
        end
        local flag = c_host_dao.update_host_limit_count(body,store)
        if not flag then
            return res:json({success = false,msg=err_msg})
        else
            local err
            flag,_,err = err_resp_template_utils.update(store,"host",body.id,req.body)
            if flag then
                return res:json({success = true,msg = success_msg})
            else
                return res:json({success = false,msg=err or err_msg})
            end
        end
    end
end)

api:post("/host/update",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('update host',req)

        local body = req.body
        if check_host_unique(body.host, body.id, store) then
            return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="host信息已存在"})
        end

        local flag = c_host_dao.update_host(body,store)

        if flag then
            return res:json({success = true,msg = success_msg})
        else
            return res:json({success = false,msg=err_msg})
        end
    end
end)

api:post("/host/enable",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('enable host',req)

        local body = req.body

        local flag = c_host_dao.update_host_enable(body,store)

        if flag then
            return res:json({success = true,msg = success_msg})
        else
            return res:json({success = false,msg=err_msg})
        end
    end
end)

api:post("/host/delete",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('delete host',req)
        if req.body.id == "" or not req.body.id  then
            return res:json({success = false,msg="'id' Can't be empty"})
        else


            local flag = c_host_dao.delete_host(req.body.id, store)
            if not flag then
                return res:json({success = false,msg=err_msg})
            else
                return res:json({success = true,msg = success_msg})
            end
        end
    end
end)

-- 灰度分流器
api:get("/gray_divide/query",function (store)
    return function(req,res,next)

        -- 记录日志
        api:print_req_log('query gray divide ',req)

        local flag, contents = gray_divide_dao.query_gray_divide_and_targets_and_conditions(build_gray_divide_param(req),store)

        if not flag then
            res:json({success = false,msg=err_msg})
        else
            res:json({success = true ,data = contents })
        end
    end
end)

api:post("/gray_divide/add",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('add gray divide',req)

        local data = req.body

        local result,gray_divide_id,selector_id
        -- 1、新增选择器
        result,selector_id = selector_dao.create_selector(store,build_selector_params(data))

        if selector_id then

            -- 2. 新增灰度分流器
            data["selector_id"]=selector_id
            ok = xpcall(function ()
                result,gray_divide_id = gray_divide_dao.insert_gray_divide(data,store)
            end ,function ()
                result =false
                ngx.log(ngx.ERR, "create gray divide error: ", debug.traceback())
            end)

            if not gray_divide_id then
                selector_dao.delete_selector(store,selector_id)
                return res:json({success = false,msg="operation failed"})
            else

                local group_targets = cjson.decode(data.group_targets);
                for _, target_id in ipairs(group_targets or {}) do
                    group_target_dao.insert_rel_gray_target(gray_divide_id,target_id,store)
                end
            end
        end

        if result then
            return res:json({success = true,data={id=gray_divide_id}})
        else
            return res:json({success = false,msg="operation failed"})
        end
    end
end)

api:post("/gray_divide/update",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('update gray_divide',req)
        local data = req.body
        if not data.id or data.id =="" then
            return res:json({success = false,msg="'id' Can't be empty"})
        end

        --1、获取对应的选择器id
        local flag,gray_divide = gray_divide_dao.query_gray_divide_by_id(data.id, store)
        if not gray_divide then
            return res:json({success = false,msg="operation failed"})
        end

        local selector_data={
            selector_name = data.selector_name,
            selector_type = data.selector_type,
            id = gray_divide.selector_id,
            -- 防火墙关联选择器，选择器enable 肯定为有效
            enable = 1
        }
        -- 2、更新选择器
        local result= selector_dao.update_selector(store,selector_data)

        data.selector_id=gray_divide.selector_id
        -- 3、更新分流器
        if result then
            result = gray_divide_dao.updated_gray_divide(data,store)

            -- 4. 更新target
            group_target_dao.reset_target(gray_divide.id, store)

            local group_targets = cjson.decode(data.group_targets);
            for _, target_id in ipairs(group_targets) do
                group_target_dao.insert_rel_gray_target(gray_divide.id,target_id,store)
            end
        end

        return build_result(result,res)
    end
end)

api:post("/gray_divide/delete", function (store)
    return function(req, res, next)
        -- 记录日志
        api:print_req_log('delete gray_divide',req)

        local data = req.body
        if not data.id or data.id =="" then
            return res:json({success = false,msg="'id' Can't be empty"})
        end


        --1、获取对应的选择器id
        local result,gray_divide = gray_divide_dao.query_gray_divide_by_id(data.id, store)
        if not gray_divide then
            return res:json({success = false,msg="operation failed"})
        end

        -- 1、删除分流器
        local result = gray_divide_dao.delete_gray_divide_by_id(store, gray_divide.id)

        if result then

            -- 2、删除条件
            condition_dao.delete_conditions_of_selector(store,gray_divide.selector_id)

            -- 3、删除选择器
            selector_dao.delete_selector(store,gray_divide.selector_id)

            -- 4.重置target
            group_target_dao.reset_target(gray_divide.id, store)
        end
        build_result(result,res)
    end
end)

api:post("/gray_divide/enable",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('enable gray_divide',req)
        local data = req.body
        if not data.id or data.id =="" then
            return res:json({success = false,msg="'id' Can't be empty"})
        end

        local result = gray_divide_dao.enable_gray_divide(store,data)

        return build_result(result,res)
    end
end)

-- 筛选条件
api:post("/selector_condition/add",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('add selector condition',req)

        local data = req.body

        if not data.selector_id or data.selector_id =="" then
            return res:json({success = false,msg="'selector_id' Can't be empty at the same time"})
        end

        local selector_id = data.selector_id

        -- 重复性校验
        local flag,err = condition_dao.check_repeat(store,data)

        if not flag then
            return res:json({success = false,msg=err})
        end

        local result,cond_id = condition_dao.create_condition(store,data)
        if result then
            return res:json({success = true,data={id=cond_id}})
        else
            return res:json({success = false,msg="operation failed"})
        end
    end
end)

api:post("/selector_condition/update",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('updated_selector',req)
        local data = req.body
        if data.id == "" or not data.id then
            return res:json({success = false,msg="'id' Can't be empty"})
        end
        local selector_id,err = condition_dao.get_selector_id_by_id(store,data.id)
        if err then
            ngx.log(ngx.ERR,"updated_condition get_selector_id_by_id err:",err)
            return res:json({success = false,msg="operation failed"})
        end
        data["selector_id"] = selector_id

        -- 重复性校验
        local flag,err = condition_dao.check_repeat(store,data)

        if not flag then
            return res:json({success = false,msg=err})
        end

        local result = condition_dao.update_condition(store,data)

        return build_result(result,res)
    end
end)

api:post("/selector_condition/delete_by_id",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('delete_condition_by_id',req)
        if not req.body.id or req.body.id == "" then
            return res:json({success = false,msg="'id' Can't be empty"})
        end

        local result = condition_dao.delete_conditions_by_id(store,req.body.id)
        if result then
            local count_num = condition_dao.count_condition_by_selectorid(store,req.body.selector_id)
            if count_num and tonumber(count_num) == 0 then
                local data = {
                    enable = 0,
                    id = req.body.gd_id
                }
                gray_divide_dao.enable_gray_divide(store,data)
            end
        end

        return build_result(result,res)
    end
end)



api:post("/api_router/add_target_list",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('add_target_list',req)
        local err_data={}
        local bodys = req.body
        local res_flag = false;
        if bodys and #bodys > 0 then
            local json = require("cjson")
            for _, body in ipairs(bodys) do
                if only_check_target(body.group_id,body.host,body.port,body.id,store) then
                    ngx.log(ngx.ERR,"add target fail group id=",body.group_id,",host=",body.host,",port=",body.port," 节点信息已存在")
                    table.insert(err_data,{host=body.host,port=body.port,flag=false,msg="节点信息已存在"})
                    --return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="target信息已存在"})
                else
                    local flag,id = group_target_dao.insert(body,store)
                    if not flag then
                        table.insert(err_data,{host=body.host,port=body.port,flag=false,msg="添加失败"})
                    else
                        res_flag = true
                    end

                end
            end
        else
            return res:json({success = false,msg="参数为空"})
        end
        if res_flag then
            return res:json({success = true,err_data = err_data})
        else
            return res:json({success = false,err_data = err_data})
        end
    end
end)



return api