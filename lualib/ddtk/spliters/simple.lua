-- spliter for test 
-- Written by Kevin.XU
-- 2016/9/1


local _M = {
    _VERSION = '0.1'
}


-- result means split target backend name
function _M.split(ngx, limit_policy)
    local need_split_target = {
        ["/a/b"] = "1",
        ["/a/c"] = "1",
        ["/a/d"] = "1",
    }
    local uri = ngx.var.uri
    if need_split_target[uri] ~= nil then
        return "backend_servers_2"
    end
    return nil
end

return _M
