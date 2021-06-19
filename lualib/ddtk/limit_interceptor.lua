-- Interceptor of limit logic  
-- Kevin.XU @2016/9/7


local limit_policy = require "ddtk.limit_policy"
local timetk = require "ddtk.timetk"
local resty_cjson = require "cjson"
local resty_cookie = require "resty.cookie"


local _M = { _VERSION = '0.01' }

local cached_modules = {}

local LOG_MARK = " FLOWLIMIT "

function _M.my_require(module_name)
    local module = cached_modules[module_name]
    if module ~= nil then
        return module
    end
    cached_modules[module_name] = require(module_name)
    return cached_modules[module_name]
end

function _M.print_cost_time(begin_msecs,message)
    local end_msecs = timetk.get_now_micro_secs()
    local cost_msecs = end_msecs - begin_msecs
    ngx.ctx.cost_msecs = cost_msecs
    ngx.log(ngx.NOTICE, LOG_MARK..message.." , COST TIME MICRO SECS : "..cost_msecs)
end

--query this uri's degrade url
function _M.query_degrade_url(url)
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
function _M.opposite_op(op)
    if op == "and" then
        return "or"
    else 
        return "and"
    end
end

--next level handle
function _M.handle_next_level(level, element, op, ngx, limit_policy, context_parameters)
    if type(element) == "string" then
        -- execute one
        local module_name = element
        local filter_module = _M.my_require("ddtk.filters."..module_name)
        local result, comment = filter_module.filtrate(ngx,limit_policy,context_parameters)
        ngx.log(ngx.DEBUG, LOG_MARK..string.rep("->",level).." - "..module_name.." filter result is "..result )
        return result, comment
    else
        -- execute list
        ngx.log(ngx.DEBUG, string.rep("->",level).." - filter list is "..resty_cjson.encode(element)..", op is "..op )
        local ele_count = #element
        for i=1, ele_count do
            local ele = element[i]
            local result, comment = _M.handle_next_level(level*2,ele,_M.opposite_op(op),ngx,limit_policy,context_parameters)
            ngx.log(ngx.DEBUG, LOG_MARK..string.rep("->",level).." - filter result is "..result )
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


function _M.load_policy()
    local content = limit_policy.read_config()
    limit_policy.write_config(content, false)
end


function _M.flowlimit_entrance()
    --record start time
    local begin_micro_secs = timetk.get_now_micro_secs()

    -- read http request
    ngx.req.read_body()

    ----------------------------------------------------------------------------------------------------------------------
    -----------------------------------------Define basic variables-------------------------------------------
    -- custom definations
    local deny_url = limit_policy.get_deny_url()
    local login_url = limit_policy.get_login_url()
    local remote_user_type = limit_policy.get_remote_user_type()
    local original_url = ngx.var.scheme .. "://" .. ngx.var.host .. ngx.var.request_uri

    -- context parameters used by the filter chain
    local context_parameters = {}

    -- set nginx conext variables
    ngx.ctx.remote_user_type = remote_user_type
    ----------------------------------------------------------------------------------------------------------------------    
    
    ----------------------------------------------------------------------------------------------------------------------
    -----------------------------------------Split flow-------------------------------------------
    if limit_policy.is_enable_split() then
        local spliters = limit_policy.get_spliters()
        if spliters ~= nil then
            local spliter_count = #(spliters)
            if spliter_count > 0 then
                for i=1, spliter_count do      
                    local element = spliters[i]
                    local spliter_module = _M.my_require("ddtk.spliters."..element)
                    local target = spliter_module.split(ngx,limit_policy)
                    if target ~= nil then
                        ngx.var.backend_name = target
                        _M.print_cost_time(begin_micro_secs,"split flow to "..target)
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
        _M.print_cost_time(begin_micro_secs,"disable limit & continue ...")
        return
    end
    ----------------------------------------------------------------------------------------------------------------------
    
    ----------------------------------------------------------------------------------------------------------------------
    -----------------------------------------Filter chain of limiting flow-------------------------------------------

    local filters_top_logic_op = limit_policy.get_filters_top_logic_op()
    local filters = limit_policy.get_filters()
    
    if filters == nil then
        _M.print_cost_time(begin_micro_secs,"not found filters & continue ...")
        return
    end
    local filter_count = #(filters)
    if filter_count == 0 then
        _M.print_cost_time(begin_micro_secs,"not define filters & continue ...")
        return
    end

    ngx.log(ngx.DEBUG, LOG_MARK.."filters top logic op is "..filters_top_logic_op)
    for i=1, filter_count do
        local element = filters[i]
        local result, comment = _M.handle_next_level(2, element, _M.opposite_op(filters_top_logic_op), ngx, limit_policy, context_parameters)
        ngx.log(ngx.DEBUG, LOG_MARK.."-> - filter result is "..result)
        -- result means 
        -- 1 : allow
        -- 3 : deny
        -- 4 : not login or session expired
        -- 5 : error 
        -- the cause of using 'while true do' is that lua language has not the keyword 'continue' 
        while true do
            if result == 1 then 
                ngx.log(ngx.DEBUG, LOG_MARK.."allow")
                if i==filter_count then
                    _M.print_cost_time(begin_micro_secs,"allow")
                    return
                else
                    if filters_top_logic_op == "and" then
                        --ignore this
                        ngx.log(ngx.DEBUG, LOG_MARK.."handle next")
                        break
                    else
                        _M.print_cost_time(begin_micro_secs,"allow")
                        return
                    end
                end
            elseif result == 3 then
                if filters_top_logic_op == "and" or (filters_top_logic_op == "or" and i==filter_count) then
                    ngx.log(ngx.DEBUG, LOG_MARK.."deny")
                    if ngx.ctx.remote_user_type == 0 then
                        -- degrade 
                        local degrade_url = _M.query_degrade_url(ngx.var.uri)
                        if degrade_url ~= nil then
                            _M.print_cost_time(begin_micro_secs, "deny")
                            --return ngx.redirect(degrade_url.."?original_url="..ngx.escape_uri(original_url), 301)
                            return ngx.redirect(degrade_url.."?original_url="..ngx.escape_uri(original_url), 302)
                        else 
                            _M.print_cost_time(begin_micro_secs, "deny")
                            --return ngx.redirect(deny_url.."?original_url="..ngx.escape_uri(original_url), 301)
                            return ngx.redirect(deny_url, 302)
                        end
                    else
                        _M.print_cost_time(begin_micro_secs, "deny")
                        return ngx.exit(480)
                    end 
                else
                    --ignore this
                    ngx.log(ngx.DEBUG, LOG_MARK.."handle next")
                    break
                end
            elseif result == 4 then
                if filters_top_logic_op == "and" or (filters_top_logic_op == "or" and i==filter_count) then
                    ngx.log(ngx.DEBUG, LOG_MARK.."not login or session expired")
                    if ngx.ctx.remote_user_type == 0 then
                        _M.print_cost_time(begin_micro_secs, "not login or session expired")
                        --return ngx.redirect(login_url.."?returnurl="..ngx.escape_uri(original_url), 301)
                        return ngx.redirect(login_url.."?returnurl="..ngx.escape_uri(original_url), 302)
                    else
                        _M.print_cost_time(begin_micro_secs, "not login or session expired")
                        return ngx.exit(481)
                    end
                else
                    --ignore this
                    ngx.log(ngx.DEBUG, LOG_MARK.."handle next")
                    break
                end
            elseif result == 5 then
                if filters_top_logic_op == "and" or (filters_top_logic_op == "or" and i==filter_count) then
                    ngx.log(ngx.DEBUG, LOG_MARK.."internal error")
                    _M.print_cost_time(begin_micro_secs, "internal error")
                    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
                else
                    --ignore this
                    ngx.log(ngx.DEBUG, LOG_MARK.."handle next")
                    break
                end
            end
        end
    end
    
    --passed
    _M.print_cost_time(begin_micro_secs,"passed all")
    ----------------------------------------------------------------------------------------------------------------------
    
end



function _M.set_response()
    if ngx.ctx.access_token ~= nil and ngx.ctx.remote_user_type ~= nil then
        if ngx.ctx.remote_user_type == 1 then
            ngx.header[limit_policy.get_access_token_key_name()] = ngx.ctx.access_token
        else 
            local cookie, err = resty_cookie:new()
            if cookie ~= nil then
                cookie:set({
                    key = limit_policy.get_access_token_key_name(), 
                    value = ngx.ctx.access_token, 
                    path = limit_policy.get_cookie_path(), 
                    domain = limit_policy.get_cookie_domain(), 
                    httponly = true
                })
            end
        end
    end
    if ngx.ctx.cost_msecs ~= nil then
        ngx.header["cost_msecs"] = ngx.ctx.cost_msecs
    end
end

return _M
