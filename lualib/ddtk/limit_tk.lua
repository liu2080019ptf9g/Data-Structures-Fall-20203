-- Toolkit
-- Written by Kevin.XU
-- 2016/7/19


-- variables on module level
local math = require "math"
local resty_md5 = require "resty.md5"
local resty_string = require "resty.string"
local resty_uuid = require "resty.uuid"

local ngx_shared = ngx.shared
local ngx_now = ngx.now
local setmetatable = setmetatable
local tonumber = tonumber
local type = type
local assert = assert

local index_table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local counter = 1

local _M = {
    _VERSION = '0.1'
}

-- Extract IP from Nginx object
function _M.extract_ip(ngx)
    local my_ip = ngx.req.get_headers()["x_forwarded_for"]
    if my_ip == nil then
        my_ip = ngx.var.remote_addr
    end
    return my_ip
end


-- generate pseudo guid string  
function _M.guid()
    local seed={'0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'}
    local tb={}
    for i=1,32 do
        table.insert(tb,seed[math.random(1,16)])
    end
    local sid=table.concat(tb)
    local t=os.time()
    return string.format('%s-%s-%s-%s-%s-%x',
        string.sub(sid,1,8),
        string.sub(sid,9,12),
        string.sub(sid,13,16),
        string.sub(sid,17,20),
        string.sub(sid,21,32),
        t
    )
end

function _M.to_binary(integer)
    local remaining = tonumber(integer)
    local bin_bits = ''

    for i = 7, 0, -1 do
        local current_power = math.pow(2, i)

        if remaining >= current_power then
            bin_bits = bin_bits .. '1'
            remaining = remaining - current_power
        else
            bin_bits = bin_bits .. '0'
        end
    end

    return bin_bits
end

function _M.from_binary(bin_bits)
    return tonumber(bin_bits, 2)
end


function _M.to_base64(to_encode)
    local bit_pattern = ''
    local encoded = ''
    local trailing = ''

    for i = 1, string.len(to_encode) do
        bit_pattern = bit_pattern .. _M.to_binary(string.byte(string.sub(to_encode, i, i)))
    end

    -- Check the number of bytes. If it's not evenly divisible by three,
    -- zero-pad the ending & append on the correct number of ``=``s.
    if math.mod(string.len(bit_pattern), 3) == 2 then
        trailing = '=='
        bit_pattern = bit_pattern .. '0000000000000000'
    elseif math.mod(string.len(bit_pattern), 3) == 1 then
        trailing = '='
        bit_pattern = bit_pattern .. '00000000'
    end

    for i = 1, string.len(bit_pattern), 6 do
        local byte = string.sub(bit_pattern, i, i+5)
        local offset = tonumber(_M.from_binary(byte))
        encoded = encoded .. string.sub(index_table, offset+1, offset+1)
    end

    return string.sub(encoded, 1, -1 - string.len(trailing)) .. trailing
end


function _M.from_base64(to_decode)
    local padded = to_decode:gsub("%s", "")
    local unpadded = padded:gsub("=", "")
    local bit_pattern = ''
    local decoded = ''

    for i = 1, string.len(unpadded) do
        local char = string.sub(to_decode, i, i)
        local offset, _ = string.find(index_table, char)
        if offset == nil then
             error("Invalid character '" .. char .. "' found.")
        end

        bit_pattern = bit_pattern .. string.sub(_M.to_binary(offset-1), 3)
    end

    for i = 1, string.len(bit_pattern), 8 do
        local byte = string.sub(bit_pattern, i, i+7)
        decoded = decoded .. string.char(_M.from_binary(byte))
    end

    local padding_length = padded:len()-unpadded:len()

    if (padding_length == 1 or padding_length == 2) then
        decoded = decoded:sub(1,-2)
    end
    return decoded
end


function _M.md5(str)
    if not str then
        return nil
    end
    local md = resty_md5:new()
    if not md then
        ngx.log(ngx.ERR, "md5 init failed")
        return nil
    end
    md:update(str)
    local tkey = md:final()
    if not tkey then
        ngx.log(ngx.ERR, "md5 encrypt failed")
        return nil
    end
    return resty_string.to_hex(tkey)
end


function _M.token_encode(source,secret_key)
    if source == nil or secret_key == nil then
        return nil
    end
    local encoded = _M.md5(source .. secret_key)
    if encoded == nil then
        return nil
    end
    return source..encoded
end


function _M.token_check(token,secret_key,source_len)
    if token == nil or secret_key == nil or source_len == nil then
        return nil
    end
    local source = string.sub(token,1,source_len)
    local encoded = string.sub(token,source_len+1)
    local encoded_calc = _M.md5(source .. secret_key)
    if encoded_calc == encoded then
        return true
    else
        return false
    end
end


function _M.ipaddrv4_to_bin_hex(ipaddr)
    if ipaddr == nil then
        return nil
    end
    --ngx.log(ngx.INFO, "ipaddr = "..ipaddr)
    local target = ""
    iter = string.gfind(ipaddr, "(%d+)")
    local value = iter()
    while value ~= nil do
        --ngx.log(ngx.INFO, "value = "..value)
        target = target .. resty_string.to_hex(string.char(tonumber(value)))
        value = iter()
    end
    return string.lower(target)
end


local default_algorithm_plan = {
    ip   = 8,
    time = 10, 
    uuid = 32,
}

function _M.get_default_algorithm_plan()
    return default_algorithm_plan
end 

function _M.cross_merge_string(source_table, algorithm_plan)
    local pos_store = {}
    local target = {}
    local merged_count = 0
    local total_len = 0
    for key, value in pairs(algorithm_plan) do
        total_len = total_len + value
    end
    while merged_count < total_len do
        for key, value in pairs(algorithm_plan) do
            local cur_pos = pos_store[key]
            if cur_pos == nil then
                cur_pos = 1
            end
            if cur_pos <= value then
                local data = source_table[key]
                table.insert(target, string.sub(data, cur_pos, cur_pos))
                cur_pos = cur_pos + 1
                pos_store[key] = cur_pos
                merged_count = merged_count + 1
            end
        end
    end
    return table.concat(target)
end


function _M.disass_cross_string(target_str, algorithm_plan)
    local merged_count = 0
    local pos_store = {}
    local source_table = {}
    local total_len = string.len(target_str)
    while merged_count < total_len do
        local disass = false
        for key, value in pairs(algorithm_plan) do
            local cur_pos = pos_store[key]
            if cur_pos == nil then
                cur_pos = 1
            end
            if cur_pos <= value then
                local source = source_table[key]
                if source == nil then
                    source = {}
                end
                table.insert(source, string.sub(target_str, merged_count+1, merged_count+1))
                source_table[key] = source
                cur_pos = cur_pos + 1
                pos_store[key] = cur_pos
                merged_count = merged_count + 1
                disass = true
            end
        end
        if not disass then
            merged_count = merged_count + 1
        end
    end
    local source_result = {}
    for key, value in pairs(source_table) do
        source_result[key] = table.concat(value)
    end
    return source_result
end


function _M.generate_access_token(user_term_ip,secret_key,algorithm_plan)
    if user_term_ip == nil or secret_key == nil then
        return nil
    end
    -- uuid : 32 byte 
    local uuid_str = resty_uuid.gen32()
    -- time secs : 10 byte
    local now = os.time()
    -- ip : 8 byte for ipv4
    local ipaddr = _M.ipaddrv4_to_bin_hex(user_term_ip)
    
    --local source = uuid_str .. now .. ipaddr
    local source_table = {}
    source_table["uuid"] = uuid_str
    source_table["time"] = tostring(now)
    source_table["ip"] = ipaddr
    local source = _M.cross_merge_string(source_table, algorithm_plan)
    --ngx.log(ngx.INFO, "source = "..source)
    
    local access_token = _M.token_encode(source,secret_key)
    --ngx.log(ngx.INFO, "access_token = "..access_token)    

    return access_token
end


function _M.check_access_token_ip(source_result,user_term_ip)
    if source_result == nil or user_term_ip == nil then
        return false
    end
    --local saved_term_ip = string.sub(access_token,43,50)
    local saved_term_ip = source_result["ip"]
    if saved_term_ip == nil then
        return false
    end
    local current_term_ip = _M.ipaddrv4_to_bin_hex(user_term_ip)
    if current_term_ip ~= saved_term_ip then
        ngx.log(ngx.ERR, "access token 's bind ip is not identical : "..saved_term_ip..", "..current_term_ip)
        return false
    end
    return true
end


function _M.check_access_token_time(source_result,max_access_interval_secs)
    if source_result == nil or max_access_interval_secs == nil then
        return false
    end
    --local last_time = string.sub(access_token,33,42)
    local last_time = source_result["time"]
    if last_time == nil then
        return false
    end
    local now = os.time()
    local last_time_val = tonumber(last_time)
    local invertal_secs = now - last_time_val
    if invertal_secs > max_access_interval_secs then
        ngx.log(ngx.ERR, "access token 's last time is too faraway : "..invertal_secs)
        return false
    end
    return true
end


return _M
