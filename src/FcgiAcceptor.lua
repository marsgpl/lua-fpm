--

local trace = require "trace"

local class = require "class"
local zmq = require "zmq"
local net = require "net"

local Panicable = require "Panicable"

--

local c = class:FcgiAcceptor {
    id = false,
    args = false,
    zmqctx = false,
    queue = false,
    listeners = {},
}:extends{ Panicable }

--

function c:init()
    Panicable.init(self)

    self:init_zmq()
    self:init_queue(self.args)
    self:init_listeners(self.args)
    self:init_epoll()

    self:process()
end

function c:init_zmq()
    self.zmqctx = self:assert(zmq.context())
end

function c:init_queue( conf )
    self.queue = self:assert(self.zmqctx:socket(zmq.f.ZMQ_STREAM))
    self:assert(self.queue:bind(conf.queue))
end

function c:init_listeners( conf )
    for i,addr in ipairs(conf.addrs) do
        local fu = "init_transport__" .. addr.transport

        if type(self[fu]) ~= "function" then
            self:panic("unknown transport: " .. addr.transport)
        end

        self[fu](self, addr)
    end
end

function c:init_transport__ip4_tcp( conf )
    local sock = self:assert(net.ip4.tcp.socket(1))

    self:assert(sock:set(net.f.SO_REUSEADDR, 1))
    self:assert(sock:bind(conf.interface, conf.port))
    self:assert(sock:listen(conf.backlog))

    self.listeners[sock:id()] = {
        sock = sock,
        clients = {},
    }
end

function c:init_transport__ip6_tcp( conf )
    local sock = self:assert(net.ip6.tcp.socket(1))

    self:assert(sock:set(net.f.SO_REUSEADDR, 1))
    self:assert(sock:bind(conf.interface, conf.port))
    self:assert(sock:listen(conf.backlog))

    self.listeners[sock:id()] = {
        sock = sock,
        clients = {},
    }
end

function c:init_transport__unix( conf )
    local sock = self:assert(net.unix.socket(1))

    os.remove(conf.path)
    self:assert(sock:bind(conf.path, conf.mode))
    self:assert(sock:listen(conf.backlog))

    self.listeners[sock:id()] = {
        sock = sock,
        clients = {},
    }
end

function c:init_epoll()
end

function c:process()
    while true do
        zmq.sleep(1)
    end
end

--

return c
