--

local class = require "class"
local trace = require "trace"

local Configurable = require "Configurable"

--

local c = class:FcgiServer {
    conf = false,
}:extends{ Configurable }

--

function c:init()
    self:init_conf()

    trace(self.conf)
end

function c:init_conf()
    local t = type(self.conf)

    if t == "string" then
        -- conf is a file path to load the conf table from
        self.conf = self:try_panic(self:load_conf(self.conf))
    elseif t == "table" then
        -- conf is already provided as table
        -- do nothing
    else
        self:panic("bad initial params", self:usage())
    end

    self:try_panic(self:check_conf())
end

function c:usage()
    return "how to use:"
        .. "\n\tlocal FcgiServer = require \"src/FcgiServer\""
        .. "\n\tFcgiServer:new{ conf=\"conf.lua\" }"
end

function c:panic( ... )
    if trace.use_colors then
        io.stderr:write(trace.color.string, "PANIC: ", trace.color.reset)
    else
        io.stderr:write("PANIC: ")
    end

    for i=1,select("#", ...) do
        io.stderr:write((select(i, ...)))
        io.stderr:write("\n")
    end

    io.stderr:flush()

    os.exit(1)
end

function c:try_panic( r, ... )
    if r then
        return r, ...
    else
        self:panic(...)
    end
end

--

return c
