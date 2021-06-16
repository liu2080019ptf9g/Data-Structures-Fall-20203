-- Update shared memory
-- Written by Kevin.XU
-- 2016/8/29

--[[
Request body:::
{
    "dic_name":"url_white_list",
    "operation":"insert",
    "records" : [
        {
            "key"   : "/abc/def",
            "value" : "1"
        },
        {
            "key"   : "/def/qwe",
            "value" : "1"
        }
    ]
}
Response body:::
{
    "status":0,
    "status_desc":""
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
local operation = request_body.operation
local records = request_body.records

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

if operation == nil then
    resp['status'] = -1
    resp['status_desc'] = "Missing operation "
    local resp_json = resty_cjson.encode(resp) 
    return ngx.say(resp_json)
end

if records == nil then
    resp['status'] = -1
    resp['status_desc'] = "Missing records "
    local resp_json = resty_cjson.encode(resp) 
    return ngx.say(resp_json)
end

operation = string.lower(operation)
if operation == "insert" then
    --insert records
    for i = 1, #records do 
        local record = records[i]
        dic:set(record.key, record.value, 0)
    end  
elseif operation == "delete" then
    --delete records
    for i = 1, #records do 
        local record = records[i]
        dic:delete(record.key)
    end
else
    resp['status'] = -1
    resp['status_desc'] = "Invalid operation : "..operation
    local resp_json = resty_cjson.encode(resp) 
    return ngx.say(resp_json)
end


local resp_json = resty_cjson.encode(resp) 
ngx.say(resp_json)

