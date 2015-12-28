--

local class = require "class"

local FcgiSocket = require "FcgiSocket"

--

local c = class:FcgiSocketAcceptor {
}:extends{ FcgiSocket }

--

return c
