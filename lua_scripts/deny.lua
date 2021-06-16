-- Deny tip page
-- Written by Kevin.XU
-- 2016/8/18


local resty_cookie = require "resty.cookie"


-- read http request
ngx.req.read_body()

local headers = ngx.req.get_headers()
local cookie, err = resty_cookie:new()
if not cookie then
    ngx.log(ngx.ERR, err)
    return
end

ngx.say("headers : ")
for key, value in pairs(headers) do
    ngx.say(key.."="..value)
end

local cookies = cookie:get_all()
if cookies ~= nil then 
    ngx.say("cookies : ")
    for key, value in pairs(cookies) do
        ngx.say(key.."="..value)
    end
end


