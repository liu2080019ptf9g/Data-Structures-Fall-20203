-- Read parameters
-- Written by Kevin.XU
-- 2016/8/22

local resty_cookie = require "resty.cookie"
local limit_toolkit = require "ddtk.limit_tk"
local limit_policy = require "ddtk.limit_policy"

local _M = {
    _VERSION = '0.1'
}

--default is false
local test_mode = true

-- result means 
-- 1 : allow
-- 3 : deny
-- 4 : not login or session expired
-- 5 : error
function _M.filtrate(ngx, limit_policy, context_parameters)
    -- read all parameters from PC or mobile, and judge the type of the terminal
    if test_mode then
        local args = ngx.req.get_uri_args()
        context_parameters["root_token"]   = args["root_token"]
        context_parameters["access_token"] = args[limit_policy.get_access_token_key_name()]
        context_parameters["user_term_ip"] = limit_toolkit.extract_ip(ngx)
        context_parameters["user_offline_id"] = args["user_offline_id"]
    else
        --Removed 
    end
    
    local personal_key = string.lower( limit_policy.get_personal_key() )
    if personal_key == "token" then
        context_parameters["user_identify"] = context_parameters["root_token"]
    elseif personal_key == "ip" then
        if context_parameters["user_term_ip"] ~= nil then
            context_parameters["user_identify"] = context_parameters["user_term_ip"]
        else 
            context_parameters["user_identify"] = ngx.var.remote_addr
        end
    elseif personal_key == "offline" then
        context_parameters["user_identify"] = context_parameters["user_offline_id"]
    end
    
    -- for key, value in pairs(context_parameters) do
        -- ngx.log(ngx.INFO, key.."="..value)
    -- end
    
    return 1, nil 
end

return _M
