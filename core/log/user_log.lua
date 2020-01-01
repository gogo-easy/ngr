---
--- 用户log 记录
--- Created by Go Go Easy Team.
--- DateTime: 2019/2/13 4:58 PM
---
local _M ={}

local user_dao = require("core.dao.admin_user_dao")
local cjson = require("cjson")
    -- 操作组件
    _M.module = {
        gateway = "网关",
        host ="主机",
        api_router = "API路由组",
        api_router_target = "上游target",
        gray_divide = "灰度分流",
        group_rate_limit = "组限流",
        property_rate_limit = "特征限速",
        anti_sql_injection = "SQL防控器",
        waf = "防火墙",
        selector_condition = "选择器条件"


    }
    -- 操作类型
    _M.operation_type = {
        MODIFY="修改",
        ADD="添加",
        DELETE="删除",
        ENABLE="启禁用"
    }

    -- 标注操作方法前缀
    _M.operation_prefix = {
        update = "MODIFY",
        add = "ADD",
        create="ADD",
        delete = "DELETE",
        enable = "ENABLE",
        update_enable = "ENABLE"
    }

local function get_module(path)
    for key, desc in pairs(_M.module) do
       local index =  string.find(path,key,0,true)
        if index and index > 0 then
            if key == 'api_router' then
                local tg_index = string.find(path,"_target")
                if tg_index and tg_index > 0 then
                    return "api_router_target",_M.module.api_router_target
                end
            end
            return key,desc;
        end
    end
    return nil,nil
end

local function get_operation_type(path)
    for key, value in pairs(_M.operation_prefix) do
        local index = string.find(path,key,0,true)
        if index and index > 0 then
            return value,_M.operation_type[value]
        end
    end
    return nil,nil
end

function _M.log_to_db(store,username,path,data)
    if not path or not data then
        return
    end
    local module,module_desc = get_module(path)
    if not module then
        return
    end
    local operation_type ,oper_desc = get_operation_type(path)
    if operation_type then
        local res,id = user_dao.inster_user_log(store,username,module,module_desc,operation_type,oper_desc,cjson.encode(data))
        if not res then
            ngx.log(ngx.ERR,"记录日志失败,module=",module,",operation_type=",operation_type)
        end
    end
end


function _M.print_log(store,message,file_name,new_data)
    local old_data = nil
    if file_name then
        local dao = require("core.dao."..file_name)
        old_data = dao.query_info_by_id(store,new_data.id)
        dao = nil
    end

    local log_data = {
        username = ngx.ctx.username,
        message = message,
        old_data = old_data or {},
        new_data = new_data
    }
    ngx.log(ngx.ERR,cjson.encode(log_data))
end
return _M;