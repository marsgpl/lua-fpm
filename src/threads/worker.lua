local std = require "std"
local thread = require "thread"
local trace = require "trace"

trace(thread.args())

for i=1,10 do
    print("worker here", thread.id())
    std.sleep(1)
end
