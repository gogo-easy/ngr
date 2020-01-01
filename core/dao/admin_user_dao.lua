local json = require("core.utils.json")
local utils = require("core.utils.utils")
local dynamicd_build = require("core.dao.dynamicd_build_sql")
local _M = {}

function _M.load_user_by_user_pwd(store,username,password)

    local flag,user = store:query({
        sql = "select * from u_admin_user where username=? and password =? and enable = 1",
        params ={username,password}
    })
    return user
end

function _M.load_user(store,data)

    local sql_prefix = "select id,username, is_admin, mobile, email, superior,enable from u_admin_user where 1=1";
    -- 根据参数动态组装SQL
    local sql,params = dynamicd_build:build_and_condition_like_sql(sql_prefix,data)
    local flag,users = store:query({
        sql = sql,
        params =params
    })
    return flag,users
end

function _M.load_user_by_user(store,username)
    local flag,user = store:query({
        sql = "select * from u_admin_user where username=? and enable = 1",
        params ={username}
    })
    return user[1]
end

function _M.inster_user(store,data)
    local res,id = store:insert({
        sql = "insert into u_admin_user(username, password, is_admin, mobile, email, superior) values (?,?,?,?,?,?)",
        params={
            utils.trim(data.username),
            utils.trim(data.password),
            data.is_admin or 0,
            utils.trim(data.mobile) or '',
            utils.trim(data.email) or '',
            utils.trim(data.superior) or ''
        }
    })
    return res,id
end

function _M.update_user(store,data)

    local res= store:update({
        sql = "update u_admin_user set username=?,mobile = ?,email=?,superior=?,updated_at =sysdate() where id = ?",
        params={
            utils.trim(data.username),
            utils.trim(data.mobile) or '',
            utils.trim(data.email) or '',
            utils.trim(data.superior) or '',
            data.id
        }
    })
    return res
end

function _M.update_user_enable(store,data)

    local res= store:update({
        sql = "update u_admin_user set enable=? where id = ?",
        params={
            data.enable,
            data.id
        }
    })
    return res
end

function _M.update_password(store,new_pwd,username)

    local res= store:update({
        sql = "update u_admin_user set password=? where username = ?",
        params={
            utils.trim(new_pwd),
            utils.trim(username)
        }
    })
    return res
end


function _M.inster_user_log(store,username,module,module_desc,operation_type,operation_desc,in_param)
    local res,id = store:insert({
        sql = "insert into u_user_log(username, module, module_desc, operation_type, operation_desc,in_param) VALUES (?,?,?,?,?,?)",
        params={
            utils.trim(username),
            module,
            module_desc,
            operation_type,
            operation_desc,
            in_param
        }
    })
    return res,id
end

function _M.query_user_log(store,data)
    local sql = [[select
              username,
              module,
              module_desc,
              operation_type,
              operation_desc,
              in_param,
              create_at,
              CONCAT(operation_desc, '-', module_desc) as 'remark'
            from u_user_log where create_at >= str_to_date(?,'%Y-%m-%d %H:%i:%s') and create_at <= str_to_date(?,'%Y-%m-%d %H:%i:%s')]]
    local params = {data.start_time,data.end_time}
    if data.username then
        sql = sql .. " and username=?"
        table.insert(params,data.username)
    end
    local flag,users = store:query({
        sql = sql,
        params = params
    })
    return flag,users
end

return _M