--

local trace = require "trace"
local class = require "class"
local std = require "std"

local Panicable = require "Panicable"
local Configurator = require "Configurator"

--

local c = class:FcgiServer {
    conf = false,
    lock = false,
}:extends{ Panicable }

--

function c:init()
    Panicable.init(self)

    self.conf = Configurator:new{ data=self.conf }

    self:assert(self.conf:check())

    if self.conf.data.lockfile then
        self.lock = self:assert(std.lock(self.conf.data.lockfile))
    end

    print("ok")
    std.sleep(60)
end

--

return c
