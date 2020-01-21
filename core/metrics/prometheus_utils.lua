---
--- Prometheus metrics integration utils
--- Created by Jacobs Lei.
--- DateTime: 2020-01-20 11:49
---
local require =require
local ngx = ngx
local string_gmatch =  string.gmatch
local table_insert = table.insert
local tonumber = tonumber
local ipairs = ipairs
local table_getn = table.getn


local prometheus_metrics = {}

local function split(str)
    local array = {}
    for mem in string_gmatch(str, '([^, ]+)') do
        table_insert(array, mem)
    end
    return array
end

local function getWithIndex(str, idx)
    if str == nil then
        return nil
    end
    return split(str)[idx]
end


function prometheus_metrics:init()
    local prometheus = require("resty.prometheus").init("prometheus_metrics")
    local bucket =  {0.01, 0.05, 0.1, 0.5, 1, 5}
    self.prometheus = prometheus
    self.http_requests = prometheus:counter("nginx_http_requests", "Number of HTTP requests", {"host", "status"})
    self.http_request_time = prometheus:histogram(
            "nginx_http_request_time", "HTTP request time", {"host"}, bucket)
    self.http_request_bytes_received = prometheus:counter(
            "nginx_http_request_bytes_received", "Number of HTTP request bytes received", {"host"})
    self.http_request_bytes_sent = prometheus:counter(
            "nginx_http_request_bytes_sent", "Number of HTTP request bytes sent", {"host"})
    self.http_connections = prometheus:gauge(
            "nginx_http_connections", "Number of HTTP connections", {"state"})
    self.http_upstream_cache_status = prometheus:counter(
            "nginx_http_upstream_cache_status", "Number of HTTP upstream cache status", {"host", "status"})
    self.http_upstream_requests = prometheus:counter(
            "nginx_http_upstream_requests", "Number of HTTP upstream requests", {"addr", "status"})
    self.http_upstream_response_time = prometheus:histogram(
            "nginx_http_upstream_response_time", "HTTP upstream response time", {"host", "addr"}, bucket)
    self.http_upstream_header_time = prometheus:histogram(
            "nginx_http_upstream_header_time", "HTTP upstream header time", {"host", "addr"}, bucket)
    self.http_upstream_bytes_received = prometheus:counter(
            "nginx_http_upstream_bytes_received", "Number of HTTP upstream bytes received", {"addr"})
    self.http_upstream_bytes_sent = prometheus:counter(
            "nginx_http_upstream_bytes_sent", "Number of HTTP upstream bytes sent", {"addr"})
    self.http_upstream_connect_time = prometheus:histogram(
            "nginx_http_upstream_connect_time", "HTTP upstream connect time", {"host", "addr"}, bucket)
    self.http_upstream_first_byte_time = prometheus:histogram(
            "nginx_http_upstream_first_byte_time", "HTTP upstream first byte time", {"host", "addr"}, bucket)
    self.http_upstream_session_time = prometheus:histogram(
            "nginx_http_upstream_session_time", "HTTP upstream session time", {"host", "addr"}, bucket)

end

function prometheus_metrics:metrics()
    if ngx.var.connections_active ~= nil then
        self.http_connections:set(ngx.var.connections_active, {"active"})
        self.http_connections:set(ngx.var.connections_reading, {"reading"})
        self.http_connections:set(ngx.var.connections_waiting, {"waiting"})
        self.http_connections:set(ngx.var.connections_writing, {"writing"})
    end
    self.prometheus:collect()
end


function prometheus_metrics:log()

    local host = ngx.var.host
    local status = ngx.var.status
    self.http_requests:inc(1, {host, status})
    self.http_request_time:observe(ngx.now() - ngx.req.start_time(), {host})
    self.http_request_bytes_sent:inc(tonumber(ngx.var.bytes_sent), {host})
    if ngx.var.bytes_received ~= nil then
        self.http_request_bytes_received:inc(tonumber(ngx.var.bytes_received), {host})
    end
    local upstream_cache_status = ngx.var.upstream_cache_status
    if upstream_cache_status ~= nil then
        self.http_upstream_cache_status:inc(1, {host, upstream_cache_status})
    end
    local upstream_addr = ngx.var.upstream_addr
    if upstream_addr ~= nil then
        local addrs = split(upstream_addr)

        local upstream_status = ngx.var.upstream_status
        local upstream_response_time = ngx.var.upstream_response_time
        local upstream_connect_time = ngx.var.upstream_connect_time
        local upstream_first_byte_time = ngx.var.upstream_first_byte_time
        local upstream_header_time = ngx.var.upstream_header_time
        local upstream_session_time = ngx.var.upstream_session_time
        local upstream_bytes_received = ngx.var.upstream_bytes_received
        local upstream_bytes_sent = ngx.var.upstream_bytes_sent
        -- compatible for nginx commas format
        for idx, addr in ipairs(addrs) do
            if table_getn(addrs) > 1 then
                upstream_status = getWithIndex(ngx.var.upstream_status, idx)
                upstream_response_time = getWithIndex(ngx.var.upstream_response_time, idx)
                upstream_connect_time = getWithIndex(ngx.var.upstream_connect_time, idx)
                upstream_first_byte_time = getWithIndex(ngx.var.upstream_first_byte_time, idx)
                upstream_header_time = getWithIndex(ngx.var.upstream_header_time, idx)
                upstream_session_time = getWithIndex(ngx.var.upstream_session_time, idx)
                upstream_bytes_received = getWithIndex(ngx.var.upstream_bytes_received, idx)
                upstream_bytes_sent = getWithIndex(ngx.var.upstream_bytes_sent, idx)
            end
            self.http_upstream_requests:inc(1, {addr, upstream_status})
            self.http_upstream_response_time:observe(tonumber(upstream_response_time), {host, addr})
            self.http_upstream_header_time:observe(tonumber(upstream_header_time), {host, addr})
            -- ngx.config.nginx_version >= 1011004
            if upstream_first_byte_time ~= nil then
                self.http_upstream_first_byte_time:observe(tonumber(upstream_first_byte_time), {host, addr})
            end
            if upstream_connect_time ~= nil then
                self.http_upstream_connect_time:observe(tonumber(upstream_connect_time), {host, addr})
            end
            if upstream_session_time ~= nil then
                self.http_upstream_session_time:observe(tonumber(upstream_session_time), {host, addr})
            end
            if upstream_bytes_received ~= nil then
                self.http_upstream_bytes_received:inc(tonumber(upstream_bytes_received), {addr})
            end
            if upstream_bytes_sent ~= nil then
                self.http_upstream_bytes_sent:inc(tonumber(upstream_bytes_sent), {addr})
            end
        end
    end
end


return prometheus_metrics;