-- Update limit policy
-- Written by Kevin.XU
-- 2016/8/30

--[[
Request body:::
{
    "version" : 1472000000,
    "enable_limit" : true,
    "personal_key" : "offline",
    "personal_qps" : 8,
    "entire_qps"   : 50,
    "entire_bucket": 200,
    "secret_key"      : "123456789",
    "root_secret_key" : "111111111",
    "max_access_interval_secs" : 1800,
    "cookie_domain" : "10.255.209.66",
    "cookie_path" : "/",
    "deny_url"  : "/deny",
    "login_url" : "/login",
    "access_token_key_name" : "test_token",
    "remote_user_type" : 0,
    "filters_top_logic_op" : "and",
    "filters" : [
        "read_params",
        "single_qps",
        [
            ["entire_qps", "reset_access_token"],
            ["check_root_token", "check_access_token", "reset_access_token"]
        ]
    ]
}
Response body:::
"Success" or error message
]]

ngx.req.read_body()

local resty_cjson = require "cjson"
local resty_string = require "resty.string"
local limit_policy = require "ddtk.limit_policy"


--read request body 
local json_request_body_data = ngx.req.get_body_data()

local message = limit_policy.write_config(json_request_body_data, true)
return ngx.say(message)
