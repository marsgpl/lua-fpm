--

local class = require "class"
local net = require "net"

local FcgiPanicable = require "FcgiPanicable"
local FcgiThreadPool = require "FcgiThreadPool"
local FcgiSocketAcceptor = require "FcgiSocketAcceptor"
local FcgiSocketClient = require "FcgiSocketClient"
local FcgiLoggerClient = require "FcgiLoggerClient"

--

local c = class:FcgiWorker {
    id = false,
    args = false,
    epoll = false,
    threads = false,
    logger = false,
    sockets = {},
    files = {},
}:extends{ FcgiPanicable }

--

function c:init()
    FcgiPanicable.init(self)

    self:init_epoll()
    self:init_threads()
    self:init_listeners()
    self:init_logger()

    self:process()
end

function c:init_logger()
    if self.args.log.enabled then
        self.logger = FcgiLoggerClient:new {
            title = class.name(self) .. " #" .. self.id,
            addr = self.args.log.addr,
        }

        self.sockets[self.logger:fd()] = self.logger

        self:assert(self.epoll:watch(self.logger:fd(), net.f.EPOLLET | net.f.EPOLLRDHUP | net.f.EPOLLOUT))
    end
end

function c:cleanup_callback( cb )
    assert(self.epoll:unwatch(cb.fd), "cleanup_callback unwatch failed")
end

function c:prepare_lua_file( file )
print "TODO prepare_file"
os.exit(1)
    if not root or not name then
        return {
            error = "LUA_ROOT or LUA_FILE are missing",
        }
    end


    if self.args.debug.auto_reload_files or not self.files[filepath] then
        local r, es, en = loadfile(filepath, "bt", {
            require = require,
        })

        if r then
            self.files[filepath] = {
                chunk = r,
            }
        else
            self.files[filepath] = {
                error = es,
            }
        end
    end

    return self.files[filepath]
end

function c:init_epoll()
    self.epoll = self:assert(net.epoll())
end

function c:init_threads()
    self.threads = FcgiThreadPool:new {
        processor = FcgiSocketClient.process_request,
        worker = self,
        min = self.args.threads,
    }

    self:assert(pcall(self.threads.prepare, self.threads))
end

function c:rewatch_listeners()
    for fd, s in pairs(self.sockets) do
        if class.name(s) == "FcgiSocketAcceptor" then
            assert(self.epoll:unwatch(fd), "rewatch_listeners unwatch failed")
            assert(self.epoll:watch(fd, net.f.EPOLLET | net.f.EPOLLIN), "rewatch_listeners watch failed")
            s:e_onread()
        end
    end
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

    local timeout = 500

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
            this.logger:error("lua: " .. tostring(es))
        end
    end

    local ontimeout = function()
        this:rewatch_listeners()
    end

    self.epoll:start(timeout, onread, onwrite, ontimeout, onerror, onhup)
end

--

return c
