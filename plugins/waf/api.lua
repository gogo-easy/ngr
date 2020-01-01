---
--- Copyright (c) GoGo Easy Team & Jacobs Lei
--- Author: Jacobs Lei
--- Date: 2018/4/7
--- Time: 上午10:45

local BaseAPI = require("plugins.base_api")
local common_api = require("plugins.common_api")
local selector_dao = require("core.dao.selector_dao")
local waf_dao = require("core.dao.waf_dao")
local condition_dao = require("core.dao.selector_condition_dao")
local config = require("plugins.waf.config")
local err_resp_template_dao = require("core.dao.err_resp_template_dao")
local err_resp_template_utils = require("core.utils.err_resp_template_utils")

local xpcall = xpcall
local debug = debug

local plugin_name = config.plugin_name

local api = BaseAPI:new(plugin_name, 2)
api:merge_apis(common_api(plugin_name))



local function build_param(req)
    local req_param={}
    if req.query.enable then
        table.insert(req_param,{column="p_waf.enable",value=req.query.enable,is_like=false})
    end

    if req.query.name and req.query.name ~="" then
        table.insert(req_param,{column="name",value=req.query.name,is_like=true})
    end

    if req.query.id and req.query.id ~="" then
        table.insert(req_param,{column="p_waf.id",value=req.query.id,is_like=false})
    end

    if req.query.is_allowed and req.query.is_allowed ~="" then
        table.insert(req_param,{column="is_allowed",value=req.query.is_allowed,is_like=false})
    end

    if req.query.selector_name and req.query.selector_name ~="" then
        table.insert(req_param,{column="selector_name",value=req.query.selector_name,is_like=true})
    end

    if req.query.selector_type and req.query.selector_type ~="" then
        table.insert(req_param,{column="selector_type",value=req.query.selector_type,is_like=false})
    end

    if req.query.host_id and req.query.host_id ~="" then
        table.insert(req_param,{column="p_waf.host_id",value=req.query.host_id,is_like=false})
    end

    if req.query.host and req.query.host ~="" then
        table.insert(req_param,{column="c_host.host",value=req.query.host,is_like=false})
    end

    if req.query.gateway_id and req.query.gateway_id ~="" then
        table.insert(req_param,{column="c_host.gateway_id",value=req.query.gateway_id,is_like=false})
    end

    return req_param;
end

local function build_condition_param(req)
    local req_param={}
    if req.query.selector_id then
        req_param["selector_id"] = req.query.selector_id
    end

    if req.query.param_type and req.query.param_type ~="" then
        req_param["param_type"] = req.query.param_type
    end

    if req.query.id and req.query.id ~="" then
        req_param["id"] = req.query.id
    end

    if req.query.condition_opt_type and req.query.condition_opt_type ~="" then
        req_param["condition_opt_type"] = req.query.condition_opt_type
    end
    return req_param;
end


local function build_result(result,res)
    if result then
        return res:json({success = true,msg="successful"})
    else
        return res:json({success = false,msg="operation failed"})
    end
end

-- 添加防火墙
-- 参数：
-- {"name":"query_body防火墙3","is_allowed":0,"enable":1,"need_log":1,"selector_name":"单条件选择器","selector_type":"1","content_type":"text/xml","message":"<xml><name>防火墙命中错误信息</name><age>23</age></xml>","host_id":1}
api:post("/waf/create_waf",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('create_waf',req)
        local data = req.body

        local ok,result,waf_id,selector_id
        -- 1、新增选择器
         result,selector_id = selector_dao.create_selector(store,data)

        ngx.log(ngx.DEBUG,"selector_id:",selector_id)

        if selector_id then
            data["selector_id"]=selector_id
            -- 2、新增防火墙
            ok = xpcall(function ()
                result,waf_id = waf_dao.insert_waf(store,data)
            end ,function ()
                result =false
                ngx.log(ngx.ERR, "create_waf error: ", debug.traceback())
            end)

            if not waf_id then
                selector_dao.delete_selector(store,selector_id)
                return res:json({success = false,msg="operation failed"})
            end
            -- 3、新增错误信息
            local id,err
            ok = xpcall(function ()
                result,id,err = err_resp_template_utils.create(store,plugin_name,waf_id,data)
            end ,function ()
                result =false
                ngx.log(ngx.ERR, "create_waf error: ", debug.traceback())
            end)

            if not result then
                waf_dao.delete_waf(store,waf_id)
                selector_dao.delete_selector(store,selector_id)
                return res:json({success = false,msg=err or "operation failed"})
            end
        end

        if result then
            return res:json({success = true,data={id=waf_id}})
        else
            return res:json({success = false,msg="operation failed"})
        end
    end
end)

-- update防火墙
-- 参数：
-- {"id":"1","name":"防火墙","is_allowed":0,"enable":1,"selector_name":"单条件选择器","selector_type":"1"}
api:post("/waf/update_waf",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('update_waf',req)
        local data = req.body
        if not data.id or data.id =="" then
            return res:json({success = false,msg="'id' Can't be empty"})
        end
        --1、获取防火墙对应的选择器id
        local simple_wafs = waf_dao.load_waf_simple_info(store,data.id)

        if not simple_wafs then
            return res:json({success = false,msg="operation failed"})
        end

        local simple_waf = simple_wafs[1]

        local selector_data={
            selector_name = data.selector_name,
            selector_type = data.selector_type,
            id = simple_waf.selector_id,
            -- 防火墙关联选择器，选择器enable 肯定为有效
            enable = 1
        }
        -- 2、更新选择器
        local result= selector_dao.update_selector(store,selector_data)

        -- 3、更新防火墙
        if result then
            result = waf_dao.updated_waf(store,data)
        end

        -- 4、更新错误信息
        if result then
           result = err_resp_template_utils.update(store,plugin_name,data.id,data)
        end

        return build_result(result,res)
    end
end)


api:post("/waf/update_enable",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('update_enable',req)
        local data = req.body
        if not data.id or data.id =="" then
            return res:json({success = false,msg="'id' Can't be empty"})
        end

        if not data.enable or data.enable =="" then
            return res:json({success = false,msg="'enable' Can't be empty"})
        end

        local result= waf_dao.updated_enable(store,data.enable,data.id)
        return build_result(result,res)
    end
end)

-- load防火墙
-- 参数：
api:get("/waf/query_waf",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('query_waf',req)

        local content = waf_dao.load_waf_and_condition(store,build_param(req))

        if not content then
           return res:json({success = false,msg="operation failed"})
        else
           return res:json({success = true ,data = content})
        end
    end
end)


api:post("/waf/delete_waf",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('delete_waf',req)
        local id = req.body.id
        if id == "" or not id  then
            return res:json({success = false,msg="'id' Can't be empty"})
        else
            --1、获取防火墙对应的选择器id
            local simple_wafs = waf_dao.load_waf_simple_info(store,id)

            if not simple_wafs then
                return res:json({success = false,msg="operation failed"})
            end
            local simple_waf = simple_wafs[1]

            -- 1、删除防火墙
            local result = waf_dao.delete_waf(store,id)

            if result then

                -- 2、删除条件
                condition_dao.delete_conditions_of_selector(store,simple_waf.selector_id)

                -- 3、删除选择器
                selector_dao.delete_selector(store,simple_waf.selector_id)

                -- 4、删除自定义错误信息
                err_resp_template_utils.delete(store,id,plugin_name)
            end
            build_result(result,res)
        end
    end
end)


-- 创建条件
-- 参数：
-- {"waf_id":2,"selector_id":1,"param_type":"REQ_BODY","condition_opt_type":"equals","param_name":"key3","param_value":"val"}
api:post("/waf/create_condition",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('create_condition',req)

        local data = req.body

        if (not data.selector_id or data.selector_id =="") and
                (not data.waf_id or data.waf_id =="") then
            return res:json({success = false,msg="'waf_id','selector_id' Can't be empty at the same time"})
        end

        local selector_id = data.selector_id
        if not selector_id or selector_id == "" then
            --1、获取防火墙对应的选择器id
            local simple_wafs = waf_dao.load_waf_simple_info(store,data.waf_id)
            if not simple_wafs or #simple_wafs < 1 then
                return res:json({success = false,msg="operation failed,err:waf_id [" .. data.waf_id .. "] not exist"})
            end
            local simple_waf = simple_wafs[1]
            selector_id = simple_waf.selector_id
        end
        data["selector_id"] = selector_id
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

-- 更新
-- 参数：
--     {"param_type":"REQ_BODY","condition_opt_type":"equals","param_name":"sge","param_value":"168","id":25}
api:post("/waf/updated_condition",function (store)
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

-- 根据id删除选择条件
api:post("/waf/delete_condition_by_id",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('delete_condition_by_id',req)
        if not req.body.id or req.body.id == "" then
            return res:json({success = false,msg="'id' Can't be empty"})
        end

        local result = condition_dao.delete_conditions_by_id(store,req.body.id)

        return build_result(result,res)
    end
end)

-- 根据防火墙 id 删除condition
api:post("/waf/delete_condition_by_waf_id",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('delete_selector_by_id',req)
        if not req.body.waf_id or req.body.waf_id == "" then
            return res:json({success = false,msg="'waf_id' Can't be empty"})
        end

        -- 获取防火墙对应的选择器id
        local simple_wafs = waf_dao.load_waf_simple_info(store,req.body.waf_id)

        if not simple_wafs then
            return res:json({success = false,msg="operation failed"})
        end
        local simple_waf = simple_wafs[1]

        local result = condition_dao.delete_conditions_of_selector(store,simple_waf.selector_id)

        return build_result(result,res)
    end
end)

-- 根据条件查询condition
-- 可选参数：
--      waf_id :防火墙id
--      selector_id:选择器id
--      param_type：选择条件参数类型 IP，USER_AGENT,QUEYRSTRING, HEADER,REQ_BODY,URL等
--      condition_opt_type：择条件匹配类型：equals（相等），not equals(不相等)，match 正则，not math，>,<,>=,<=
--      id：condition 主键
api:get("/waf/query_condition",function (store)
    return function(req,res,next)
        -- 记录日志
        api:print_req_log('query_condition',req)

        local params = build_condition_param(req)

        if req.query.waf_id and req.query.waf_id ~="" then
            --1、获取防火墙对应的选择器id
            local simple_wafs = waf_dao.load_waf_simple_info(store,req.query.waf_id)

            if not simple_wafs then
                return res:json({success = false,msg="operation failed"})
            end
            local simple_waf = simple_wafs[1]
            params["selector_id"] = simple_waf.selector_id
        end

        local flag,result,err = condition_dao.load_condition(store,params)

        if result then
            return res:json({success = true,data=result})
        else
            return res:json({success = false,msg="operation failed"})
        end
    end
end)

-- 查看某一天防火墙拒绝记录
-- 参数：date yyyy-mm-dd
-- return

api:get("/waf/query_judge_record",function (store,cache_client)
    return function(req,res,next)
        api:print_req_log('/waf/query_judge_record',req)
        ---yyyy-mm-dd
        local date = req.query.date
        local gateway_id = req.query.gateway_id
        local host_id = req.query.host_id
        if not date then
            return  res:json({success = false,msg="'date' Can't be empty"})
        end

        if not gateway_id then
            return  res:json({success = false,msg="'gateway_id' Can't be empty"})
        end

        if not host_id then
            return  res:json({success = false,msg="'host_id' Can't be empty"})
        end

        local key = config.build_waf_hit_record_key(gateway_id,host_id,date)
        local data,err = cache_client : lrange_json(key,0,99)
        if not data and err then
            return res:json({success = false,msg="query judge record error： " .. err })
        else
            return res:json({success = true ,data = data})
        end
    end
end)

api:post("/waf/add_err_resp_template",function (store)
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

api:post("/waf/update_err_resp_template",function (store)
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


api:post("/waf/delete_err_resp_template",function (store)
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

api:get("/waf/query_err_resp_template",function (store)
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

