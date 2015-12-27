--

package.path = "./src/?.lua;" .. package.path

local thread = require "thread"
local FcgiAcceptor = require "FcgiAcceptor"

FcgiAcceptor:new{ id=thread.id(), args=thread.args() }
