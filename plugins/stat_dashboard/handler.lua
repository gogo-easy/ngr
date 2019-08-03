---
--- Dashboard stat handler
--- Created by jacobs.
--- DateTime: 2018/4/25 下午8:58
---

local require = require
local ngx_log = ngx.log
local base_handler = require("plugins.base_handler")
local PRIORITY = require("plugins.handler_priority")

local plugin_name = "stat_dashboard"

local stat_dashboard_handler = base_handler:extend()
stat_dashboard_handler.PRIORITY = PRIORITY.stat_dashboard

function stat_dashboard_handler:new(app_context)
    stat_dashboard_handler.super.new(self, plugin_name)
    self.app_context = app_context
    self.cache_client = app_context.cache_client
    self.stats =  require("plugins.stat_dashboard.stats")(app_context.cache_client,app_context.config.service_name)
end

function stat_dashboard_handler:log()
    ngx_log(ngx.DEBUG,"stat_dashboard_handler's log handler execute.")
    stat_dashboard_handler.super.log(self)
    local stats  = self.stats
    stats:log()
end

function stat_dashboard_handler: init_worker()
    local config = self.app_context.config
    self.stats:init_worker(config)
end

function stat_dashboard_handler: init_worker_ext_timer()
    self.stats:init_worker_ext_timer()
end

return stat_dashboard_handler
