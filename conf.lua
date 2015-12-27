--

return {
    lockfile = "/tmp/lua-fcgi.lock",
    acceptor = {
        file = "src/threads/acceptor.lua",
        addrs = {
            { transport="ip4_tcp", interface="127.0.0.1", port=12345, backlog=128 },
            { transport="ip6_tcp", interface="::1", port=12345, backlog=128 },
            { transport="unix", path="/tmp/lua-fcgi.sock", mode=666, backlog=128 },
        },
    },
    workers = {
        file = "src/threads/worker.lua",
        amount = 4,
        queue = "inproc://tasks",
    },
    monitor = {
        enabled = false,
    },
}
