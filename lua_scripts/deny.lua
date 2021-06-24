-- Deny tip page
-- Written by Kevin.XU
-- 2016/9/13

-- location = /deny.html {
      -- default_type text/html;
      -- content_by_lua_file /usr/local/openresty/lua_scripts/deny.lua;
-- }

-- read http request
ngx.req.read_body()

local limit_policy = require "ddtk.limit_policy"

local page = [[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
	<meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />
	<title></title>
</head>
<body>
	<style type="text/css">
	*{margin: 0;padding: 0;}
	body,.page_hurry{background:#fafafa;width:100%;}
	.page_hurry .page_hurry_inner{width:960px;margin:0 auto;height:740px;position:relative;background:#fafafa url(/resources/images/error_404.jpg) 213px 134px no-repeat;}
	.page_hurry .page_logo{position: absolute;top: 20px;left: 0px;}
	.page_hurry .page_logo img{display: block;border:0;}
	.page_hurry .back_index{display: block;width: 150px;height: 57px;background:#fafafa url(/resources/images/btn_bg.png) 0 0 no-repeat;position: absolute;left: 245px;top: 493px;}
	.page_hurry .page_num{font-family: Arial;font-size: 16px;font-weight: bold;position: absolute;top: 564px;right: 585px;color: #777;}
	</style>
	<div class="page_hurry" limit_deny_url="limit_deny_url_replace_place">
		<div class="page_hurry_inner">
		</div>
	</div>
</body>
</html>
]]

-- if limit_policy ~= nil then
    -- ngx.say("limit_policy is not nil")
-- end

local deny_url = limit_policy.get_deny_url()

-- if deny_url ~= nil then
    -- ngx.say(deny_url)
-- end

page = string.gsub(page, "limit_deny_url_replace_place", deny_url)

ngx.say(page)


