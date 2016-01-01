--

local class = require "class"
local std = require "std"
local zmq = require "zmq"
local thread = require "thread"

local FcgiPanicable = require "FcgiPanicable"
local FcgiConfigurator = require "FcgiConfigurator"

--

local c = class:FcgiServer {
    conf = false,
    lock = false,
    zmq = false,
    logger = false,
    workers = {},
}:extends{ FcgiPanicable }

--

function c:init()
    FcgiPanicable.init(self)

    self:init_conf()
    self:init_lock(self.conf.data)
    self:init_zmq()
    self:init_limits(self.conf.data)
    self:init_workers(self.conf.data)
    self:init_logger(self.conf.data)
end

function c:init_conf()
    self.conf = FcgiConfigurator:new{ data=self.conf }
    self:assert(self.conf:check())
end

function c:init_lock( conf )
    if conf.lockfile then
        self.lock = self:assert(std.lock(conf.lockfile))
    end
end

function c:init_zmq()
    self.zmq = self:assert(zmq.context())
end

function c:init_limits( conf )
    self:assert(std.setrlimit(std.f.RLIMIT_NOFILE, conf.max_open_files, conf.max_open_files))
end

function c:init_logger( conf )
    if conf.log.enabled then
        self.logger = self:assert(thread.start(conf.log.code, {
            file = conf.log.file,
            addr = conf.log.addr,
            stdout = conf.debug.log_stdout,
        }, { zmq.__get_ctx_mf() }))
    end
end

function c:init_workers( conf )
    for i,data in ipairs(conf.workers) do
        local t = self:assert(thread.start(data.code, {
            listeners = data.listeners,
            threads = data.threads,
            debug = conf.debug,
            log = conf.log,
        }, { zmq.__get_ctx_mf() }))

        table.insert(self.workers, t)
    end
end

--

return c
