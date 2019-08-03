---
---  Judge: check request parameters can match the expected value given by selectors and conditions
--- Created by jacobs.
--- DateTime: 2018/4/18 下午5:19
---
local param_type = require("core.constants.param_type")
local operator = require("core.constants.operator_type")
local extractor = require( "core.req.req_var_extractor")
local tonumber = tonumber
local string_format = string.format
local str_upper = string.upper
local ngx_re_find = ngx.re.find

local _M = {}

---
-- Judge condition rules,return "hit or not" and hit value
-- @parameter  expected_param_type(require) :
--    TYPE_URI = "URI",
--    TYPE_IP ="IP",
--    TYPE_HEADER = "Header",
--    TYPE_POST_PARAM = "PostParam",
--    TYPE_HOST = "Host",
--    TYPE_REFERER = "Referer",
--    TYPE_UA = "UserAgent"
--    TYPE_JSON_PARAM = "JsonParam"
-- @parameter expected_param_name(optional): parameter name, such as username,token and so on,
--        if param_type is IP,expected_param_name is IP,
--        if param_type is URI,expected_param_name is URI,
--        if param_type is REFERER,expected_param_name is REFERER,
--        if param_type is UA,expected_param_name is UA,
-- @parameter expected_value(require): the expected parameter value,default for any value,if not exists,opt_type must not be exist.
-- @parameter opt_type compare operator for param_name's expected_value & actual value:
--@return hit:true, not hit: false
--@return hit value, if not hit,hit value is nil, if expected_value is nil, return nil
function _M.judge(expected_param_type, expected_param_name,expected_value, opt_type)
    local _,actual_value = extractor.extract_param_by_type_and_name(expected_param_type,expected_param_name)
    if not actual_value then
        return false,nil
    end

    -- ip 段单独处理
    if str_upper(expected_param_type) == str_upper(param_type.TYPE_IP) then
        local number = string.find(expected_value or "","/")
        if number and number > 1 then
            if opt_type ~= operator.EQUALS and opt_type ~= operator.NOT_EQUALS then
                ngx.log(ngx.ERR,"waf ip segment supports only the operator 'equals' or 'not equals';in opt_type[".. opt_type .."]")
                return false
            end

            local iputils = require("resty.iputils.iputils")
            local cidrs = iputils.parse_cidrs({expected_value})
            local res = iputils.ip_in_cidrs(actual_value,cidrs)

            if opt_type == operator.EQUALS and res then
                return true,expected_value,actual_value
            end

            if opt_type == operator.NOT_EQUALS and not res then
                return true,expected_value,actual_value
            end

            return false
        end
    end


    local regex = '^'..expected_value..'$'
    if opt_type == operator.MATCH then
        if ngx_re_find(actual_value, regex, 'isjo') ~= nil then
            return true, expected_value,actual_value
        end
    elseif opt_type == operator.NOT_MATCH then
        if ngx_re_find(actual_value, regex, 'isjo') == nil then
            return true,expected_value,actual_value
        end
    elseif opt_type == operator.EQUALS then
        if actual_value == expected_value then
            return true,expected_value,actual_value
        end
    elseif opt_type == operator.NOT_EQUALS then
        if actual_value ~= expected_value then
            return true,expected_value,actual_value
        end
    elseif opt_type == operator.GT then
        if actual_value ~= nil and expected_value ~= nil then
            expected_value = tonumber(expected_value)
            actual_value = tonumber(actual_value)
            if actual_value and expected_value and actual_value > expected_value then
                return true,expected_value,actual_value
            end
        end
    elseif opt_type == operator.GT_EQUALS then
        if actual_value ~= nil and expected_value ~= nil then
            expected_value = tonumber(expected_value)
            actual_value = tonumber(actual_value)
            if actual_value and expected_value and actual_value >= expected_value then
                return true,expected_value,actual_value
            end
        end
    elseif opt_type == operator.LT then
        if actual_value ~= nil and expected_value ~= nil then
            expected_value = tonumber(expected_value)
            actual_value = tonumber(actual_value)
            if actual_value and expected_value and actual_value < expected_value then
                return true,expected_value,actual_value
            end
        end
    elseif opt_type == operator.LT_EQUALS then
        if actual_value ~= nil and expected_value ~= nil then
            expected_value = tonumber(expected_value)
            actual_value = tonumber(actual_value)
            if actual_value and expected_value and actual_value <= expected_value then
                return true,expected_value,actual_value
            end
        end
    end

    return false

end



function _M.judge_equals(expected_param_type,expected_param_name,expected_value)
    return _M.judge(expected_param_type,expected_param_name,expected_value,operator.EQUALS)
end


---
--- judge the expected parameter name is exist
--@return exist true or false
--@return actual parameter value if exists
function _M.judge_exist(expected_param_type,expected_param_name)
    if str_upper(expected_param_type) == str_upper(param_type.TYPE_IP) then
        local actual_ip  = extractor.extract_IP()
        return true, actual_ip
    end
    if str_upper(expected_param_type) == str_upper(param_type.TYPE_URI) then
        local actual_uri = extractor.extract_req_uri().uri
        return true, actual_uri
    end
    if str_upper(expected_param_type) == str_upper(param_type.TYPE_REFERER) then
        local actual_referer = extractor.extract_referer()
        return true, actual_referer
    end
    if str_upper(expected_param_type) == str_upper(param_type.TYPE_UA) then
        local actual_ua = extractor.extract_UA()
        return true, actual_ua
    end
    if str_upper(expected_param_type) == str_upper(param_type.TYPE_HEADER) then
        local actual_value = extractor.extract_header_param(expected_param_name)
        if actual_value then
            return true, actual_value
        else
            return false,nil
        end
    end

    if str_upper(expected_param_type) == str_upper(param_type.TYPE_HOST) then
        local actual_value = extractor.extract_http_host()
        if actual_value then
            return true, actual_value
        else
            return false,nil
        end
    end

    if str_upper(expected_param_type) == str_upper(param_type.TYPE_POST_PARAM) or str_upper(expected_param_type) == str_upper(param_type.TYPE_JSON_PARAM) then
        local actual_value = extractor.extract_post_param(expected_param_name)
        if actual_value then
            return true, actual_value
        else
            return false, nil
        end
    end
    if str_upper(expected_param_type) == str_upper(param_type.TYPE_QUERY_STRING) then
        local actual_value = extractor.extract_query_param(expected_param_name)
        if actual_value then
            return true, actual_value
        else
            return false, nil
        end
    end
    ngx.log(ngx.ERR, "The expected parameter type does not support[" .. expected_param_type .."]")
    return false, nil
end

return _M