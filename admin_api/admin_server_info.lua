---
--- 功能：admin_api服务信息
--- Created by: Jacobs.
--- DateTime: 2018/5/10
---

local server = {}
server.version = "1.0"
server.name="NgrRouter-Admin"
server.full_name = server.name .. "/" .. server.version

-- 跨域相关配置
server.Access_Control_Allow_Origin = "*"
server.Access_Control_Allow_Methods = "*"
server.Access_Control_Allow_Headers = "Origin, X-Requested-With, Content-Type, Accept, Authorization"

return server