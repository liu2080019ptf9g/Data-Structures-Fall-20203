-- Reset access token
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
    
    local access_token = limit_toolkit.generate_access_token(user_term_ip,secret_key,limit_toolkit.get_default_algorithm_plan())
    -- ngx.log(ngx.INFO, "access_token = "..access_token)
    
    local source_result = limit_toolkit.disass_cross_string(string.sub(access_token,1,50),limit_toolkit.get_default_algorithm_plan())
    -- ngx.log(ngx.INFO, "source_result = "..resty_cjson.encode(source_result))
    
    if ngx.ctx.remote_user_type == 1 then
        ngx.log(ngx.INFO, "set header for mobile")
        ngx.ctx.access_token = access_token
    else
        ngx.log(ngx.INFO, "set cookie for pc")
        ngx.ctx.access_token = access_token
    end
    
    return 1, nil
end

return _M
