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
    print(class.name(self), "unbound e_onread")
end

function c:e_onwrite()
    print(class.name(self), "unbound e_onwrite")
end

function c:e_onhup()
    print(class.name(self), "unbound e_onhup")
end

function c:e_onerror( es, en )
    print(class.name(self), "unbound e_onerror: ", es, en)
end

--

return c
