-- Set Cookie and Header
-- Written by Kevin.XU
-- 2016/8/26

local resty_cookie = require "resty.cookie"
local limit_policy = require "ddtk.limit_policy"

if ngx.ctx.access_token ~= nil and ngx.ctx.remote_user_type ~= nil then
    if ngx.ctx.remote_user_type == 1 then
        ngx.header[limit_policy.get_access_token_key_name()] = ngx.ctx.access_token
    else 
        local cookie, err = resty_cookie:new()
        if cookie ~= nil then
            cookie:set({
                key = limit_policy.get_access_token_key_name(), 
                value = ngx.ctx.access_token, 
                path = limit_policy.get_cookie_path(), 
                domain = limit_policy.get_cookie_domain(), 
                httponly = true
            })
        end
    end
end

if ngx.ctx.cost_msecs ~= nil then
    ngx.header["cost_msecs"] = ngx.ctx.cost_msecs
end
