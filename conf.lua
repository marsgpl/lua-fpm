--

-- { transport="ip4_tcp", interface="127.0.0.1", port=12345, backlog=128 },
-- { transport="ip6_tcp", interface="::1", port=12345, backlog=128 },

return {
    lockfile = "/tmp/lua-fcgi.lock",
    workers = {
        {
            file = "worker.lua",
            threads = 500,
            listeners = {
                { transport="unix", path="/tmp/lua-fcgi-1.sock", mode=666, backlog=128 },
            },
        },
        {
            file = "worker.lua",
            threads = 500,
            listeners = {
                { transport="unix", path="/tmp/lua-fcgi-2.sock", mode=666, backlog=128 },
            },
        },
        {
            file = "worker.lua",
            threads = 500,
            listeners = {
                { transport="unix", path="/tmp/lua-fcgi-3.sock", mode=666, backlog=128 },
            },
        },
        {
            file = "worker.lua",
            threads = 500,
            listeners = {
                { transport="unix", path="/tmp/lua-fcgi-4.sock", mode=666, backlog=128 },
            },
        },
    },
}
