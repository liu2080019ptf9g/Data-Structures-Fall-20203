-- IP black list
-- Written by Kevin.XU
-- 2016/8/18

--need the following configs ::
--
--http {
--    .....
--    lua_shared_dict ip_black_list 10m;
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
    local ip_black_list = ngx.shared["ip_black_list"]
    if ip_black_list == nil then
        return 1, nil
    end 
    local ip = context_parameters["user_term_ip"]
    local cur_value = ip_black_list:get(ip)
    if cur_value ~= nil then
        ngx.log(ngx.ERR, "ip is in black ip list : ",ip)
        return 3, nil
    else
        return 1, nil
    end
end

return _M
