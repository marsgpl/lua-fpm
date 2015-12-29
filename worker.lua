--

package.path = package.path .. ";./src/?.lua"

local std = require "std"
local thread = require "thread"
local FcgiWorker = require "FcgiWorker"

assert(std.strict())

FcgiWorker:new{ id=thread.id(), args=thread.args() }
