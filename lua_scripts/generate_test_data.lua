-- Generate data for test
-- Written by Kevin.XU
-- 2016/8/30

--[[
URL parameter: 
type: uuid | root_token | access_token
count: ?
ip : ?
]]

ngx.req.read_body()

local resty_cjson = require "cjson"
local resty_string = require "resty.string"
local resty_uuid = require "resty.uuid"
local limit_toolkit = require "ddtk.limit_tk"
local limit_policy = require "ddtk.limit_policy"

local args = ngx.req.get_uri_args()

local type = args["type"]
local count = tonumber(args["count"])
local ip = args["ip"]


for i=1,count do 
    if type == "uuid" then 
        ngx.say(resty_uuid.gen32())
    end
    if type == "root_token" then 
        ngx.say(limit_toolkit.token_encode(resty_uuid.gen32(),limit_policy.get_root_secret_key()))
    end
    if type == "access_token" then 
        ngx.say(limit_toolkit.generate_access_token(ip,limit_policy.get_secret_key(),limit_toolkit.get_default_algorithm_plan()))
    end
end 
