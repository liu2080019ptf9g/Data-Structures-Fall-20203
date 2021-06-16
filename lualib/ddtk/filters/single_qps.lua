-- QPS by single person
-- Written by Kevin.XU
-- 2016/8/22

--need the following configs ::
--
--http {
--    .....
--    lua_shared_dict sqps_limit_locks 10m;
--    lua_shared_dict sqps_limit_counter 10m;
--    .....
--}
--

local locks = require "resty.lock"

local _M = {
    _VERSION = '0.1'
}


-- result means 
-- 1 : allow
-- 3 : deny
-- 4 : not login or session expired
-- 5 : error
function _M.filtrate(ngx, limit_policy, context_parameters)
    local user_identify = context_parameters["user_identify"]
    local personal_qps = limit_policy.get_personal_qps()
    
    local sqps_limit_counter = ngx.shared.sqps_limit_counter
    local key = user_identify
    local cur_value = sqps_limit_counter:get(key)
    
    -- check current value
    if cur_value ~= nil and cur_value + 1 > personal_qps then
        ngx.log(ngx.ERR, "request exceed personal_qps : ", key)
        return 3, nil
    end
    
    -- require lock
    local lock = locks:new("sqps_limit_locks")
    local elapsed, err = lock:lock(key)
    if elapsed == nil then
        ngx.log(ngx.ERR, "require sqps_limit lock failed : ",key)
        return 1, nil
    end
    
    -- increase current value
    if cur_value == nil then
        sqps_limit_counter:set(key, 1, 1)
    else
        sqps_limit_counter:incr(key, 1)
    end
    
    -- release lock
    lock:unlock()
    
    return 1, nil
end

return _M
