--

local trace = require "trace"
local class = require "class"
local net = require "net"

local Panicable = require "Panicable"
local FcgiSocketAcceptor = require "FcgiSocketAcceptor"

--

local c = class:FcgiWorker {
    id = false,
    args = false,
    epoll = false,
    sockets = {},
    threads = {},
    thread_next_id = 1,
}:extends{ Panicable }

--

function c:init()
    Panicable.init(self)

    self:init_epoll()
    self:init_listeners()
    self:init_threads()

    self:process()
end

function c:init_epoll()
    self.epoll = self:assert(net.epoll())
end

function c:init_listeners()
    for i,addr in ipairs(self.args.listeners) do
        local fu = "init_transport__" .. addr.transport

        if type(self[fu]) ~= "function" then
            self:panic("unknown transport: " .. addr.transport)
        end

        self[fu](self, addr)
    end
end

function c:init_transport__ip4_tcp( conf )
    local sock, fd = self:assert(net.ip4.tcp.socket(1))

    self:assert(sock:set(net.f.SO_REUSEADDR, 1))
    self:assert(sock:bind(conf.interface, conf.port))
    self:assert(sock:listen(conf.backlog))

    self:assert(self.epoll:watch(fd, net.f.EPOLLET | net.f.EPOLLIN))

    local obj = FcgiSocketAcceptor:new {
        fd = fd,
        sock = sock,
        worker = self,
    }

    self.sockets[fd] = obj

    obj:e_onread()
end

function c:init_transport__ip6_tcp( conf )
    local sock, fd = self:assert(net.ip6.tcp.socket(1))

    self:assert(sock:set(net.f.SO_REUSEADDR, 1))
    self:assert(sock:bind(conf.interface, conf.port))
    self:assert(sock:listen(conf.backlog))

    self:assert(self.epoll:watch(fd, net.f.EPOLLET | net.f.EPOLLIN))

    local obj = FcgiSocketAcceptor:new {
        fd = fd,
        sock = sock,
        worker = self,
    }

    self.sockets[fd] = obj

    obj:e_onread()
end

function c:init_transport__unix( conf )
    local sock, fd = self:assert(net.unix.socket(1))

    os.remove(conf.path)
    self:assert(sock:bind(conf.path, conf.mode))
    self:assert(sock:listen(conf.backlog))

    self:assert(self.epoll:watch(fd, net.f.EPOLLET | net.f.EPOLLIN))

    local obj = FcgiSocketAcceptor:new {
        fd = fd,
        sock = sock,
        worker = self,
    }

    self.sockets[fd] = obj

    obj:e_onread()
end

function c:process()
    local this = self

    local timeout = -1

    local onread = function( fd )
        local obj = this.sockets[fd]
        if obj then
            obj:e_onread()
        end
    end

    local onwrite = function( fd )
        local obj = this.sockets[fd]
        if obj then
            obj:e_onwrite()
        end
    end

    local onhup = function( fd )
        local obj = this.sockets[fd]
        if obj then
            obj:e_onhup()
        end
    end

    local onerror = function( fd, es, en )
        if fd then -- socket error
            local obj = this.sockets[fd]
            if obj then
                obj:e_onerror(es, en)
            end
        else -- lua error
            print("onerror: lua:", es, en)
        end
    end

    local ontimeout = function()
        error("this func shall never be called with infinite timeout")
    end

    self.epoll:start(timeout, onread, onwrite, ontimeout, onerror, onhup)
end

function c:init_threads()
    for i=1,self.args.threads do
        self:add_thread()
    end
end

function c:add_thread()
    local tid = self.thread_next_id

    if tid > self.args.threads then
        print(tid)
    end

    self.thread_next_id = self.thread_next_id + 1

    local t = coroutine.create(function()
        local tid, t, request, response

        while true do
            tid, t, request = coroutine.yield()

            response = {
                status = 404,
                stdout = "",
                stderr = "TODO: load fucking files",
            }

            request.client:request_done(request, response)
            request.client.worker:put_thread(tid, t)
        end
    end)

    self:assert(coroutine.resume(t))

    self.threads[tid] = t

    return tid, t
end

function c:get_thread()
    local tid, t = next(self.threads)

    if not tid then
        tid, t = self:add_thread()
    end

    self.threads[tid] = nil

    return tid, t
end

function c:put_thread( tid, t )
    self.threads[tid] = t
end

--

return c
