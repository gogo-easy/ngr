--- 分布式缓存处理
--- Created by Go Go Easy Team.
--- DateTime: 2018/4/9 下午2:03
---
local redis_db = require("core.utils.redis_client")
local Object = require("core.framework.classic")
local lua_script = require("core.store.redis_lua_extend_script")
local json = require("core.utils.json")
local cache =Object:extend()

local not_support_cache_type_msg = "不支持当前cache_type，请查看ngr.json文件cache_type配置"

function cache:new(options)
    cache.super.new(self)
    -- 默认缓存使用redis
    if not options.cache_type or options.cache_type == 'redis' then
        self.redis = redis_db:new(options.cache_redis);
    else
        ngx.log(ngx.ERR,"cache type 暂不支持【"..options.cache_type.."】")
    end
end

local function check_connect(redis)
    if not redis then
        return false,not_support_cache_type_msg;
    end
    return true,nil
end

--[[
    功能：set 函数，
    key : 键
    val : 值
    return: 返回两个参数
        res:true/false
        err:错误信息
]]
function cache:set(key,val)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return check_res,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:set(key,val)
    end)

    -- 3、包装结果
    if err then
        return false,err
    else
        return true,nil
    end

end

--[[
    功能：set_json 函数，
    key : 键
    val : table
    return: 返回两个参数
        res:true/false
        err:错误信息
]]
function cache:set_json(key,val)
    if not val then
        return true
    end
   return cache.set(self,key,json.encode(val))
end

--[[
    功能：get 函数，
    key : 键
    return:返回两个参数
        res:nil/key对应的值
        err:错误信息
]]
function cache:get(key)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:get(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    elseif res==ngx.null then
        return nil,nil
    else
        return res,nil
    end
end

--[[
    功能：get_json 函数，
    key : 键
    return:返回两个参数
        res:nil/key对应的值
        err:错误信息
]]
function cache:get_json(key)
    local res,err = cache.get(self,key)
    if res and res ~= ngx.null then
        return json.decode(res)
    end
    return nil,err
end

--[[
    功能：带过期时间的 set 函数，
    key : 键
    val : 值
    timeout : 过期时间,单位 秒
    return:返回两个参数
        res:true/false
        err:错误信息
]]
function cache:setex(key,val,timeout)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return check_res,err;
    end

    -- 2、执行命令
    if timeout then
        local res,err = self.redis:exec(function (r)
            return r:setex(key,timeout,val)
        end)
    else
        local res,err = self.redis:exec(function (r)
            return r:set(key,val)
        end)
    end

    -- 3、包装结果
    if err then
        return false,err
    else
        return true,nil
    end
end


--[[
    功能：，只有在 key 不存在时才设置 key 的值
    key : 键
    val : 值
    return：返回两个值
        res:true/false
        err:错误信息
]]
function cache:setnx(key,val)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return check_res,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:setnx(key,val)
    end)

    -- 3、包装结果
    if err then
        return false,err
    elseif res == 0 then
        return false,"key '"..key.."' exist"
    else
        return true,nil
    end
end

--[[
    功能：del 函数，删除存在的key返回 1，否则返回0
    key : 键
    return:返回两个值
       res:nil/ 0 / 1   1：表示删除key成功
       err:错误信息
]]
function cache:delete(key)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return 0,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:del(key)
    end)


    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：incr 函数，将 key 中储存的数字值增一，
          key 不存在，先创建key，再累计 1
    key : 键
    return:返回两个值
        res:nil/key incr 后的值    -- 出现异常 res 返回nil
        err:错误信息
]]
function cache:incr(key)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:incr(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：incrby 函数，将 key 中储存的数字加上指定的增量值
          key 不存在，先创建key，再累计 1
    key : 键
    increment : 增量
    return:返回两个值
        res:nil/key incr increment 后的值    -- 出现异常 res 返回nil
        err:错误信息
]]
function cache:incrby(key,increment)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:incrby(key,increment)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：decr 函数，将 key 中储存的数字值减一，
          key 不存在，初始化key值为0，再执行decr操作
    key : 键
    return:返回两个值
        res:nil/key decr 后的值    -- 出现异常 res 返回nil
        err:错误信息
]]
function cache:decr(key)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:decr(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：decrby 函数，将 key 中储存的数字加上指定的增量值
          key 不存在，先创建key，再累计 1
    key : 键
    decrement:减量
    return:返回两个值
        res:nil/key decrby decrement 后的值    -- 出现异常 res 返回nil
        err:错误信息
]]
function cache:decrby(key,decrement)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:decrby(key,decrement)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：exists 函数，检查key是否存在
    key : 键
    return:返回两个值
        res：nil / 0 ／ 1   若 key 存在返回 1 ，否则返回 0
        err：错误信息
]]
function cache:exists(key)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:exists(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：Expire 命令用于设置 key 的过期时间。key 过期后将不再可用，单位"秒"
    key：键
    seconds ：过期时间，单位"秒"
    return:返回两个值
        res:nil / 0 / 1  设置成功返回 1;当 key 不存在或者不能为 key 设置过期时间时返回 0
        err:错误信息
]]
function cache:expire(key,seconds)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:expire(key,seconds)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：persist 用于移除给定 key 的过期时间，使得 key 永不过期
    key：键
    return:返回两个值
        res:nil / 0 / 1  当过期时间移除成功时，返回 1 。 如果 key 不存在或 key 没有设置过期时间，返回 0
        err:错误信息
]]
function cache:persist(key,seconds)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:persist(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

-- ================= list 操作 ======================

--[[
    功能：lupsh 用于将一个或多个值插入到列表头部
    key：键
    ...: 具体值数组
    return:返回两个值
        res:nil／ 列表的长度
        err:错误信息
]]
function cache:lpush(key,...)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    local args = { ... }
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:lpush(key,unpack(args))
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：rpush 用于将一个或多个值插入到列表的尾部(最右边)
        如果列表不存在，一个空列表会被创建并执行 RPUSH 操作。 当列表存在但不是列表类型时，返回一个错误。
    key：键
    ...: 具体值数组
    return:返回两个值
        res:nil／ 列表的长度
        err:错误信息
]]
function cache:rpush(key,...)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    local args = { ... }
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:rpush(key,unpack(args))
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：add 用于在列表尾部添加值
        如果列表不存在，一个空列表会被创建并执行 add 操作。 当列表存在但不是列表类型时，返回一个错误。
    key：键
    val:值 --string
    return:返回两个值
        res:nil／ add 后列表的长度
        err:错误信息
]]
function cache:add(key,val)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:rpush(key,val)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：add_table 用于向列表中添加值
        如果列表不存在，一个空列表会被创建并执行 add 操作。 当列表存在但不是列表类型时，返回一个错误。
    key：键
    val:值 - table
    is_right ：true / false 默认从头部添加
    return:返回两个值
        res:nil／ add 后列表的长度
        err:错误信息
]]
function cache:add_json(key,val,is_right)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    if type(val) ~= "table" then
        return nil,"parameter type error"
    end
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        if is_right then
            return r:rpush(key,json.encode(val))
        else
            return r:lpush(key,json.encode(val))
        end
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：llen 用于返回列表的长度,如果列表 key 不存在，则 key 被解释为一个空列表，返回 0
    key：键
    return:返回两个值
        res:nil／ 0 / 列表具体长度
        err:错误信息
]]
function cache:llen(key)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:llen(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：lindex 用于通过索引获取列表中的元素
    key：键
    index: 索引位置
    return:返回两个值
        res:nil／ 索引位置具体值
        err:错误信息
]]
function cache:lindex(key,index)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:lindex(key,index)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：lrange 返回列表中指定区间内的元素，区间以偏移量 START 和 END 指定
         其中 0 表示第一个元素
    key：键
    start: 索引起始位置
    _end:索引结束位置
        res:nil／ 返回具体列表数据
        err:错误信息
]]
function cache:lrange(key,start,_end)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:lrange(key,start,_end)
end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：lrange 返回列表中指定区间内的元素，区间以偏移量 START 和 END 指定
         其中 0 表示第一个元素
    key：键
    start: 索引起始位置
    _end:索引结束位置
        res:nil／ 返回具体列表数据
        err:错误信息
]]
function cache:lrange_json(key,start,_end)

    local res,err = cache.lrange(self,key,start,_end)

    if res and #res > 0 then
        local result = {}
        for _, v in ipairs(res) do
            table.insert(result,json.decode(v))
        end
        return result,nil
    end
    return nil,err
end

--[[
    功能：lpop 命令用于移除并返回列表的第一个元素。
    key：键
    return:返回两个值
        res:nil／ 列表的第一个元素
        err:错误信息
]]
function cache:lpop(key)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:lpop(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：rpop 移除并返回列表的最后一个元素
    key：键
    return:返回两个值
        res:nil／ 列表的最后一个元素
        err:错误信息
]]
function cache:rpop(key)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:rpop(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：lget 根据key获取所有元素
    key：键
    return:返回两个值
        res:nil／ key 对应列表值
        err:错误信息
]]
function cache:lget(key)

    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:eval(lua_script.lget,1,key)
    end)

    if res == ngx.null then
        return nil,nil
    end

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    功能：lget_json 根据key获取所有元素,每个元素均为table格式
    例如：[{},{}]
    key：键
    return:返回两个值
        res:nil／ key 对应列表值
        err:错误信息
]]
function cache:lget_json(key)
    local res,err = cache.lget(self,key)

    if res and #res > 0 then
        local result = {}
        for _, v in ipairs(res) do
            table.insert(result,json.decode(v))
        end
        return result,nil
    end

    return nil,err
end

-- ======================== set 操作 =====================
--[[
    sadd 将一个或多个成员元素加入到集合中，已经存在于集合的成员元素将被忽略.
         key 不存在则创建
         key 不是集合类型，返回错误
    参数：
        key：操作key
        ...:插入key，对应的val值

     return：返回两个值
        res:nil ／ 被添加到集合中的新元素的数量，不包括被忽略的元素。
        err:错误信息
]]
function cache:sadd(key,...)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    local args = { ... }

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:sadd(key,unpack(args))
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    scard 命令返回集合中元素的数量。
    参数：
        key：操作key

     return：返回两个值
        res:nil ／ 0 / 元素数量
        err:错误信息
]]
function cache:scard(key,val)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:scard(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    sismember 命令判断成员元素是否是集合的成员
    参数：
        key：操作key
        val:值

     return：返回两个值
        res:nil ／ 1 / 0 ；如果成员元素是集合的成员，返回 1 。 如果成员元素不是集合的成员，或 key 不存在，返回 0 。
        err:错误信息
]]
function cache:sismember(key,val)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:sismember(key,val)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    sdiff 命令返回给定集合之间的差集。不存在的集合 key 将视为空集
    参数：
        first_key: 差集的结果来源
        ...：动态key

     return：返回两个值
        res:nil ／ 包含差集成员的列表
        err:错误信息
]]
function cache:sdiff(first_key,...)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    local args = { ... }

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:sdiff(first_key,unpack(args))
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    sinter 返回给定所有给定集合的交集。
          不存在的集合 key 被视为空集。 当给定集合当中有一个空集时，结果也为空集
    参数：
        ...：动态key

     return：返回两个值
        res:nil ／ 交集成员的列表
        err:错误信息
]]
function cache:sinter(...)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    local args = { ... }

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:sinter(unpack(args))
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    smembers 返回集合中的所有的成员。 不存在的集合 key 被视为空集合
    参数：
        key：操作key

     return：返回两个值
        res:nil ／ 集合成员的列表
        err:错误信息
]]
function cache:smembers(key)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:smembers(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    smove 命令将指定成员 member 元素从 source 集合移动到 destination 集合。原子性操作。
    参数：
        source：源key
        destination: 目标key
        member:要移动的元素
     return：返回两个值
        res:nil ／ 0 / 1
        err:错误信息
]]
function cache:smove(source,destination,member)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:smove(source,destination,member)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    srem 命令用于移除集合中的一个或多个成员元素，不存在的成员元素会被忽略。
    参数：
        key：操作key
        member:要移除的元素
     return：返回两个值
        res:nil ／ 0 / 被成功移除的元素的数量
        err:错误信息
]]
function cache:srem(key,member)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:srem(key,member)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    sunion 返回给定集合的并集。不存在的集合 key 被视为空集
    参数：
        ...：传入操作key
     return：返回两个值
        res:nil / 并集成员的列表。
        err:错误信息
]]
function cache:sunion(...)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    local args = { ... }
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:sunion(unpack(args))
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

-- =============== sorted set 操作 =================

--[[
    zadd 命令用于将一个或多个成员元素及其分数值加入到有序集当中。
    参数：
        key : 操作key
        ...：score 与 value 对
     return：返回两个值
        res:nil ／被成功添加的新成员的数量
        err:错误信息
]]
function cache:zadd(key,...)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    local args = { ... }
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:zadd(key,unpack(args))
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    zcard 命令用于计算集合中元素的数量。
    参数：
        key : 操作key
     return：返回两个值
        res:nil ／ 0 / 有序集的数量
        err:错误信息
]]
function cache:zcard(key)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:zcard(key)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    zcount 命令用于计算有序集合中指定分数区间的成员数量。
    参数：
        key : 操作key
        min : 最小分数
        max : 最大分数
     return：返回两个值
        res:nil ／ 0 / 有序集的数量
        err:错误信息
]]
function cache:zcount(key,min,max)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:zcount(key,min,max)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    zincrby 命令对有序集合中指定成员的分数加上增量 increment
    参数：
        key : 操作key
        increment : 分数增量
        member : 元素
     return：返回两个值
        res:nil ／ member 成员的新分数值，以字符串形式表示
        err:错误信息
]]
function cache:zincrby(key,increment,member)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:zincrby(key,increment,member)
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    zrange 返回有序集中，指定区间内的成员。
           其中有序集成员按分数值递增(从小到大)顺序排列
    参数：
        key : 操作key
        start : 下标起始值 例如：0 表示第1个元素
        stop : 最大分数 例如： -1 表示最后一个元素
        flag : true / false  是否返回scores； 默认为 false
     return：返回两个值
        res:nil / 指定区间内，带有分数值(可选)的有序集成员的列表。
        err:错误信息
]]
function cache:zrange(key,start,stop,flag)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        if flag then
            return r:zrange(key,start,stop,"withscores")
        else
            return r:zrange(key,start,stop)
        end
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end


--[[
    zrevrange 命令返回有序集中，指定区间内的成员
              其中成员的位置按分数值递减(从大到小)来排列
    参数：
        key : 操作key
        start : 下标起始值 例如：0 表示第1个元素
        stop : 最大分数 例如： -1 表示最后一个元素
        flag : true / false  是否返回scores； 默认为 false
     return：返回两个值
        res:nil / 指定区间内，带有分数值(可选)的有序集成员的列表。
        err:错误信息
]]
function cache:zrevrange(key,start,stop,flag)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        if flag then
            return r:zrevrange(key,start,stop,"withscores")
        else
            return r:zrevrange(key,start,stop)
        end    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    zscore 命令返回有序集中，成员的分数值
    参数：
        key : 操作key
        member : 元素
     return：返回两个值
        res:nil / 成员的分数值，以字符串形式表示
        err:错误信息
]]
function cache:zscore(key,member)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:zscore(key,member)
     end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    zrem 用于移除有序集中的一个或多个成员
    参数：
        key : 操作key
        ... : 移除元素列表
     return：返回两个值
        res:nil ／ 0 / 被成功移除的成员的数量
        err:错误信息
]]
function cache:zrem(key,...)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    local args = { ... }
    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:zrem(key,unpack(args))
    end)

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end
end

--[[
    eval 命令使用 Lua 解释器执行脚本
    参数：
        script
        numkeys
        key [key....]
        arg [arg ...]

     return：返回两个值
        res:执行lua脚本返回的值 / nil
        err:错误信息
]]
function cache:eval(...)
    -- 1、connect 校验
    local check_res,err = check_connect(self.redis)
    if err then
        return nil,err;
    end
    local args = { ... }

    -- 2、执行命令
    local res,err = self.redis:exec(function (r)
        return r:eval(unpack(args))
    end)

    if res == ngx.null then
        return nil,nil
    end

    -- 3、包装结果
    if err then
        return nil,err
    else
        return res,nil
    end

end


return cache;