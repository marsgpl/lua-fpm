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
    epoll = false,
    zmqctx = false,
    queue = false,
    listeners = {},
    clients = {},
    workers = {},
}:extends{ Panicable }

--

function c:init()
    Panicable.init(self)

    self:init_epoll()
    self:init_zmq()
    self:init_queue(self.args)
    self:init_listeners(self.args)

    self:process()
end

function c:init_epoll()
    self.epoll = self:assert(net.epoll())
end

function c:init_zmq()
    self.zmqctx = self:assert(zmq.context())
end

function c:init_queue( conf )
    local sock = self:assert(self.zmqctx:socket(zmq.f.ZMQ_REP))
    local fd = sock:get(zmq.f.ZMQ_FD)

    self:assert(self.epoll:watch(fd, net.f.EPOLLET | net.f.EPOLLRDHUP | net.f.EPOLLIN | net.f.EPOLLOUT))

    self:assert(sock:bind(conf.queue))

    self.queue = {
        fd = fd,
        sock = sock,
        can_read = true,
        can_write = true,
    }
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

    self:assert(self.epoll:watch(sock:fd(), net.f.EPOLLET | net.f.EPOLLRDHUP | net.f.EPOLLIN))

    self:assert(sock:set(net.f.SO_REUSEADDR, 1))
    self:assert(sock:bind(conf.interface, conf.port))
    self:assert(sock:listen(conf.backlog))

    self.listeners[sock:fd()] = {
        sock = sock,
        can_read = true,
        can_write = true,
    }
end

function c:init_transport__ip6_tcp( conf )
    local sock = self:assert(net.ip6.tcp.socket(1))

    self:assert(self.epoll:watch(sock:fd(), net.f.EPOLLET | net.f.EPOLLRDHUP | net.f.EPOLLIN))

    self:assert(sock:set(net.f.SO_REUSEADDR, 1))
    self:assert(sock:bind(conf.interface, conf.port))
    self:assert(sock:listen(conf.backlog))

    self.listeners[sock:fd()] = {
        sock = sock,
        can_read = true,
        can_write = true,
    }
end

function c:init_transport__unix( conf )
    local sock = self:assert(net.unix.socket(1))

    self:assert(self.epoll:watch(sock:fd(), net.f.EPOLLET | net.f.EPOLLRDHUP | net.f.EPOLLIN))

    os.remove(conf.path)
    self:assert(sock:bind(conf.path, conf.mode))
    self:assert(sock:listen(conf.backlog))

    self.listeners[sock:fd()] = {
        sock = sock,
        can_read = true,
        can_write = true,
    }
end

function c:process()
    local this = self

    local onread = function( fd )
        if fd == this.queue.fd then
            this:queue_onread()
        elseif this.listeners[fd] then
            this:listener_onread(fd)
        elseif this.clients[fd] then
            this:client_onread(fd)
        else
            error("onread: unknown fd: " .. (tonumber(fd) or -1))
        end
    end

    local onwrite = function( fd )
        if fd == this.queue.fd then
            this:queue_onwrite()
        elseif this.listeners[fd] then
            this:listener_onwrite(fd)
        elseif this.clients[fd] then
            this:client_onwrite(fd)
        else
            error("onwrite: unknown fd: " .. (tonumber(fd) or -1))
        end
    end

    local onhup = function( fd )
        if fd == this.queue.fd then
            this:queue_onhup()
        elseif this.listeners[fd] then
            this:listener_onhup(fd)
        elseif this.clients[fd] then
            this:client_onhup(fd)
        else
            error("onwrite: unknown fd: " .. (tonumber(fd) or -1))
        end
    end

    local onerror = function( fd, es, en ) -- if lua error then fd = nil
        print("Error occured:", fd, es, en)
    end

    local ontimeout = function()
    end

    while true do
        self:assert(self.epoll:start(-1, onread, onwrite, ontimeout, onerror, onhup))
    end
end

--

function c:queue_onread()
    while true do
        local msg = self.queue.sock:recv(1)

        if not msg then
            break
        end

        trace(msg)
    end
end

function c:queue_onwrite()
end

function c:queue_onhup()
end

--

function c:listener_onread( fd )
end

function c:listener_onwrite( fd )
end

function c:listener_onhup( fd )
end

--

function c:client_onread( fd )
end

function c:client_onwrite( fd )
end

function c:client_onhup( fd )
end

--

return c
