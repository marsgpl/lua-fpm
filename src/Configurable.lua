--

local oop = require "oop"

--

local c = class:Configurable {
}

--

function c:load_conf()
    return { todo=true }
end

function c:check_conf()
    return true
end

--

return c
