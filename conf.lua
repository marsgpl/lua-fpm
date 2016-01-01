--

-- { transport="ip4_tcp", interface="127.0.0.1", port=12345, backlog=64 },
-- { transport="ip6_tcp", interface="::1", port=12345, backlog=64 },
-- { transport="unix", path="/tmp/lua-fpm.sock", mode=666, backlog=64 },

return {
    lockfile = "/tmp/lua-fpm.lock",
    workers = {
        {
            file = "worker.lua",
            threads = 128,
            listeners = {
                { transport="unix", path="/tmp/lua-fpm-1.sock", mode=666, backlog=512 },
            },
        },
        {
            file = "worker.lua",
            threads = 128,
            listeners = {
                { transport="unix", path="/tmp/lua-fpm-2.sock", mode=666, backlog=512 },
            },
        },
        {
            file = "worker.lua",
            threads = 128,
            listeners = {
                { transport="unix", path="/tmp/lua-fpm-3.sock", mode=666, backlog=512 },
            },
        },
        {
            file = "worker.lua",
            threads = 128,
            listeners = {
                { transport="unix", path="/tmp/lua-fpm-4.sock", mode=666, backlog=512 },
            },
        },
    },
    debug = {
        auto_reload_files = false,
    },
}
