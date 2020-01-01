---
--- Author: Jacobs Lei
--- Date: 2018/6/19
--- Time: 下午6:36
local cjson = require("cjson")
local user_log = require("core.log.user_log")
local _M = {}

function _M.query_info_by_id(store,id)
    local flag, info= store:query({
        sql = "select * from c_group_target where id = ?",
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

--- query api group's targets by group'id
-- @param group_id
-- @param store
-- @return query success flag
-- @return targets array
--
function _M.query_target_by_group_id(group_id,store)
    local _,targets, err = store:query({
        sql = "select * from c_group_target where group_id = ? and enable = 1 order by id asc",
        params = {group_id}
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when initializing api groups error:", err)
        return false, nil
    end

    if targets and type(targets) == "table"  then
        return true, targets
    end

    return false,nil
end


function _M.query_target_and_gray_divide_count_by_group_id(group_id,store)
    local _,targets, err = store:query({
        sql = [[
            select
              a.*,
              (select count(1)
               from c_rel_gray_target t
               where t.target_id = a.id) as gray_divide_count
            from c_group_target a where a.group_id=? order by a.id asc
        ]],
        params = {group_id}
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when initializing api groups error:", err)
        return false, nil
    end

    if targets and type(targets) == "table"  then
        return true, targets
    end

    return false,nil
end

function _M.query_target_by_gray_divide_id(gray_divide_id,store)
    local _,targets, err = store:query({
        sql = [[
            select b.*
            from c_rel_gray_target a
              join c_group_target b on a.target_id = b.id
            where a.gray_divide_id = ?
            order by b.id asc
        ]],
        params = {gray_divide_id}
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when initializing api groups error:", err)
        return false, nil
    end

    if targets and type(targets) == "table"  then
        return true, targets
    end

    return false,nil
end

function _M.query_target_by_group_id_and_gray_divide_id(group_id,gray_divide_id,store)
    local sql = "select * from c_group_target where group_id = ? ";
    local params = {
        group_id
    };

    if gray_divide_id then
        sql = sql .. ' and gray_divide_id=? '
        table.insert(params, gray_divide_id)
    end

    sql = sql .. ' order by id asc'

    local _,targets, err = store:query({
        sql = sql,
        params = params
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when initializing api groups error:", err)
        return false, nil
    end

    if targets and type(targets) == "table"  then
        return true, targets
    end

    return false,nil
end

function _M.query_target(group_id,host,port,store)
    local _,targets, err = store:query({
        sql = "select * from c_group_target where group_id = ? and host = ? and port = ?",
        params = {group_id,host,port}
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when initializing api groups error:", err)
        return false, nil
    end

    if targets and type(targets) == "table"  then
        return true, targets
    end

    return false,nil
end

function _M.insert(target,store)
    ngx.log(ngx.DEBUG,"insert c_group_target...param["..cjson.encode(target).."]")
    local sql,params

    user_log.print_log(store,user_log.module.api_router_target .."-新增",nil,target)

    if target.weight then
        sql = "INSERT INTO c_group_target(group_id,host,port,weight,is_only_ab) VALUES (?,?,?,?,?)"
        params = {target.group_id,target.host,target.port,target.weight,target.is_only_ab or 0}
    else
        sql = "INSERT INTO c_group_target(group_id,host,port,is_only_ab) VALUES (?,?,?,?)"
        params = {target.group_id,target.host,target.port,target.is_only_ab or 0}
    end

    return store:insert({
        sql = sql,
        params=params
    })
end

function _M.update(target,store)
    ngx.log(ngx.DEBUG,"update c_group_target...param["..cjson.encode(target).."]")

    user_log.print_log(store,user_log.module.api_router_target .."-修改","group_target_dao",target)

    local sql,params

    if target.weight then
        sql = "update c_group_target set host = ? ,port = ?,weight=?,is_only_ab=? where id = ? "
        params={target.host,target.port,target.weight,target.is_only_ab or 0,target.id}
    else
        sql = "update c_group_target set host = ? ,port = ?,weight=null,is_only_ab=? where id = ? "
        params={target.host,target.port,target.is_only_ab or 0,target.id}
    end

    local res = store:query({
        sql = sql,
        params= params
    })
    return res;
end

function _M.update_gray_divide_id_by_target_id(gray_divide_id,target_id,store)
    ngx.log(ngx.DEBUG,"update update_gray_divide_id...param["..gray_divide_id.."]")
    local sql,params

    sql = "update c_group_target c set c.gray_divide_id=? where c.id=?"
    params={gray_divide_id,target_id}

    local res = store:query({
        sql = sql,
        params= params
    })
    return res;
end

function _M.reset_target(gray_divide_id,store)
    ngx.log(ngx.DEBUG,"reset target...param["..gray_divide_id.."]")
    local sql,params

    sql = "delete from c_rel_gray_target where gray_divide_id=?"
    params={gray_divide_id}

    local res = store:query({
        sql = sql,
        params= params
    })
    return res;
end

function _M.delete(id,store)
    ngx.log(ngx.DEBUG,"delete c_group_target...param["..id.."]")

    user_log.print_log(store,user_log.module.api_router_target .."-删除","group_target_dao",{id=id})

    local res = store:query({
        sql = "delete from c_group_target  where id = ?",
        params={id}
    })
    return res;
end

function _M.query_rel_gray_target_by_target_id(id, store)
    local _, results, err = store:query({
        sql = "select a.target_id,a.gray_divide_id from c_rel_gray_target a where target_id=?",
        params = {id}
    })

    if err then
        ngx.log(ngx.ERR, "Find data from storage when query rel_gray_target by target_id error:", err)
        return false, nil
    end

    if results and type(results) == "table"  then
        return true, results
    end

    return false,nil
end


function _M.insert_rel_gray_target(gray_divide_id,target_id,store)
    local sql = "insert into c_rel_gray_target(gray_divide_id, target_id) values (?, ?)"

    return store:insert({
        sql = sql,
        params={
            gray_divide_id,
            target_id
        }
    })
end


function _M.update_target_enable(target,store)

    user_log.print_log(store,user_log.module.api_router_target .. (target.enable == "1" and "启用" or "禁用"),
            nil,{id=target.id,enable=target.enable})

    local res = store:update({
        sql = "UPDATE c_group_target set enable=? where id = ?",
        params={
            target.enable,
            target.id
        }
    })
    return res;
end
return _M