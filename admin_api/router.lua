 local ipairs = ipairs
local pairs = pairs
local type = type
local require = require
local xpcall = xpcall
local string_lower = string.lower
local lor = require("lor.index")
local plugin_dao = require("core.dao.plugin_dao")
local auth = require("admin_api.auth")
 local admin_server_info = require("admin_api.admin_server_info")
 local plugins_config = require("plugins.plugins_config")
 local user_dao = require("core.dao.admin_user_dao")

---
 -- 加载plugin上注册的API
 -- @param plugin
 -- @param api_router
 -- @param store
 --
local function load_plugin_api(plugin, api_router, store, cache_client,config)
    local plugin_api_path = "plugins." .. plugin .. ".api"
    ngx.log(ngx.DEBUG, "[plugin's api load], plugin_api_path:", plugin_api_path)

    local ok, plugin_api, e
    ok = xpcall(function() 
        plugin_api = require(plugin_api_path)
    end, function()
        e =  plugin .. " do not have api for configuration."
    end)
    if not ok or not plugin_api or type(plugin_api) ~= "table" then
        ngx.log(ngx.INFO, "Plugin's api load failed,", e)
        return
    end

    local plugin_apis
    if plugin_api.get_mode and plugin_api:get_mode() == 2 then
        plugin_apis = plugin_api:get_apis()
    else
        plugin_apis = plugin_api
    end

    for uri, api_methods in pairs(plugin_apis) do
        -- ngx.log(ngx.INFO, "load route, uri:", uri)
        if type(api_methods) == "table" then
            for method, func in pairs(api_methods) do
                local method = string_lower(method)
                if method == "get" or method == "post" or method == "put" or method == "delete" then
                    api_router[method](api_router, uri, func(store,cache_client,config))
                end
            end
        end
    end
end

 local function interface_auth(store)
     local user = user_dao.load_user_by_user(store,ngx.ctx.username)
     if user then
         if tonumber(user.is_admin) == 1 then
             return true
         end
     end
     return false
 end

 return function(config, store, cache_client)
     local api_router = lor:Router()

    --- 健康检查
    api_router:get("/", function(req, res, next)
            res:set_header('Server',admin_server_info.full_name)
            res:json({success = true,msg="ngr-api is up!"})
    end)


     --- 登录
     api_router:post("/login", function(req, res, next)
         local flag = false
         local role = 0;
         local authorization = req.headers["Authorization"]
         if type(authorization) == "string" and authorization ~= "" then
             local encoded_credential = auth:get_encoded_credential(authorization)
             flag,role = auth:check_password(store,encoded_credential)
         end
         if flag then
             res:status(200):json({success = true,msg="success",role = role})
         else
             res:status(401):json({success = flag,msg="Not Authorized"})
         end
     end)

     --- 加载所有的插件信息
     -- 当前加载的插件，开启与关闭情况
     api_router:get("/plugins", function(req, res, next)

         local flag,plugins = plugin_dao.load_plugin(store)

         local plugins_res  ={}
         if flag then
             if plugins then
                 for _, v in ipairs(plugins) do
                     table.insert(plugins_res,{
                         plugin_name = v.plugin_name,
                         enable = v.enable
                     })
                 end
             end
             res:json({
                 success = true,
                 data = {
                     plugins = plugins_res
                 }
             })
         else
             res:json({success = false,msg="operation failed"})
         end
     end)

     --- 新增用户
     api_router:post("/create_user", function(req, res, next)


         if not interface_auth(store) then
             return res:json({success = false,msg="非法调用！当前登录用户：" .. ngx.ctx.username})
         end

         if not req.body.username then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="用户名不能为空"})
         elseif not req.body.password then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="用户密码不能为空"})
         end
         local user = user_dao.load_user_by_user(store,req.body.username)
         if user then
             return res:json({success = false,msg="用户" .. req.body.username .. "已存在"})
         end
         -- 加密
         req.body.password = auth:sha_password(req.body.password)

         local result,id = user_dao.inster_user(store,req.body)
         if result then
             return res:json({success = true,data={id=id}})
         else
             return res:json({success = false,msg="operation failed"})
         end
     end)

     --- 修改用户
     api_router:post("/modify_user", function(req, res, next)

         if not interface_auth(store) then
             return res:json({success = false,msg="非法调用！当前登录用户：" .. ngx.ctx.username})
         end

         if not req.body.id then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="id 不能为空"})
         end

         if not req.body.username then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="用户名不能为空"})
         end
         local user = user_dao.load_user_by_user(store,req.body.username)
         if user and tonumber(user.id) ~= tonumber(req.body.id)  then
             return res:json({success = false,msg="用户" .. req.body.username .. "已存在"})
         end
         local result = user_dao.update_user(store,req.body)
         if result then
             return res:json({success = true,msg="success"})
         else
             return res:json({success = false,msg="operation failed"})
         end
     end)

     --- 修改用户
     api_router:post("/modify_passowrd", function(req, res, next)
         if not req.body.username then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="用户名不能为空"})
         end
         if not req.body.old_password then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="原始密码不能为空"})
         end
         if not req.body.password then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="密码不能为空"})
         end

         local user = user_dao.load_user_by_user_pwd(store,req.body.username,auth:sha_password(req.body.old_password))
         if user and #user == 0 then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="原始密码不正确"})
         end

         local result = user_dao.update_password(store,auth:sha_password(req.body.password),req.body.username)

         if result then
             return res:json({success = true,msg="success"})
         else
             return res:json({success = false,msg="operation failed"})
         end

     end)

     --- 修改用户
     api_router:post("/user_enable", function(req, res, next)

         if not interface_auth(store) then
             return res:json({success = false,msg="非法调用！当前登录用户：" .. ngx.ctx.username})
         end

         if not req.body.id then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="id不能为空"})
         end

         if not req.body.enable then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="enable 不能为空"})
         end

         local result = user_dao.update_user_enable(store,req.body)

         if result then
             return res:json({success = true,msg="success"})
         else
             return res:json({success = false,msg="operation failed"})
         end

     end)

     --- 查询用户
     api_router:get("/query_user_list", function(req, res, next)

         if not interface_auth(store) then
             return res:json({success = false,msg="非法调用！当前登录用户：" .. ngx.ctx.username})
         end

         local req_param={}
         if req.query.username then
             table.insert(req_param,{column="username",value=req.query.username,is_like=false})
         end

         if req.query.mobile then
             table.insert(req_param,{column="mobile",value=req.query.mobile,is_like=false})
         end

         local result,users = user_dao.load_user(store,req_param)

         if result then
             return res:json({success = true,data=users})
         else
             return res:json({success = false,msg="operation failed"})
         end
     end)

     --- 查询用户
     api_router:get("/query_user_log", function(req, res, next)

         if not interface_auth(store) then
             return res:json({success = false,msg="非法调用！当前登录用户：" .. ngx.ctx.username})
         end

         if not req.query.start_time or not req.query.end_time then
             return res:json({success = false,err_no=plugins_config.CODE_WARNING,msg="时间段不能为空"})
         end
         local result,users = user_dao.query_user_log(store,req.query)
         if result then
             return res:json({success = true,data=users})
         else
             return res:json({success = false,msg="operation failed"})
         end
     end)


     --- 加载其他"可用"插件的API
     local available_plugins = config.plugins
     if not available_plugins or type(available_plugins) ~= "table" or #available_plugins<1 then
         return api_router
     end

     for _, plugin in ipairs(available_plugins) do
         load_plugin_api(plugin, api_router, store,cache_client,config)
     end

     return api_router
 end

