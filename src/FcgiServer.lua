--

local trace = require "trace"

local class = require "class"
local std = require "std"
local zmq = require "zmq"
local thread = require "thread"

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
    local queues = {}

    for i,lconf in ipairs(conf.listeners) do
        local queue = { addr="inproc://queue#"..i }

        table.insert(queues, queue)

        local t = self:assert(thread.start(lconf.code, {
            queue = queue,
            addr = lconf.addr,
        }, { zmq.__get_ctx_mf() }))

        table.insert(self.threads, t)
    end

    trace(queues)
end

-- TODO
function c:monitor()
    local n = 0
    while true do
        std.sleep(.678)
        n = n + 1
        print("monitoring stage " .. n)
    end
end

--

return c
