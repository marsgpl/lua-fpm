--

local trace = require "trace"

local class = require "class"
local zmq = require "zmq"
local std = require "std"
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

    self:init_conf()
    self:init_lock(self.conf.data)
    self:init_zmq(self.conf.data)
    self:init_threads(self.conf.data)

    self:monitor(self.conf.data)
end

function c:init_conf()
    self.conf = Configurator:new{ data=self.conf }
    self:assert(self.conf:check())
end

function c:init_lock( conf )
    if conf.lockfile then
        self.lock = self:assert(std.lock(conf.lockfile))
    end
end

function c:init_zmq()
    self.zmqctx = self:assert(zmq.context())
end

function c:init_threads( conf )
    self:init_acceptor(conf)
    self:init_workers(conf)
end

function c:init_acceptor( conf )
    local t = self:assert(thread.start(conf.acceptor.file, {
        queue = conf.workers.queue,
        addrs = conf.acceptor.addrs,
    }, { zmq.__get_ctx_mf() }))

    table.insert(self.threads, t)
end

function c:init_workers( conf )
    for i=1,conf.workers.amount do
        local t = self:assert(thread.start(conf.workers.file, {
            queue = conf.workers.queue,
        }, { zmq.__get_ctx_mf() }))

        table.insert(self.threads, t)
    end
end

function c:monitor( conf )
    if not conf.monitor.enabled then
        return
    end

    while true do
        zmq.sleep(1)
    end
end

--

return c
