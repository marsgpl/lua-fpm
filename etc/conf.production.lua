--

return {
    lockfile = "/tmp/lua-fpm.lock",
    max_open_files = 4096,
    log = {
        enabled = true,
        code = "logger.lua",
        file = "/tmp/lua-fpm.log",
        addr = "inproc://logger",
    },
    debug = {
        auto_reload_files = false,
        log_stdout = false,
        show_errors = false,
    },
    workers = {
        {
            code = "worker.lua",
            threads = 128,
            listeners = {
                { transport="unix", path="/tmp/lua-fpm-1.sock", mode=666, backlog=512 },
            },
        },
        {
            code = "worker.lua",
            threads = 128,
            listeners = {
                { transport="unix", path="/tmp/lua-fpm-2.sock", mode=666, backlog=512 },
            },
        },
        {
            code = "worker.lua",
            threads = 128,
            listeners = {
                { transport="unix", path="/tmp/lua-fpm-3.sock", mode=666, backlog=512 },
            },
        },
        {
            code = "worker.lua",
            threads = 128,
            listeners = {
                { transport="unix", path="/tmp/lua-fpm-4.sock", mode=666, backlog=512 },
            },
        },
    },
}
