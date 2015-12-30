--

local class = require "class"

--

local c = class:FcgiThreadPool {
    processor = false,
    worker = false,
    min = 0,
    threads = {},
    thread_next_id = 1,
}

--

function c:prepare()
    for i=1,self.min do
        self:push(self:create())
    end
end

function c:pop()
    local tid, t = next(self.threads)

    if not tid then
        tid, t = self:create()
    end

    -- remove from "available for remove"
    self.threads[tid] = nil

    return tid, t
end

function c:push( tid, t )
    self.threads[tid] = t
end

function c:create()
    local tid = self.thread_next_id
    local t = coroutine.create(self.processor)

    assert(coroutine.resume(t))

    self.thread_next_id = self.thread_next_id + 1

    return tid, t
end

--

return c
