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
    self:say_to_acceptor_we_are_ready()

    self:process()
end

function c:init_zmq()
    self.zmqctx = self:assert(zmq.context())
end

function c:init_queue( conf )
    local sock = self:assert(self.zmqctx:socket(zmq.f.ZMQ_REQ))
    local fd = sock:get(zmq.f.ZMQ_FD)

    self:assert(sock:connect(conf.queue))

    self.queue = {
        fd = fd,
        sock = sock,
        can_read = true,
        can_write = true,
    }
end

function c:say_to_acceptor_we_are_ready()
    trace(self.queue.sock:send("+", 1))
end

function c:process()
    while true do
        zmq.sleep(1)
    end
end

--

return c
