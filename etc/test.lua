--

local trace = require "trace"
local net = require "net"

trace.use_colors = false

-- request.params.LUA_PATH
-- request.params.LUA_ARGS
-- request.stdin

return function( request )
    print "before yield"

    local s = net.ip4.tcp.socket(1)
    s:connect(net.ip4.tcp.nslookup("fuck.world")[1], 80)
    request.client.worker.sockets[s:fd()] = {
        sock = s,
        e_onwrite = function()
            request.client.worker.sockets[s:fd()] = nil
            s:close()
            coroutine.resume(request.t)
        end
    }
    request.client.worker.epoll:watch(s:fd(), net.f.EPOLLET | net.f.EPOLLRDHUP | net.f.EPOLLOUT)
    coroutine.yield()

    print "after yield"

    return {}, trace.str(request)
end
