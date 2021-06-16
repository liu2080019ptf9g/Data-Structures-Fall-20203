-- Config of redis nodes 
-- Written by Kevin.XU
-- 2016/7/25


local _M = {
    _VERSION = '0.1'
}

-- config all redis nodes at here 
local master_redis_node = {
    '127.0.0.1',6379
}
local slave_redis_nodes = {
    {'127.0.0.1',6379}
}

-- select master redis node
function _M.select_master_redis_node()
    return master_redis_node[1],master_redis_node[2]
end

-- select one slave redis node
function _M.select_slave_redis_node()
    local size = table.getn(slave_redis_nodes)
    if size == 0 then
        return nil
    end
    local t = os.time()
    local idx = (t % size) + 1
    return slave_redis_nodes[idx][1],slave_redis_nodes[idx][2]
end

return _M