---
--- Compare actual value with expected value using operator type
---
--- Created by jacobs.
--- DateTime: 2018/4/19 下午6:20
---

--      =
--      !=
--      match 正则匹配
--      not_match 正则匹配后再取非
--      >
--      >=
--      <
--      <=
local _M = {
    MATCH =  "match",
    NOT_MATCH = "not_match",
    EQUALS = "equals",
    NOT_EQUALS = "not_equals",
    GT = "gt",
    LT = "lt",
    GT_EQUALS = "gt_eq",
    LT_EQUALS = "lt_eq"
}


return _M