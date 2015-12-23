--

local class = require "class"

--

local c = class:Configurable {
}

--

function c:load_conf( path )
    return { todo=true }
end

function c:check_conf()
    return true
end

--

return c
