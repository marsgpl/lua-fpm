--

local class = require "class"
local zmq = require "zmq"
local std = require "std"

local FcgiSocket = require "FcgiSocket"
local FcgiPanicable = require "FcgiPanicable"

--

local c = class:FcgiLoggerClient {
    title = false,
    addr = false,
    zmq = false,
    buff_write = {},
    can_write = true,
}:extends{ FcgiPanicable, FcgiSocket }

--

function c:init()
    self:init_zmq()
end

function c:init_zmq()
    self.zmq = {}

    self.zmq.ctx = self:assert(zmq.context())
    self.zmq.sock = self:assert(self.zmq.ctx:socket(zmq.f.ZMQ_PUSH))

    self:assert(self.zmq.sock:connect(self.addr))
end

function c:fd()
    return self.zmq.sock:get(zmq.f.ZMQ_FD)
end

function c:error( ... )
    table.insert(self.buff_write, { "error", std.concat("", ...) })
    self:process_write_buffer()
end

function c:warn( ... )
    table.insert(self.buff_write, { "warn", std.concat("", ...) })
    self:process_write_buffer()
end

function c:debug( ... )
    table.insert(self.buff_write, { "debug", std.concat("", ...) })
    self:process_write_buffer()
end

function c:log( ... )
    table.insert(self.buff_write, { "", std.concat("", ...) })
    self:process_write_buffer()
end

function c:e_onwrite()
    self.can_write = true
    self:process_write_buffer()
end

function c:process_write_buffer()
    local task, r

    while self.zmq.sock and self.can_write and #self.buff_write > 0 do
        task = next(self.buff_write)

        r = self.zmq.sock:send(self.title, 1, 1)
            and self.zmq.sock:send(task[1], 1, 1)
            and self.zmq.sock:send(task[2], 1)

        if not r then
            self.can_write = false
        else
            table.remove(self.buff_write, 1)
        end
    end
end

--

return c
