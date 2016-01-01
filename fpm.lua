--

package.path = package.path .. ";./src/?.lua"

local std = require "std"
local FcgiServer = require "FcgiServer"

assert(std.strict())

FcgiServer:new{ conf=(arg[1] or "conf.lua") }
