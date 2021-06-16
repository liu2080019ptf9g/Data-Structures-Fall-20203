-- Request Limitation Entrance 
-- Written by Kevin.XU
-- 2016/8/17

--[[
For example######

    deal config >>>>>
    
    filters = {
        "read_params",
        "single_qps",
        {
            {"entire_qps", "reset_access_token"},
            {"check_root_token", "check_access_token", "reset_access_token"},
        }
    }

    shopping config >>>>>
    
    filters = {
        "read_params",
        "single_qps",
        {
            {"entire_qps", "reset_access_token"},
            {"check_access_token", "reset_access_token"},
        }
    }
    
    filters = {
        "read_params",
        "single_qps",
        {
            "url_while_list",
            {
                {
                    {"entire_qps", "reset_access_token"},
                    {"check_access_token", "reset_access_token"},
                }
            }
        }
    }
    
    filters = {
        "read_params",
        "single_qps",
        {
            "url_while_list",
            "entire_qps",
        }
    }
    
    filters = {
        "read_params",
        {
            "url_while_list",
            {
                "single_qps",
                "entire_qps",
            }
        }
    }
]]


local limit_policy = require "ddtk.limit_policy"
local timetk = require "ddtk.timetk"
local resty_cjson = require "cjson"


function print_cost_time(begin_msecs,message)
    local end_msecs = timetk.get_now_micro_secs()
    local cost_msecs = end_msecs - begin_msecs
    ngx.ctx.cost_msecs = cost_msecs
    ngx.log(ngx.INFO, message..", COST TIME MICRO SECS : "..cost_msecs)
end

--
local begin_micro_secs = timetk.get_now_micro_secs()

-- read http request
ngx.req.read_body()

local original_url = ngx.var.scheme .. "://" .. ngx.var.host .. ngx.var.request_uri
-- ngx.log(ngx.INFO, "original_url="..original_url)
-- ngx.log(ngx.INFO, "ngx.var.query_string="..ngx.var.query_string)
-- ngx.log(ngx.INFO, "ngx.var.uri="..ngx.var.uri)


----------------------------------------------------------------------------------------------------------------------
-----------------------------------------Split flow-------------------------------------------
if limit_policy.is_enable_split() then
    local spliters = limit_policy.get_spliters()
    if spliters ~= nil then
        local spliter_count = #(spliters)
        if spliter_count > 0 then
            for i=1, spliter_count do      
                local element = spliters[i]
                local spliter_module = require("ddtk.spliters."..element)
                local target = spliter_module.split(ngx,limit_policy)
                if target ~= nil then
                    ngx.var.backend_name = target
                    print_cost_time(begin_micro_secs,"split flow to "..target)
                    return 
                end
            end
        end
    end
end
----------------------------------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------------------------------
-----------------------------------------Check the switch of limiting flow-------------------------------------------
-- if disable limit, then allow it directly
if not limit_policy.is_enable_limit() then
    print_cost_time(begin_micro_secs,"disable limit & continue ...")
    return
end
----------------------------------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------------------------------
-----------------------------------------Define basic variables-------------------------------------------
-- custom definations
local deny_url = limit_policy.get_deny_url()
local login_url = limit_policy.get_login_url()
local remote_user_type = limit_policy.get_remote_user_type()

-- context parameters used by the filter chain
local context_parameters = {}

-- set nginx conext variables
ngx.ctx.remote_user_type = remote_user_type

----------------------------------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------------------------------
-----------------------------------------Filter chain of limiting flow-------------------------------------------

local filters_top_logic_op = limit_policy.get_filters_top_logic_op()
local filters = limit_policy.get_filters()

--need the following configs ::
--
--http {
--    .....
--    lua_shared_dict degrade_url_mapping 10m;
--    .....
--}
--query this uri's degrade url
function query_degrade_url(url)
    local degrade_url_mapping = ngx.shared["degrade_url_mapping"]
    if degrade_url_mapping == nil then
        return nil
    end     
    local degrade_url = degrade_url_mapping:get(url)
    if degrade_url ~= nil then
        return degrade_url
    end
    return nil
end

-- return opposite operation
-- allow param : and | or
function opposite_op(op)
    if op == "and" then
        return "or"
    else 
        return "and"
    end
end

--next level handle
function handle_next_level(level, element, op, ngx, limit_policy, context_parameters)
    if type(element) == "string" then
        -- execute one
        local module_name = element
        local filter_module = require("ddtk.filters."..module_name)
        local result, comment = filter_module.filtrate(ngx,limit_policy,context_parameters)
        ngx.log(ngx.DEBUG, string.rep("->",level).." - "..module_name.." filter result is "..result )
        return result, comment
    else
        -- execute list
        ngx.log(ngx.DEBUG, string.rep("->",level).." - filter list is "..resty_cjson.encode(element)..", op is "..op )
        local ele_count = #element
        for i=1, ele_count do
            local ele = element[i]
            local result, comment = handle_next_level(level*2,ele,opposite_op(op),ngx,limit_policy,context_parameters)
            ngx.log(ngx.DEBUG, string.rep("->",level).." - filter result is "..result )
            while true do
                if i == ele_count then
                    return result, comment
                else
                    if result == 1 then
                        --check success
                        if op == "and" then
                            break
                        else
                            return result, comment
                        end
                    else
                        --check failed
                        if op == "and" then
                            return result, comment
                        else
                            break
                        end
                    end
                end
            end
        end
    end
end


if filters == nil then
    print_cost_time(begin_micro_secs,"not found filters & continue ...")
    return
end
local filter_count = #(filters)
if filter_count == 0 then
    print_cost_time(begin_micro_secs,"not define filters & continue ...")
    return
end

ngx.log(ngx.DEBUG, "filters top logic op is "..filters_top_logic_op)
for i=1, filter_count do
    local element = filters[i]
    local result, comment = handle_next_level(2, element, opposite_op(filters_top_logic_op), ngx, limit_policy, context_parameters)
    ngx.log(ngx.DEBUG, "-> - filter result is "..result)
    -- result means 
    -- 1 : allow
    -- 3 : deny
    -- 4 : not login or session expired
    -- 5 : error 
    -- the cause of using 'while true do' is that lua language has not the keyword 'continue' 
    while true do
        if result == 1 then 
            ngx.log(ngx.DEBUG, "allow")
            if i==filter_count then
                print_cost_time(begin_micro_secs,"allow")
                return
            else
                if filters_top_logic_op == "and" then
                    --ignore this
                    ngx.log(ngx.DEBUG, "handle next")
                    break
                else
                    print_cost_time(begin_micro_secs,"allow")
                    return
                end
            end
        elseif result == 3 then
            if filters_top_logic_op == "and" or (filters_top_logic_op == "or" and i==filter_count) then
                ngx.log(ngx.DEBUG, "deny")
                if ngx.ctx.remote_user_type == 0 then
                    -- degrade 
                    local degrade_url = query_degrade_url(ngx.var.uri)
                    if degrade_url ~= nil then
                        print_cost_time(begin_micro_secs, "deny")
                        return ngx.redirect(degrade_url.."?original_url="..ngx.escape_uri(original_url), 301)
                    else 
                        print_cost_time(begin_micro_secs, "deny")
                        return ngx.redirect(deny_url.."?original_url="..ngx.escape_uri(original_url), 301)
                    end
                else
                    print_cost_time(begin_micro_secs, "deny")
                    return ngx.exit(480)
                end 
            else
                --ignore this
                ngx.log(ngx.DEBUG, "handle next")
                break
            end
        elseif result == 4 then
            if filters_top_logic_op == "and" or (filters_top_logic_op == "or" and i==filter_count) then
                ngx.log(ngx.DEBUG, "not login or session expired")
                if ngx.ctx.remote_user_type == 0 then
                    print_cost_time(begin_micro_secs, "not login or session expired")
                    return ngx.redirect(login_url.."?returnurl="..ngx.escape_uri(original_url), 301)
                else
                    print_cost_time(begin_micro_secs, "not login or session expired")
                    return ngx.exit(481)
                end
            else
                --ignore this
                ngx.log(ngx.DEBUG, "handle next")
                break
            end
        elseif result == 5 then
            if filters_top_logic_op == "and" or (filters_top_logic_op == "or" and i==filter_count) then
                ngx.log(ngx.DEBUG, "internal error")
                print_cost_time(begin_micro_secs, "internal error")
                return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            else
                --ignore this
                ngx.log(ngx.DEBUG, "handle next")
                break
            end
        end
    end
end
print_cost_time(begin_micro_secs,"passed all")


----------------------------------------------------------------------------------------------------------------------
