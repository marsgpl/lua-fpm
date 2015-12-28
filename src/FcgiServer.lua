--

local class = require "class"
local std = require "std"
local thread = require "thread"

local Panicable = require "Panicable"
local Configurator = require "Configurator"

--

local c = class:FcgiServer {
    conf = false,
    lock = false,
    workers = {},
}:extends{ Panicable }

--

function c:init()
    Panicable.init(self)

    self:init_conf()
    self:init_lock(self.conf.data)
    self:init_workers(self.conf.data)
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

function c:init_workers( conf )
    for i,data in ipairs(conf.workers) do
        local t = self:assert(thread.start(data.file, {
            listeners = data.listeners,
        }))

        table.insert(self.workers, t)
    end
end

--

return c
