--

package.path = "./src/?.lua;" .. package.path

local thread = require "thread"
local FcgiWorker = require "FcgiWorker"

FcgiWorker:new{ id=thread.id(), args=thread.args() }
