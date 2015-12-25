--

package.path = "./src/?.lua;" .. package.path

local FcgiWorker = require "FcgiWorker"

FcgiWorker:new{}
