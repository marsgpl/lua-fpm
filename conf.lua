--

return {
    lockfile = "fcgi.lock",
    zmq = {
        max_sockets = 65536,
        ipv6_enabled = false,
    },
    listener = {
        file = "src/threads/acceptor.lua",
        addr = "tcp://127.0.0.1:12345",
        --addr = "tcp://::1:12345",
        --addr = "ipc:///home/pd/src/lua-fcgi/fcgi.sock",
    },
    workers = {
        file = "src/threads/worker.lua",
        amount = 4,
    },
    queue = {
        addr = "inproc://queue",
    },
}
