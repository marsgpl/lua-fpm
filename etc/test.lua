--

local trace = require "trace"

trace.use_colors = false

-- request.params.LUA_PATH
-- request.params.LUA_ARGS
-- request.stdin

return function( request )
    return {}, trace.str(request)
end
