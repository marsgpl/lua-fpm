--

package.path = "./src/?.lua;" .. package.path

local FcgiServer = require "src/FcgiServer"

FcgiServer:new{ conf="conf.lua" }
