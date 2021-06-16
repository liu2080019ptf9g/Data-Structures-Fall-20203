-- URL while list
-- Written by Kevin.XU
-- 2016/8/29

--need the following configs ::
--
--http {
--    .....
--    lua_shared_dict url_white_list 10m;
--    .....
--}
--

local _M = {
    _VERSION = '0.1'
}


-- result means 
-- 1 : allow
-- 3 : deny
-- 4 : not login or session expired
-- 5 : error
function _M.filtrate(ngx, limit_policy, context_parameters)
    local url_white_list = ngx.shared["url_white_list"]
    if url_white_list == nil then
        return 3, nil
    end 
    local cur_value = url_white_list:get(ngx.var.uri)
    if cur_value ~= nil then
        ngx.log(ngx.ERR, "uri is in while list : "..ngx.var.uri)
        return 1, nil
    else
        return 3, nil
    end
end

return _M
