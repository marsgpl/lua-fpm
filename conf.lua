--

return {
    lockfile = "fcgi.lock",
    listener = {
        type = "unix",
        path = "fcgi.sock",
    },
    processes = 4,
}
