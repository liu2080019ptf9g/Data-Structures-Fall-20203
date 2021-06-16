-- Check access token
-- Written by Kevin.XU
-- 2016/8/26

local limit_toolkit = require "ddtk.limit_tk"
local resty_cjson = require "cjson"


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
    local user_term_ip = context_parameters["user_term_ip"]
    local secret_key = limit_policy.get_secret_key()
    local max_access_interval_secs = limit_policy.get_max_access_interval_secs()
    
    local access_token = context_parameters["access_token"]
    
    if access_token == nil then
        -- access token is absent
        ngx.log(ngx.ERR, "access_token is absent")
        return 3, nil
    else 
        -- check access token 
        local len = string.len(access_token)
        if len ~= 82 then 
            ngx.log(ngx.ERR, "access_token length is invalid : "..len)
            return 3, nil
        end
        local check_result = limit_toolkit.token_check(access_token,secret_key,50)
        if check_result then
            local source_result = limit_toolkit.disass_cross_string(string.sub(access_token,1,50),limit_toolkit.get_default_algorithm_plan())
            -- check ip
            local check_ip_result = limit_toolkit.check_access_token_ip(source_result,user_term_ip)
            if not check_ip_result then
                return 3, nil
            end
            -- check timie interval
            local check_time_result = limit_toolkit.check_access_token_time(source_result,max_access_interval_secs)
            if not check_time_result then
                return 3, nil
            end
            -- allow
            return 1, nil
        else
            -- invalid token
            return 3, nil
        end
    end
    
    return 1, nil
end

return _M
