-- QPS by all users with burst
-- Written by Kevin.XU
-- 2016/8/22

--need the following configs ::
--
--http {
--    .....
--    lua_shared_dict aqps_limit_locks 1m;
--    lua_shared_dict aqps_limit_counter 1m;
--    .....
--}
--
--
--Refer the Token Bucket Algorithm by Guava of Google 
--

local locks = require "resty.lock"
local timetk = require "ddtk.timetk"

local _M = {
    _VERSION = '0.1'
}


-- result means 
-- 1 : allow
-- 3 : deny
-- 4 : not login or session expired
-- 5 : error
function _M.filtrate(ngx, limit_policy, context_parameters)
    local entire_qps    = limit_policy.get_entire_qps()
    local entire_bucket = limit_policy.get_entire_bucket()
    local cost_microsecs_per_token = (1 * 1000000) / entire_qps
    
    local aqps_limit_counter = ngx.shared.aqps_limit_counter
    local left_tokens_count_key = "left_tokens_count"
    local last_access_time_key  = "last_access_time"
    local aqps_limit_lock_key = "aqps_limit_lock"
    
    local now_micro_secs = timetk.get_now_micro_secs()
    ngx.log(ngx.INFO, "now_micro_secs="..now_micro_secs)
    
    local return_value = 0
    
    -- require lock
    local lock = locks:new("aqps_limit_locks")
    local elapsed, err = lock:lock(aqps_limit_lock_key)
    if elapsed == nil then
        ngx.log(ngx.ERR, "require aqps_limit lock failed : ",aqps_limit_lock_key)
        return 1, nil
    end
    
    local left_tokens_count = aqps_limit_counter:get(left_tokens_count_key) or 0
    local last_access_time  = aqps_limit_counter:get(last_access_time_key) or (now_micro_secs-60*60*1000000)
    
    --put token
    if now_micro_secs > last_access_time then 
        left_tokens_count = math.min( entire_bucket, left_tokens_count + (now_micro_secs-last_access_time)/cost_microsecs_per_token )
        last_access_time = now_micro_secs
    end
    
    --require token
    if left_tokens_count > 0 then 
        return_value = 1
        left_tokens_count = left_tokens_count - 1
        ngx.log(ngx.INFO, "token bucket have left tokens : ",left_tokens_count)
    else
        ngx.log(ngx.ERR, "token bucket is empty ")
        return_value = 3
    end
    
    --store value
    aqps_limit_counter:set(left_tokens_count_key, left_tokens_count, 0)
    aqps_limit_counter:set(last_access_time_key, last_access_time, 0)
    
    -- release lock
    lock:unlock()
    
    return return_value, nil
end

return _M
