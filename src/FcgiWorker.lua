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
    exchange = {},

    static_epolladd = false,
    static_epollrem = false,
}:extends{ FcgiPanicable }

--

function c:init()
    FcgiPanicable.init(self)

    self:get_static_epolladd()
    self:get_static_epollrem()

    self:init_epoll()
    self:init_threads()
    self:init_logger()
    self:init_listeners()
    self:init_exchange()

    self:process()
end

function c:init_exchange()
    self.exchange = {
        epolladd = self.static_epolladd,
        epollrem = self.static_epollrem,
        logger = self.logger,
        services = {},
    }
end

function c:init_logger()
    if self.args.log.enabled then
        self.logger = FcgiLoggerClient:new {
            title = class.name(self) .. " #" .. self.id,
            addr = self.args.log.addr,
        }

        self:assert(self.static_epolladd(self.logger:fd(), self.logger))
    end
end

function c:create_lua_env()
    local env = {}

    setmetatable(env, { __index=_G })
    env._G = env

    return env
end

function c:prepare_lua_file( file, args )
    if not file then
        return false, "prepare_lua_file: file is not a string (fastcgi_param LUA_PATH)", 500
    end

    if not args then
        return false, "prepare_lua_file: args are not a string (fastcgi_param LUA_ARGS)", 500
    end

    local f = self.files[file]
    local r, es, fu

    if self.args.debug.auto_reload_files or not f then
        r, es = loadfile(file, "bt", self:create_lua_env())

        if r then
            r, fu = pcall(r)

            if r and type(fu)=="function" then
                f = {
                    chunk = fu,
                }
            else
                f = {
                    error = "prepare_lua_file: pcall: " .. (fu or "must return a function"),
                }
            end
        else
            f = {
                error = "prepare_lua_file: loadfile: " .. es,
            }
        end

        self.files[file] = f
    end

    if f.chunk then
        return f.chunk
    else
        return false, f.error, 500
    end
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

    if self.logger then
        self.logger:log("listening ", conf.interface, ":", math.tointeger(conf.port))
    end

    self:assert(sock:set(net.f.SO_REUSEADDR, 1))
    self:assert(sock:bind(conf.interface, conf.port))
    self:assert(sock:listen(conf.backlog))

    local obj = FcgiSocketAcceptor:new {
        fd = fd,
        sock = sock,
        worker = self,
    }

    self:assert(self.static_epolladd(fd, obj))

    obj:e_onread()
end

function c:init_transport__ip6_tcp( conf )
    local sock, fd = self:assert(net.ip6.tcp.socket(1))

    if self.logger then
        self.logger:log("listening ", conf.interface, ":", math.tointeger(conf.port))
    end

    self:assert(sock:set(net.f.SO_REUSEADDR, 1))
    self:assert(sock:bind(conf.interface, conf.port))
    self:assert(sock:listen(conf.backlog))

    local obj = FcgiSocketAcceptor:new {
        fd = fd,
        sock = sock,
        worker = self,
    }

    self:assert(self.static_epolladd(fd, obj))

    obj:e_onread()
end

function c:init_transport__unix( conf )
    local sock, fd = self:assert(net.unix.socket(1))

    if self.logger then
        self.logger:log("listening ", conf.path, ", chmod ", math.tointeger(conf.mode))
    end

    os.remove(conf.path)
    self:assert(sock:bind(conf.path, conf.mode))
    self:assert(sock:listen(conf.backlog))

    local obj = FcgiSocketAcceptor:new {
        fd = fd,
        sock = sock,
        worker = self,
    }

    self:assert(self.static_epolladd(fd, obj))

    obj:e_onread()
end

function c:process()
    local this = self
    local timeout = 500

    local onread = function( fd )
        local obj = this.sockets[fd]

        if obj and obj.e_onread then
            obj:e_onread()
        end
    end

    local onwrite = function( fd )
        local obj = this.sockets[fd]

        if obj and obj.e_onwrite then
            obj:e_onwrite()
        end
    end

    local onhup = function( fd )
        local obj = this.sockets[fd]

        if obj and obj.e_onhup then
            obj:e_onhup()
        end
    end

    local onerror = function( fd, es, en )
        if fd then -- socket error
            local obj = this.sockets[fd]

            if obj and obj.e_onerror then
                obj:e_onerror(es, en)
            end

            this.static_epollrem(fd)
        else -- lua error
            if this.logger then
                this.logger:error("lua: ", tostring(es))
            end
        end
    end

    local ontimeout = function()
        this:rewatch_listeners()
    end

    self.epoll:start(timeout, onread, onwrite, ontimeout, onerror, onhup)
end

function c:get_static_epolladd()
    local this = self

    if not this.static_epolladd then
        this.static_epolladd = function( fd, obj )
            local fread = obj.e_onread and net.f.EPOLLIN or 0
            local fwrite = obj.e_onwrite and net.f.EPOLLOUT or 0
            local fhup = obj.e_onhup and net.f.EPOLLRDHUP or 0

            if fread+fwrite+fhup == 0 then
                return nil, "specify at least one listening option"
            end

            local r, es = this.epoll:watch(fd, net.f.EPOLLET | fread | fwrite | fhup)

            if r then
                this.sockets[fd] = obj
                return r
            else
                return r, es
            end
        end
    end

    return this.static_epolladd
end

function c:get_static_epollrem()
    local this = self

    if not this.static_epollrem then
        this.static_epollrem = function( fd )
            if this.sockets[fd] then
                this.epoll:unwatch(fd)
                this.sockets[fd] = nil
            end

            return true
        end
    end

    return this.static_epollrem
end

--

return c
