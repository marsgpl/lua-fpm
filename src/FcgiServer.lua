--

local trace = require "trace"

local thread = require "thread"
local class = require "class"
local zmq = require "zmq"
local std = require "std"

local Panicable = require "Panicable"
local Configurator = require "Configurator"

--

local c = class:FcgiServer {
    conf = false,
    lock = false,
    zmqctx = false,
    threads = {},
}:extends{ Panicable }

--

function c:init()
    Panicable.init(self)

    self.conf = Configurator:new{ data=self.conf }
    self:assert(self.conf:check())

    if self.conf.data.lockfile then
        self.lock = self:assert(std.lock(self.conf.data.lockfile))
    end

    self:init_zmq(self.conf.data.zmq)

    self:init_threads(self.conf.data)

    self:monitor()
end

function c:init_zmq( conf )
    self.zmqctx = self:assert(zmq.context {
        [zmq.f.ZMQ_MAX_SOCKETS] = tonumber(conf.max_sockets),
        [zmq.f.ZMQ_IPV6] = conf.ipv6_enabled and 1 or 0,
    })
end

function c:init_threads( conf )
    local t = self:assert(thread.start(conf.listener.file, {
        addr = conf.listener.addr,
        queue = conf.queue.addr,
    }, { zmq.__get_ctx_mf() }))

    table.insert(self.threads, t)

    for i=1,conf.workers.amount do
        local t = self:assert(thread.start(conf.workers.file, {
            queue = conf.queue.addr,
        }, { zmq.__get_ctx_mf() }))

        table.insert(self.threads, t)
    end
end

function c:monitor()
    while true do
        std.sleep(1)
    end
end

--

return c
