--

local class = require "class"
local net = require "net"
local redis = require "redis"

--

local c = class:FcgiRedisClient {
    transport = "ip4_tcp",
    addr = "127.0.0.1",
    port = 6379,
    id = false,
    data = {
        fd = false,
        sock = false,
        connected = false,
    },
    server = false,
    client = false,
}

--

function c:init()
    self.id = "redis:" .. tostring(self.transport) .. ":" .. tostring(self.addr) .. ":" .. tostring(self.port)

    if self.server.services[self.id] then
        self.data = self.server.services[self.id].data
    else
        self.server.services[self.id] = self
    end
end

function c:connect()
    if self.data.connected then
        return self
    end

    if self.transport == "ip4_tcp" then
        self.data.sock, self.data.fd = assert(net.ip4.tcp.socket(1))
    else
        error("unknown transport: " .. tostring(self.transport))
    end

    self.server.epolladd(self.data.fd, self)

    self.data.sock:connect(self.addr, self.port)
print "yield here"
    coroutine.yield()

    return self
end

--

function c:e_onread()
end

function c:e_onwrite()
    if not self.data.connected then
        self.data.connected = true
print "resume here (connected)"
        coroutine.resume(self.client.t)
    end
end

function c:e_onhup()
end

function c:e_onerror( es, en )
end

--

return c
