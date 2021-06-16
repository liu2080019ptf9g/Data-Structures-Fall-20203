-- Check root token
-- Written by Kevin.XU
-- 2016/8/24

local limit_policy = require "ddtk.limit_policy"
local limit_toolkit = require "ddtk.limit_tk"
local resty_uuid = require "resty.uuid"

local _M = {
    _VERSION = '0.1'
}


-- result means 
-- 1 : allow
-- 3 : deny
-- 4 : not login or session expired
-- 5 : error
function _M.filtrate(ngx, limit_policy, context_parameters)
    local root_token = context_parameters["root_token"]
    if root_token == nil then
        ngx.log(ngx.ERR, "root_token is absent")
        return 3, nil
    end
    
    -- cut out the root token
    local p1, p2 = string.find(root_token, "_")
    if p1 ~= nil and p2 ~= nil then
        root_token = string.sub(root_token, p2+1)
    end
    
    if root_token == nil then
        ngx.log(ngx.ERR, "root_token is blank")
        return 3, nil
    end
    
    local len = string.len(root_token)
    if len ~= 64 then 
        ngx.log(ngx.ERR, "root_token length is invalid : "..len)
        return 3, nil
    end
    
    -- local source = resty_uuid.gen32()
    -- ngx.log(ngx.INFO,"source="..source)
    -- local token = limit_toolkit.token_encode(source,secret_key)
    -- ngx.log(ngx.INFO,"token="..token)
    -- local check_result = limit_toolkit.token_check(token,secret_key,string.len(source))
    -- ngx.log(ngx.INFO,"check="..tostring(check_result))
    
    local check_result = limit_toolkit.token_check(root_token,limit_policy.get_root_secret_key(),32)
    if check_result then
        return 1, nil
    else
        return 3, nil
    end
    
end

return _M
