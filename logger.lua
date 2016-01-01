--

package.path = package.path .. ";./src/?.lua"

local std = require "std"
local thread = require "thread"
local FcgiLogger = require "FcgiLogger"

assert(std.strict())

FcgiLogger:new(thread.args())
