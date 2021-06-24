-- Request Limitation Policy Module For Dangdang.com
-- Written by Kevin.XU
-- 2016/7/19

--need the following configs ::
--
--http {
--    .....
--    lua_shared_dict limit_config_list 10m;
--    .....
--}
--

local resty_cjson = require "cjson"
local timetk = require "ddtk.timetk"

local local_storage_config_file = "/usr/local/openresty/lualib/ddtk/limit_policy.json"
local max_refresh_micro_secs = 30 * 1000 * 1000

local limit_config_list = ngx.shared["limit_config_list"]

--[[
local data = {
    --version use seconds of time, increase progressively
    version = 1472000000,
    --enable limit or not
    enable_limit = true,
    --offline|ip|token
    personal_key = "offline",
    --personal QPS
    personal_qps = 8,
    --entire QPS
    entire_qps   = 50,
    --entire burst size
    entire_bucket= 200,
    --secret key for access token
    secret_key = "123456789",
    --secret key for root token
    root_secret_key = "ed2e7d8be5287ecdcc42671bed057a32",
    --max interval for continuous access, unit is second
    max_access_interval_secs = 10*60,
    --write cookie using this domain value and path value
    cookie_domain = "10.255.209.66",
    cookie_path = "/",
    --friend page for deny
    deny_url = "http://10.255.209.66/deny",
    --login url
    login_url = "http://login.dangdang.com/signin.aspx",
    -- access token name : shopping_token | deal_token
    access_token_key_name = "shopping_token",
    -- terminal type : 0 means pc , 1 means mobile
    remote_user_type = 0,
    -- filters defination expression
    -- logic operation is changed alternately
    -- For example
    -- at top level, relation is 'and'
    -- so, at second level, relation is 'or'
    -- so, at third level, relation is 'and'
    filters_top_logic_op = "and",
    filters = {
        "read_params",
        "single_qps",
        {
            {"entire_qps", "reset_access_token"},
            {"check_root_token", "check_access_token", "reset_access_token"},
        }
    }
}
]]

local _M = {}

local cached_objs = {}
local last_micro_secs = timetk.get_now_micro_secs()

--query config
function _M.read_config()
    local file = io.open(local_storage_config_file,"r")
    if file == nil then
        return "Not found "..local_storage_config_file
    end
    local content = file:read("*all")
    file:close()
    return content
end

--query config
function _M.write_config(content, with_write_file)
    --write to shared memory simultaneously
    local updated_items = resty_cjson.decode(content) 
    if updated_items == nil then
        return "Wrong format of config"
    end
    local updated_version = updated_items.version
    if updated_version == nil then
        return "Missing 'version'"
    end
    if limit_config_list == nil then
        return "Not define dictionary 'limit_config_list'"
    end
    local current_version = limit_config_list.version
    if current_version ~= nil and updated_version <= current_version then
        local message = "Give up the updated information with old version : "..current_version.." , "..updated_version
        ngx.log(ngx.ERR, message)
        return message
    end
    ----settings begin
    local configs = {}
    limit_config_list:set("version", updated_version, 0)
    if limit_config_list:get("version") ~= nil then
        configs["version"] = updated_version
    end
    
    if updated_items.enable_limit ~= nil then
        limit_config_list:set("enable_limit", updated_items.enable_limit, 0)
    end
    if limit_config_list:get("enable_limit") ~= nil then
        configs["enable_limit"] = limit_config_list:get("enable_limit")
    end
    
    if updated_items.personal_key ~= nil then
        limit_config_list:set("personal_key", updated_items.personal_key, 0)
    end
    if limit_config_list:get("personal_key") ~= nil then
        configs["personal_key"] = limit_config_list:get("personal_key")
    end
    
    if updated_items.personal_qps ~= nil then
        limit_config_list:set("personal_qps", updated_items.personal_qps, 0)
    end
    if limit_config_list:get("personal_qps") ~= nil then
        configs["personal_qps"] = limit_config_list:get("personal_qps")
    end
    
    if updated_items.entire_qps ~= nil then
        limit_config_list:set("entire_qps", updated_items.entire_qps, 0)
    end
    if limit_config_list:get("entire_qps") ~= nil then
        configs["entire_qps"] = limit_config_list:get("entire_qps")
    end
    
    if updated_items.entire_bucket ~= nil then
        limit_config_list:set("entire_bucket", updated_items.entire_bucket, 0)
    end
    if limit_config_list:get("entire_bucket") ~= nil then
        configs["entire_bucket"] = limit_config_list:get("entire_bucket")
    end
    
    if updated_items.secret_key ~= nil then
        limit_config_list:set("secret_key", updated_items.secret_key, 0)
    end
    if limit_config_list:get("secret_key") ~= nil then
        configs["secret_key"] = limit_config_list:get("secret_key")
    end
    
    if updated_items.root_secret_key ~= nil then
        limit_config_list:set("root_secret_key", updated_items.root_secret_key, 0)
    end
    if limit_config_list:get("root_secret_key") ~= nil then
        configs["root_secret_key"] = limit_config_list:get("root_secret_key")
    end
    
    if updated_items.max_access_interval_secs ~= nil then
        limit_config_list:set("max_access_interval_secs", updated_items.max_access_interval_secs, 0)
    end
    if limit_config_list:get("max_access_interval_secs") ~= nil then
        configs["max_access_interval_secs"] = limit_config_list:get("max_access_interval_secs")
    end
    
    if updated_items.cookie_domain ~= nil then
        limit_config_list:set("cookie_domain", updated_items.cookie_domain, 0)
    end
    if limit_config_list:get("cookie_domain") ~= nil then
        configs["cookie_domain"] = limit_config_list:get("cookie_domain")
    end
    
    if updated_items.cookie_path ~= nil then
        limit_config_list:set("cookie_path", updated_items.cookie_path, 0)
    end
    if limit_config_list:get("cookie_path") ~= nil then
        configs["cookie_path"] = limit_config_list:get("cookie_path")
    end
    
    if updated_items.deny_url ~= nil then
        limit_config_list:set("deny_url", updated_items.deny_url, 0)
    end
    if limit_config_list:get("deny_url") ~= nil then
        configs["deny_url"] = limit_config_list:get("deny_url")
    end
    
    if updated_items.login_url ~= nil then
        limit_config_list:set("login_url", updated_items.login_url, 0)
    end
    if limit_config_list:get("login_url") ~= nil then
        configs["login_url"] = limit_config_list:get("login_url")
    end    
    
    if updated_items.access_token_key_name ~= nil then
        limit_config_list:set("access_token_key_name", updated_items.access_token_key_name, 0)
    end
    if limit_config_list:get("access_token_key_name") ~= nil then
        configs["access_token_key_name"] = limit_config_list:get("access_token_key_name")
    end
    
    if updated_items.remote_user_type ~= nil then
        limit_config_list:set("remote_user_type", updated_items.remote_user_type, 0)
    end
    if limit_config_list:get("remote_user_type") ~= nil then
        configs["remote_user_type"] = limit_config_list:get("remote_user_type")
    end
    
    if updated_items.filters_top_logic_op ~= nil then
        limit_config_list:set("filters_top_logic_op", updated_items.filters_top_logic_op, 0)
    end
    if limit_config_list:get("filters_top_logic_op") ~= nil then
        configs["filters_top_logic_op"] = limit_config_list:get("filters_top_logic_op")
    end
    
    if updated_items.enable_split ~= nil then
        limit_config_list:set("enable_split", updated_items.enable_split, 0)
    end
    if limit_config_list:get("enable_split") ~= nil then
        configs["enable_split"] = limit_config_list:get("enable_split")
    end
    
    if updated_items.filters ~= nil then
        local filters_info = resty_cjson.encode(updated_items.filters)
        --ngx.log(ngx.INFO, "filters_info="..filters_info)
        limit_config_list:set("filters", filters_info, 0)
    end
    if limit_config_list:get("filters") ~= nil then
        configs["filters"] = resty_cjson.decode(limit_config_list:get("filters")) 
    end

    if updated_items.spliters ~= nil then
        local spliters_info = resty_cjson.encode(updated_items.spliters)
        --ngx.log(ngx.INFO, "spliters_info="..spliters_info)
        limit_config_list:set("spliters", spliters_info, 0)
    end
    if limit_config_list:get("spliters") ~= nil then
        configs["spliters"] = resty_cjson.decode(limit_config_list:get("spliters")) 
    end
    
    ----settings end
    if with_write_file then
        local saved_content = resty_cjson.encode(configs)
        if saved_content == nil then
            return "Save file error : json encode error"
        end
        --write to file
        local file = io.open(local_storage_config_file,"w")
        if file == nil then
            return "Not found "..local_storage_config_file.." or not have write permission"
        end
        file:write(saved_content)
        file:close()
    end
    return "Success"
end

function _M.read_config_item_from_dic(key)
    local value, flags = limit_config_list:get(key)
    return value
end

function _M.is_enable_limit()
    return _M.read_config_item_from_dic("enable_limit") or false
end

function _M.get_personal_key()
    return _M.read_config_item_from_dic("personal_key") or "offline"
end

function _M.get_personal_qps()
    return _M.read_config_item_from_dic("personal_qps") or 3
end

function _M.get_entire_qps()
    return _M.read_config_item_from_dic("entire_qps") or 50
end

function _M.get_entire_bucket()
    return _M.read_config_item_from_dic("entire_bucket") or 200
end

function _M.get_secret_key()
    return _M.read_config_item_from_dic("secret_key") or "123456789"
end

function _M.get_root_secret_key()
    return _M.read_config_item_from_dic("root_secret_key") or "ed2e7d8be5287ecdcc42671bed057a32"
end

function _M.get_max_access_interval_secs()
    return _M.read_config_item_from_dic("max_access_interval_secs") or 1800
end

function _M.get_cookie_domain()
    return _M.read_config_item_from_dic("cookie_domain") or ".dangdang.com"
end

function _M.get_cookie_path()
    return _M.read_config_item_from_dic("cookie_path") or "/"
end

function _M.get_deny_url()
    return _M.read_config_item_from_dic("deny_url") or "/deny"
end

function _M.get_login_url()
    return _M.read_config_item_from_dic("login_url") or "/deny"
end

function _M.get_access_token_key_name()
    return _M.read_config_item_from_dic("access_token_key_name") or "shopping_token"
end

function _M.get_remote_user_type()
    return _M.read_config_item_from_dic("remote_user_type") or 0
end

function _M.get_filters_top_logic_op()
    return _M.read_config_item_from_dic("filters_top_logic_op") or "and"
end

function _M.get_filters()
    local now_micro_secs = timetk.get_now_micro_secs()
    local filters_obj = cached_objs["filters"]
    if filters_obj ~= nil and (now_micro_secs-last_micro_secs<max_refresh_micro_secs) then
        ngx.log(ngx.ERR, "TRACK: filters found from cache")
        return filters_obj
    end
    ngx.log(ngx.ERR, "TRACK: filters refresh into cache")
    local content = _M.read_config_item_from_dic("filters")
    if content == nil then
        return nil
    end
    local filters = resty_cjson.decode(content) 
    cached_objs["filters"] = filters
    last_micro_secs = now_micro_secs
    return filters
end

function _M.is_enable_split()
    return _M.read_config_item_from_dic("enable_split") or false
end

function _M.get_spliters()
    local now_micro_secs = timetk.get_now_micro_secs()
    local spliters_obj = cached_objs["spliters"]
    if spliters_obj ~= nil and (now_micro_secs-last_micro_secs<max_refresh_micro_secs) then
        ngx.log(ngx.ERR, "TRACK: spliters found from cache")
        return spliters_obj
    end
    ngx.log(ngx.ERR, "TRACK: spliters refresh into cache")
    local content = _M.read_config_item_from_dic("spliters")
    if content == nil then
        return nil
    end
    local spliters = resty_cjson.decode(content) 
    cached_objs["spliters"] = spliters
    last_micro_secs = now_micro_secs
    return spliters
end

return _M
