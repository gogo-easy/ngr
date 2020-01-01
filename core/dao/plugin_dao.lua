---
--- plugin configuration information dao
--- Copyright (c) GoGo Easy Team & Jacobs Lei
--- Author: Jacobs Lei
--- Date: 2018/4/6
--- Time: 下午4:05

local tonumber = tonumber
local tostring = tostring


local _M = {}


---
--- load plugin information from storage by plugin name
-- @param plugin_name
-- @param store
--
function _M.load_plugin_by_plugin_name(plugin_name, store)
    local flag,plugins, err = store:query({
        sql = "select * from `c_plugin` where `plugin_name` = ?",
        params = {plugin_name}
    })

    if err then
        ngx.log(ngx.ERR, "Load `enable` of plugin[" .. plugin_name .. "], error: ", err)
        return false, nil
    end

    if plugins and type(plugins) == "table" and #plugins > 0 then

        -- mysql query 默认返回的是一个array, 此处根据plugin_name查询只返回一个plugin
        -- 如果直接返回 plugin 其实是array，后续使用会误解，所以此处直接返回 plugin[1]
        return true, plugins[1]
    end

    return false,nil

end


--- update the plugin enable or not by plugin's name
-- @param store
-- @param plugin_name
-- @param enable
--
function _M.update_plugin_enable(store,plugin_name, enable)
    ngx.log(ngx.ERR, "update the plugin[" .. plugin_name .."]'s enable[".. enable .."]")
    if not plugin_name or type(plugin_name) ~= "string" then
        ngx.log(ngx.ERR, "update the plugin[" .. plugin_name .."]'s enable[".. enable .."] false")
        return false
    end

    if not enable or  not tonumber (enable)  then
        ngx.log(ngx.ERR, "update the plugin[" .. plugin_name .."]'s enable[".. enable .."] false")
        return false
    end

    local result = store:update({
        sql = "update c_plugin  set `enable` = ? where `plugin_name`=? ",
        params = {enable,plugin_name }
    })
    ngx.log(ngx.ERR, "update the plugin[" .. plugin_name .."]'s enable[".. enable .."]'s result:" .. tostring(result))
    return result

end



---
--- 获取所有非内建 plugin
-- @param store
--
function _M.load_plugin(store)
    local flag,plugins, err = store:query({
        sql = "select * from c_plugin where is_built_in = 0"
    })

    if err then
        ngx.log(ngx.ERR, "load_plugin error: ", err)
        return false, nil
    end

    if plugins and type(plugins) == "table" and #plugins > 0 then
        return true, plugins
    end

    return true,nil

end


return _M