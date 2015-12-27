--

local trace = require "trace"

local class = require "class"
local zmq = require "zmq"

local Panicable = require "Panicable"

--

local c = class:FcgiWorker {
    id = false,
    args = false,
    zmqctx = false,
    queue = false,
}:extends{ Panicable }

--

function c:init()
    Panicable.init(self)

    self:init_zmq()
    self:init_queue(self.args)

    self:process()
end

function c:init_zmq()
    self.zmqctx = self:assert(zmq.context())
end

function c:init_queue( conf )
    self.queue = self:assert(self.zmqctx:socket(zmq.f.ZMQ_STREAM))
    self:assert(self.queue:connect(conf.queue))
end

function c:process()
    while true do
        zmq.sleep(1)
    end
end

--

return c
