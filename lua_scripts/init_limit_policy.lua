-- Init the limit policy 
-- Written by Kevin.XU
-- 2016/8/30


local limit_policy = require "ddtk.limit_policy"


local content = limit_policy.read_config()

limit_policy.write_config(content, false)

