--

local class = require "class"

local FcgiSocket = require "FcgiSocket"

--

local c = class:FcgiSocketClient {
}:extends{ FcgiSocket }

--

return c
