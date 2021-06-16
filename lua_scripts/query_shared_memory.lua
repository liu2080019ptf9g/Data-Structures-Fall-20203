-- Query shared memory
-- Written by Kevin.XU
-- 2016/8/29

--[[
Request body:::
{
    "dic_name":"url_white_list",
    "key" : "/abc/def"
}
Response body:::
{
    "status":0,
    "status_desc":""
    "value" : "1"
}
]]

ngx.req.read_body()

local resty_cjson = require "cjson"
local resty_string = require "resty.string"


--read request body 
local json_request_body_data = ngx.req.get_body_data()
local request_body = resty_cjson.decode(json_request_body_data) 

--
local dic_name = request_body.dic_name
local key = request_body.key

--make response
local resp={}
resp['status']=0
resp['status_desc']=''


local dic = ngx.shared[dic_name]
if dic == nil then
    resp['status'] = -1
    resp['status_desc'] = "Not found dic : "..dic_name
    local resp_json = resty_cjson.encode(resp) 
    return ngx.say(resp_json)
end

local value = dic:get(key)

if value ~= nil then
    resp['value']=value
end

local resp_json = resty_cjson.encode(resp) 
ngx.say(resp_json)

