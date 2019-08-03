---
--- Created by yusai.
--- DateTime: 2018/6/11 上午10:45
---
local cjson = require("core.utils.json")
local _M = {}

function _M.inster(store,err_resp_template)
        ngx.log(ngx.DEBUG,"insert c_err_resp_template...param["..cjson.encode(err_resp_template).."]")
        local res,id = store:insert({
            sql = "INSERT INTO c_err_resp_template(plugin_name,biz_id,content_type,message,http_status) VALUES (?,?,?,?,?)",
            params={err_resp_template.plugin_name,err_resp_template.biz_id,err_resp_template.content_type,err_resp_template.message,err_resp_template.http_status or ''}
        })
        return res,id;
end

function _M.update(store,err_resp_template,plugin_name)
    ngx.log(ngx.DEBUG,"update c_err_resp_template...param["..cjson.encode(err_resp_template).."]")
    local res = store:query({
        sql = "update c_err_resp_template set content_type = ? ,message = ?,http_status = ? where biz_id = ? and plugin_name = ?",
        params={err_resp_template.content_type,err_resp_template.message,err_resp_template.http_status or '',err_resp_template.biz_id,plugin_name}
    })
    return res;
end

function _M.delete(store,biz_id,plugin_name)
    local res = store:query({
        sql = "delete from c_err_resp_template  where biz_id = ? and plugin_name = ?",
        params={biz_id,plugin_name}
    })
    return res;
end

function _M.load_err_resp_template_by_plugin_name(store,plugin_name)
    local flag,content = store:query({
        sql = "select * from c_err_resp_template where plugin_name = ?",
        params={plugin_name}
    })
    return flag,content;
end

function _M.load_err_resp_template_by_biz_id(store,biz_id)
    local flag,content = store:query({
        sql = "select * from c_err_resp_template where biz_id = ?",
        params={biz_id}
    })
    return flag,content;
end

function _M.load_err_resp_template(store,plugin_name,biz_id)
    local flag,content = store:query({
        sql = "select * from c_err_resp_template where plugin_name=? and biz_id = ?",
        params={plugin_name,biz_id}
    })
    if #content > 0 then
        return flag,content[1]
    end
    return flag,nil;
end

return _M