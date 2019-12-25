---
--- Created by Go Go Easy Team.
--- DateTime: 2018/6/11 下午3:11
---
local err_resp_template_dao = require("core.dao.err_resp_template_dao")
local json = require("core.utils.json")

-- redis cache中历史错误响应模版前缀
local err_resp_template_old_key_all_prefix = "ERR_RESP_TEMPLATE_OLD_KEY_ALL"

local xpcall = xpcall
local _M={}


-- return
-- 存在：true
-- 不存在：false
local function only_check(plugin_name,biz_id,store)
    local flag,content = err_resp_template_dao.load_err_resp_template(store,plugin_name,biz_id)
    if content and #content > 0 then
        return true
    end
    return false
end

local function build_catch_key(plugin_name,biz_id)
    return "RESP_TEMPLATE_" .. plugin_name .. "_|_" .. biz_id
end

local function delete_catche_key(old_key,cache_client)
    if old_key then -- 清理已删除的数据
        for key, _ in pairs(old_key) do
            local res, err = cache_client:delete(key)
            if err then
                ngx.log(ngx.ERR, "delete cache key=",key,", err:",err)
            end
        end
    end
end

function _M.create(store,plugin_name,biz_id,data)
    if not data.content_type or not data.message or data.content_type == "" or data.message == "" then
        return true
    end

    data["plugin_name"] = plugin_name
    data["biz_id"] = biz_id

    local id,err = _M.add(store,data)
    if id then
        return true,id
    else
        return false,nil,err
    end
end

function _M.update(store,plugin_name,biz_id,data)

    if not data.content_type or not data.message or data.content_type == "" or data.message == "" then
        local flag = err_resp_template_dao.delete(store,biz_id,plugin_name)
        if not flag then
            return false
        end
        return true
    end

    data["biz_id"] = biz_id
    local flag,content =  err_resp_template_dao.load_err_resp_template(store,plugin_name,biz_id)
    if flag and not content then
        flag = _M.create(store,plugin_name,biz_id,data)
        return flag
    end

    local flag = err_resp_template_dao.update(store,data,plugin_name)
    if not flag then
        return false
    else
        return true
    end
end

-- delete 不抛异常
function _M.delete(store,biz_id,plugin_name)
   local ok,result
    ok = xpcall(function ()
        result = err_resp_template_dao.delete(store,biz_id,plugin_name)
    end ,function ()
        result =false
        ngx.log(ngx.ERR, "delete c_err_resp_template error: ", debug.traceback())
    end)
    return result
end

-- 添加
function _M.add(store,err_resp_template)
    local flag =only_check(err_resp_template.plugin_name,err_resp_template.biz_id,store)
    if flag then
        return nil,"当前记录下已添加过自定义错误信息"
    end
    local res ,id = err_resp_template_dao.inster(store,err_resp_template)
    if res then
        return id
    end
    return nil,"operation failed"
end

function _M.init_2_redis(plugin_name,store,cache_client)

    if not plugin_name then
        return
    end

    local old_key = cache_client:get_json(err_resp_template_old_key_all_prefix ..plugin_name)
    local flag,content = err_resp_template_dao.load_err_resp_template_by_plugin_name(store,plugin_name)
    if not content or #content < 1 then
        -- 清理已删除的数据
        delete_catche_key(old_key,cache_client)
        return
    end
    local new_key ={}
    for _, item in ipairs(content) do
        local key = build_catch_key(item.plugin_name,item.biz_id)
        local res,err = cache_client:set(key,json.encode(item))
        if err then
            ngx.log(ngx.ERR, "plugin_name="..plugin_name.."biz_id=".. item.biz_id .. " init_2_redis err :",err)
        else
            if old_key then
                old_key[key]=nil
            end
            new_key[key] = key
        end
    end
    -- 清理已删除的数据
    delete_catche_key(old_key,cache_client)
    -- 缓存all_key
    local tt, err = cache_client:set_json(err_resp_template_old_key_all_prefix ..plugin_name,new_key)
end

function _M.get_err_resp_template(plugin_name,biz_id,cache_client)
    if not plugin_name or not biz_id then
        return nil
    end

    local key = build_catch_key(plugin_name,biz_id)
    ngx.log(ngx.INFO,"get_err_resp_template key = ",key)

    local res ,err = cache_client:get_json(key)
    if err then
        ngx.log(ngx.ERR, "plugin_name="..plugin_name.."biz_id=".. biz_id .. " init_2_redis err :",err)
        return nil
    end
    return res
end


return _M