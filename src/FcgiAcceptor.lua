--

local trace = require "trace"

local thread = require "thread"
local class = require "class"
local zmq = require "zmq"

local Panicable = require "Panicable"

--

local c = class:FcgiAcceptor {
    zmqctx = false,
    queue = false,
    listener = false,
}:extends{ Panicable }

--

function c:init()
    Panicable.init(self)

    self.zmqctx = self:assert(zmq.context())

    self:init_listener(thread.args())

    self:init_queue(thread.args())

    self:process()
end

function c:process()
    while zmq.poll{ self.listener, self.queue } do
        self:process_listener()
        self:process_queue()
    end
end

function c:process_listener()
    while true do
        local r, es = self.listener:recv(1)

        if not r then
            return
        end

        trace(r)
    end
end

function c:process_queue()
    while true do
        local r, es = self.queue:recv(1)

        if not r then
            return
        end

        trace(r)
    end
end

function c:init_listener( conf )
    self.listener = self:assert(self.zmqctx:socket(zmq.f.ZMQ_STREAM))
    self:assert(self.listener:bind(conf.addr))
end

function c:init_queue( conf )
    self.queue = self:assert(self.zmqctx:socket(zmq.f.ZMQ_STREAM))
    self:assert(self.queue:bind(conf.queue))
end

--

return c
