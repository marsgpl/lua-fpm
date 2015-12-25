--

package.path = "./src/?.lua;" .. package.path

local FcgiAcceptor = require "FcgiAcceptor"

FcgiAcceptor:new{}
