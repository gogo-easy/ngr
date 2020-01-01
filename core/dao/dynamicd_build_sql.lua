local utils = require("core.utils.utils")

local _M ={}


local function trim(s)
    if type(s) == 'string' then
        return utils.trim(s)
    end
end

function _M:build_and_condition_sql(sql, _params)
    local params ={}

    -- 根据参数动态组装SQL　
    if _params and type(_params) == 'table' then
        for k, v in pairs(_params) do
            sql = sql.." and ".. k .. "= ? "
            if type(v) == "table" then
                v = v[#v]
            end
            params[#params+1]=trim(v)
        end
    end
    return sql,params
end

function _M:build_and_condition_like_sql(sql, _params)
    local params ={}
    -- 根据参数动态组装SQL　
    if _params and type(_params) == 'table' then
        for _, v in pairs(_params) do

            local value = v.value
            if type(value) == "table" then
                value = value[#value]
            end

            if v.is_like then
                sql = sql.." and ".. v.column .. " like '%".. trim(value) .."%'"
            else
                sql = sql.." and ".. v.column .. " =  ?"

                if type(value) == 'string'  then
                    params[#params+1]=trim(value)
                else
                    params[#params+1]=value
                end
            end
        end
    end
    return sql,params
end

return _M