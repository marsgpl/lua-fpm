--

local class = require "class"
local net = require "net"

local FcgiSocket = require "FcgiSocket"
local FcgiSocketClient = require "FcgiSocketClient"

--

local c = class:FcgiSocketAcceptor {
}:extends{ FcgiSocket }

--

function c:e_onread()
    while self.sock do
        local sock, fd = self.sock:accept(1)

        if not sock then
            break
        end

        assert(self.worker.epoll:watch(fd, net.f.EPOLLET | net.f.EPOLLRDHUP | net.f.EPOLLIN | net.f.EPOLLOUT))

        local obj = FcgiSocketClient:new {
            fd = fd,
            sock = sock,
            worker = self.worker,
            acceptor = self,
        }

        self.worker.sockets[fd] = obj

        obj:e_onread()
    end
end

--

return c
