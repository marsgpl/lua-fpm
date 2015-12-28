--

return {
    lockfile = "/tmp/lua-fcgi.lock",
    workers = {
        {
            file = "src/threads/worker.lua",
            listeners = {
                { transport="ip4_tcp", interface="127.0.0.1", port=12345, backlog=128 },
            },
        },
        {
            file = "src/threads/worker.lua",
            listeners = {
                { transport="ip6_tcp", interface="::1", port=12345, backlog=128 },
            },
        },
        {
            file = "src/threads/worker.lua",
            listeners = {
                { transport="unix", path="/tmp/lua-fcgi.sock", mode=666, backlog=128 },
            },
        },
    },
}
