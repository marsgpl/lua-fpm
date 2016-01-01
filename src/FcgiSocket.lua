--

local class = require "class"

--

local c = class:FcgiSocket {
    fd = false,
    sock = false,
    worker = false,
}

--

function c:e_onread()
end

function c:e_onwrite()
end

function c:e_onhup()
end

function c:e_onerror( es, en )
end

--

return c
