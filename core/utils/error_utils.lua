---
--- Error type definition, utils method definition
--- Created by Jacobs Lei
--- DateTime: 2018/5/14 下午4:45
---
local ngx = ngx
local _t =  {
    types = {
        ERROR_SYSTEM = {
            name =  "sys"
        },
        ERROR_BIZ = {
            name = "biz"
        },
        -- Glabal access control's error, see global_access_control plugin
        ERROR_GAC = {
            name = "gac"
        },
        ERROR_UPSTREAM =  {
            name = "upstream"
        }
    }
}

---
--- ddd error information: big type
---
function _t.add_error_2_ctx(big_type, small_type)
    ngx.ctx.error = true
    ngx.ctx.error_type = big_type
    ngx.ctx.error_detail = small_type
end


return _t
