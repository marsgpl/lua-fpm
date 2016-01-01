--

local class = require "class"
local std = require "std"
local zmq = require "zmq"

local FcgiPanicable = require "FcgiPanicable"

--

local c = class:FcgiLogger {
    file = false,
    addr = false,
    stdout = false,
    fp = false, -- log file pointer
    zmq = false,

    time_format = "%Y-%m-%d %H:%M:%S",
    text_indent = "  ", -- time *indent* title *indent* level: msg
    text_level = {
        error = "Error: ",
        warn = "Warning: ",
        debug = "DEBUG: ",
    },
    color = {
        time = "\27[0;35m", -- purple
        title = "\27[0;36m", -- cyan
        error = "\27[0;31m", -- red
        warn = "\27[0;33m", -- yellow
        debug = "\27[0;34m", -- blue
        reset = "\27[0m",
    },
}:extends{ FcgiPanicable }

--

function c:init()
    self:init_file()
    self:init_zmq()
    self:listen()
end

function c:init_file()
    if type(self.file) == "string" then
        self.fp = self:assert(io.open(self.file, "a"))
    end
end

function c:init_zmq()
    self.zmq = {}

    self.zmq.ctx = self:assert(zmq.context())
    self.zmq.sock = self:assert(self.zmq.ctx:socket(zmq.f.ZMQ_PULL))

    self:assert(self.zmq.sock:bind(self.addr))
end

function c:listen()
    while zmq.poll { self.zmq.sock } do
        self:log(
            self.zmq.sock:recv(),
            self.zmq.sock:recv(),
            self.zmq.sock:recv()
        )
    end
end

function c:log( title, level, msg )
    msg = std.trim(msg)

    if self.stdout then
        if self.time_format then
            io.stdout:write(
                self.color.time,
                os.date(self.time_format),
                self.color.reset,
                self.text_indent
            )
        end
        if title then
            io.stdout:write(
                self.color.title,
                tostring(title),
                self.color.reset,
                self.text_indent
            )
        end
        if level then
            local text = self.text_level[level]
            if text then
                io.stdout:write(
                    self.color[level],
                    text,
                    self.color.reset
                )
            end
        end

        io.stdout:write(msg, "\n"):flush()
    end

    if self.fp then
        if self.time_format then
            self.fp:write(os.date(self.time_format), self.text_indent)
        end
        if title then
            self.fp:write(tostring(title), self.text_indent)
        end
        if level then
            local text = self.text_level[level]
            if text then
                self.fp:write(text)
            end
        end

        self.fp:write(msg, "\n"):flush()
    end
end

--

return c
