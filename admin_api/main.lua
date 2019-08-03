local server = require("admin_api.api_server")
-- global context
local srv = server:new(context.config, context.store,context.cache_client)
return srv:get_app()
