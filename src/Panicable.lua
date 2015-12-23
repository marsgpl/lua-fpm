--

local class = require "class"

--

local c = class:Panicable {
    use_colors = true,
    color = {
        panic = "\27[0;31m", -- red
        reset = "\27[0m",
    },
}

--

function c:assert( r, ... )
    if r then
        return r, ...
    else
        self:panic(...)
    end
end

function c:panic( ... )
    if self.use_colors then
        io.stderr:write(self.color.panic, "PANIC: ", self.color.reset)
    else
        io.stderr:write("PANIC: ")
    end

    for i=1,select("#", ...) do
        io.stderr:write(tostring(select(i, ...)))
        io.stderr:write("\n")
    end

    io.stderr:write(debug.traceback())
    io.stderr:write("\n")

    io.stderr:flush()

    os.exit(1)
end

--

return c
