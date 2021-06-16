-- Time tool
-- Written by Kevin.XU
-- 2016/7/25

local ffi = require "ffi"
local ffi_new = ffi.new
local ffi_str = ffi.string

local _M = { _VERSION = '0.01' }

ffi.cdef[[
    struct timeval {
        long int tv_sec;
        long int tv_usec;
    };
    int gettimeofday(struct timeval *tv, void *tz);
]]


function _M.get_now_micro_secs()
    local tm = ffi.new("struct timeval")
    ffi.C.gettimeofday(tm, nil)
    local sec = tonumber(tm.tv_sec)
    local usec = tonumber(tm.tv_usec)
    return sec * 1000000 + usec
end

return _M
