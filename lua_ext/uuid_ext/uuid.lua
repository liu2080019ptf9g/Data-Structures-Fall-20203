-- Modified by Kevin.XU @2016/8/20

local ffi = require "ffi"
local ffi_new = ffi.new
local ffi_str = ffi.string

local _M = { _VERSION = '0.01' }

ffi.cdef[[
void uuid8(char *out);
void uuid20(char *out);
void uuid32(char *out);
]]

local libuuid = ffi.load("libuuidx")

function _M.gen8()
    if libuuid then
        local result = ffi_new("char[9]")
        libuuid.uuid8(result)
        return ffi_str(result)
    end
end

function _M.gen20()
    if libuuid then
        local result = ffi_new("char[21]")
        libuuid.uuid20(result)
        return ffi_str(result)
    end
end

function _M.gen32()
    if libuuid then
        local result = ffi_new("char[37]")
        libuuid.uuid32(result)
        local ret = ffi_str(result)
        return string.gsub(ret,"-","")
    end
end

return _M

