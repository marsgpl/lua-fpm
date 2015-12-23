--

package.path = "./src/?.lua;" .. package.path

local FcgiServer = require "FcgiServer"

FcgiServer:new{ conf="conf.lua" }
