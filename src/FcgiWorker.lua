--

local trace = require "trace"

local thread = require "thread"
local class = require "class"
local zmq = require "zmq"

local Panicable = require "Panicable"

--

local c = class:FcgiWorker {
    zmqctx = false,
    queue = false,
}:extends{ Panicable }

--

function c:init()
    Panicable.init(self)

    self.zmqctx = self:assert(zmq.context())

    self:init_queue(thread.args())

    zmq.sleep(999999999)
end

function c:init_queue( conf )
    self.queue = self:assert(self.zmqctx:socket(zmq.f.ZMQ_STREAM))
    self:assert(self.queue:connect(conf.queue))
end

--

return c
