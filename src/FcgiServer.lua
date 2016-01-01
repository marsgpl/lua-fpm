--

local class = require "class"
local std = require "std"
local thread = require "thread"

local FcgiPanicable = require "FcgiPanicable"
local FcgiConfigurator = require "FcgiConfigurator"

--

local c = class:FcgiServer {
    conf = false,
    lock = false,
    workers = {},
}:extends{ FcgiPanicable }

--

function c:init()
    FcgiPanicable.init(self)

    self:init_conf()
    self:init_lock(self.conf.data)
    self:init_workers(self.conf.data)
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

function c:init_workers( conf )
    for i,data in ipairs(conf.workers) do
        local t = self:assert(thread.start(data.file, {
            listeners = data.listeners,
            threads = data.threads,
            debug = conf.debug,
        }))

        table.insert(self.workers, t)
    end
end

--

return c
