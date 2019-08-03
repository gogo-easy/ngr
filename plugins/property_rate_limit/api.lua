local BaseAPI = require("plugins.base_api")
local common_api = require("plugins.common_api")
local config = require("plugins.property_rate_limit.config")
local dao = require("core.dao.property_rate_limit_dao")
local co_parameter_dao = require("core.dao.co_parameter_dao")
local err_resp_template_utils = require("core.utils.err_resp_template_utils")
local err_resp_template_dao = require("core.dao.err_resp_template_dao")
local plugins_config = require("plugins.plugins_config")

local function build_param(req)
    local req_param={}
    if req.query.name then
        table.insert(req_param,{column="name",value=req.query.name,is_like=true})
    end

    if req.query.property_type and req.query.property_type ~="" then
        table.insert(req_param,{column="property_type",value=req.query.property_type,is_like=false})
    end

    if req.query.id and req.query.id ~="" then
        table.insert(req_param,{column="id",value=req.query.id,is_like=false})
    end

    if req.query.property_name and req.query.property_name ~="" then
        table.insert(req_param,{column="property_name",value=req.query.property_name,is_like=true})
    end
    if req.query.enable and req.query.enable ~="" then
        table.insert(req_param,{column="enable",value=req.query.enable,is_like=false})
    end
    if req.query.is_blocked and req.query.is_blocked ~="" then
        table.insert(req_param,{column="is_blocked",value=req.query.is_blocked,is_like=false})
    end

    if req.query.rate_type and req.query.rate_type ~="" then
        table.insert(req_param,{column="rate_type",value=req.query.rate_type,is_like=false})
    end

    if req.query.host_id and req.query.host_id ~="" then
        table.insert(req_param,{column="host_id",value=req.query.host_id,is_like=false})
    end

    if req.query.host and req.query.host ~="" then
        table.insert(req_param,{column="c_host.host",value=req.query.host,is_like=false})
    end
    if req.query.gateway_id and req.query.gateway_id ~="" then
        table.insert(req_param,{column="c_host.gateway_id",value=req.query.gateway_id,is_like=false})
    end
    return req_param;
end

-- return
--  存在 true
--  不存在 false
local function only_check(property_type,property_name,prl_id,id,store)
    local contents = co_parameter_dao.load_co_parameter_info(property_type,property_name,prl_id,"property_rate_limit",store)
    if contents and #contents> 0 then
        if id then
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

local plugin_name = config.plugin_name

local api = BaseAPI:new(plugin_name, 2)
api:merge_apis(common_api(plugin_name))

api.path_prefix = "/" .. plugin_name


---
--查询被阻止访问的特征列表
--@parameter date 日期 只能查最近五日
--@return
-- [
--   {blocked_date,blocked_time, property_type,property_name, property_value}
-- ]
api:get(api.path_prefix .. "/blocked/list",function (store,cache_client)
    return function(req,res,next)
        api:print_req_log('/property_rate_limit/blocked/list',req)
        ---yyyy-mm-dd
        local date = req.query.date
        local gateway_id = req.query.gateway_id
        local host_id = req.query.host_id

        if not date or date =='' then
            return res:json({success = false,msg="parameter 'date' is empty." })
        end

        if not gateway_id or gateway_id =='' then
            return res:json({success = false,msg="parameter 'gateway_id' is empty." })
        end

        if not host_id or host_id =='' then
            return res:json({success = false,msg="parameter 'host_id' is empty." })
        end

        local key = config.blocked_recored_key(gateway_id,host_id,date)

        local data,err = cache_client : lrange_json(key,0,99)
        if not data and err then
            res:json({success = false,msg="query blocked list error： " .. err })
        else
            res:json({success = true ,data = data})
        end
    end
end)

---
---
----查询被限速访问的特征列表
----@parameter date 日期 只能查最近五日
----@return
---- [
----   {limit_date,limit_time, property_type,property_name, property_value}
---- ]
--
api:get(api.path_prefix .."/limit/list",function (store,cache_client)
    return function(req,res,next)
        api:print_req_log('/property_rate_limit/limit/list',req)
        ---yyyy-mm-dd
        local date = req.query.date
        local gateway_id = req.query.gateway_id
        local host_id = req.query.host_id

        if not date or date =='' then
            return res:json({success = false,msg="parameter 'date' is empty." })
        end

        if not gateway_id or gateway_id =='' then
            return res:json({success = false,msg="parameter 'gateway_id' is empty." })
        end

        if not host_id or host_id =='' then
            return res:json({success = false,msg="parameter 'host_id' is empty." })
        end

        local key = config.build_limit_recored_key(gateway_id,host_id,date)

        local data,err = cache_client : lrange_json(key,0,99)
        if not data and err then
            res:json({success = false,msg="query limit list error： " .. err })
        else
            res:json({success = true ,data = data})
        end
    end
end)

----
---查询特征限流防刷配置列表
---
---
api:get(api.path_prefix .. "/query", function (store,cache_client)
    return function(req,res, next)
        api:print_req_log(api.path_prefix .."/query", req)
        local content = dao.load_property_rate_limit_config(build_param(req),store)
        if not content  then
            res:json({success = false,msg="query property rate limit configuration data error." })
        else
            res:json({success = true,msg="ok", data = content })
        end
    end
end)

---添加配置
api:post(api.path_prefix .. "/add", function (store, cache_client)
    return function(req,res,next)
        api:print_req_log(api.path_prefix .."/add", req)
        local body = req.body
        if not body then
            res:json({success = false,msg="parameter table is empty. "})
        else
            local result,property_id = dao.insert(body, store)
            if ( not result) then
               return res:json({success = false,msg="operation failed"})
            else
                local ok,id,err
                ok = xpcall(function ()
                    result,id,err = err_resp_template_utils.create(store,plugin_name,property_id,body)
                end ,function ()
                    result =false
                    ngx.log(ngx.ERR, "create_waf error: ", debug.traceback())
                end)

                if result then
                    return res:json({success = true,data = {id = property_id}})
                else
                    dao.delete(property_id,store)
                    return res:json({success = false,msg = err or "operation failed"})
                end
            end
        end
    end
end)

--修改配置
api: post(api.path_prefix .. "/update", function (store,cache_client)
    return function(req,res,next)
        api : print_req_log(api.path_prefix .. "/update", req)
        local body = req.body
        if not body then
            res:json({success = false,msg="parameter table is empty. "})
            return
        end
        if not body.id then
            res:json({success = false,msg="parameter id is empty. "})
            return
        end
        local flag,old_data = err_resp_template_dao.load_err_resp_template(store,plugin_name,body.id)

        local result = err_resp_template_utils.update(store,plugin_name,body.id,body)

        if not result then
            res:json({success = false,msg="operation failed"})
            return
        end

        result = dao.update(body, store)
        if ( not result) then
            if old_data then
                err_resp_template_dao.update(store,old_data,plugin_name)
            else
                err_resp_template_dao.delete(store,body.id,plugin_name)
            end

            res:json({success = false,msg="operation failed"})
            return
        else
            res:json({success = true,msg="success"})
            return
        end
    end
end)

--修改配置
api: post(api.path_prefix .. "/update_enable", function (store)
    return function(req,res,next)
        api : print_req_log(api.path_prefix .. "/update_enable", req)
        local body = req.body
        if not body then
            res:json({success = false,msg="parameter table is empty. "})
            return
        end
        if not body.id then
            res:json({success = false,msg="parameter id is empty. "})
            return
        end
        if not body.enable then
            res:json({success = false,msg="parameter enable is empty. "})
            return
        end

        local result = dao.update_enable(body.id,body.enable, store)
        if ( not result) then
            res:json({success = false,msg="operation failed"})
            return
        else
            res:json({success = true,msg="success"})
            return
        end
    end
end)

---删除配置
api:post(api.path_prefix .. "/delete", function (store,cache_client)
    return function(req,res,next)
        api:print_req_log(api.path_prefix .. "/delete/", req)
        local id = req.body.id
        if not id then
            res:json({success = false,msg="property rate limit config id is nil."})
            return
        end
        local flag = dao.delete(id,store)
        if not flag then
            res:json({success = false,msg="operation failed"})
        else
            err_resp_template_utils.delete(store,id,plugin_name)
            res:json({success = true,msg = "success"})
        end
    end
end)


---添加配置
api:post(api.path_prefix .. "/add_detail", function (store, cache_client)
    return function(req,res,next)
        api:print_req_log(api.path_prefix .."/add_detail", req)
        local body = req.body
        if not body then
            res:json({success = false,msg="parameter table is empty. "})
        else

            -- 唯一性校验
            local check_res = only_check(body.property_type,body.property_name,body.prl_id,body.id,store)
            if check_res then
                -- 前端要求这种格式
                return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg = "该特征类型和特征属性名称已存在"})
            end

            -- 特征不能超过 5 个
            local _count = co_parameter_dao.count_property_detail(body.prl_id,"property_rate_limit",store)

            if _count and tonumber(_count)  >= 5 then
                return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="一个特征防刷器下不能超过5个特征属性"})
            end

            local result,id = co_parameter_dao.insert_co_parameter("property_rate_limit",body.prl_id,body.property_type,body.property_name,store)
            if ( not result) then
                return res:json({success = false,msg="add property detail config error. "})
            else
                return res:json({success = true,data = {id = id}})
            end
        end
    end
end)

---添加配置
api:post(api.path_prefix .. "/update_detail", function (store, cache_client)
    return function(req,res,next)
        api:print_req_log(api.path_prefix .."/update_detail", req)
        local body = req.body
        if not body then
            res:json({success = false,msg="parameter table is empty. "})
        else
            -- 唯一性校验
            local check_res = only_check(body.property_type,body.property_name,body.prl_id,body.id,store)
            if check_res then
                -- 前端要求这种格式
                return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg = "该特征类型和特征属性名称已存在"})
            end
            body["biz_id"] = body.prl_id
            local result,id = co_parameter_dao.update_co_parameter("property_rate_limit",body, store)
            if ( not result) then
                return res:json({success = false,msg="operation failed"})
            else
                return res:json({success = true,msg = "success"})
            end
        end
    end
end)


api:post(api.path_prefix .. "/delete_detail", function (store,cache_client)
    return function(req,res,next)
        api:print_req_log(api.path_prefix .. "/delete_detail/", req)
        local id = req.body.id
        if not id then
            res:json({success = false,msg="property rate limit config id is nil."})
            return
        end
        local flag = co_parameter_dao.delete_co_parameter(id,store)
        if not flag then
            res:json({success = false,msg="operation failed"})
        else
            res:json({success = true,msg = "success"})
        end
    end
end)

api:get(api.path_prefix .. "/query_property_detail", function (store,cache_client)
    return function(req,res, next)
        api:print_req_log(api.path_prefix .."/query_property_detail", req)
        local prl_id = req.query.prl_id

        if not prl_id then
            return res:json({success = false,msg="parameter prl_id is empty. "})
        end

        local content = co_parameter_dao.load_co_parameter_by_bizid(prl_id,"property_rate_limit",store)

        if not content  then
            res:json({success = false,msg="operation failed" })
        else
            res:json({success = true,msg="ok", data = content })
        end
    end
end)



api:post(api.path_prefix .. "/add_err_resp_template",function (store)
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

api:post(api.path_prefix .. "/update_err_resp_template",function (store)
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


api:post(api.path_prefix .. "/delete_err_resp_template",function (store)
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

api:get(api.path_prefix .. "/query_err_resp_template",function (store)
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