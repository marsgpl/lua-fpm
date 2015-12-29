--

local trace = require "trace"
local class = require "class"
local net = require "net"
local fcgi = require "fcgi"

local FcgiSocket = require "FcgiSocket"

--

local c = class:FcgiSocketClient {
    acceptor = false,
    close_after_write = false,
    can_write = true,
    buff_write = "",
    buff_read = "",
    requests = {},
}:extends{ FcgiSocket }

--

function c:e_onread()
    while self.sock do
        local msg, len, errno = self.sock:recv()

        if msg then -- oke
            if #msg == 0 then -- bitch dropped us
                self:e_onhup()
                break
            else
                self.buff_read = self.buff_read .. msg
                self:process_read_buffer()
            end
        elseif errno == net.e.EWOULDBLOCK then -- no data atm
            break
        else -- epic error on the sock
            self:e_onhup()
            break
        end
    end
end

function c:e_onwrite()
    self.can_write = true
    self:process_write_buffer()
end

function c:e_onhup()
    if self.sock then
        self.sock:close()
        self.sock = false
        self.buff_write = ""
        self.worker.sockets[self.fd] = nil
    end
end

function c:e_onerror( es, en )
    self:e_onhup()
end

function c:send( msg )
    self.buff_write = self.buff_write .. msg
    self:process_write_buffer()
end

function c:process_write_buffer()
    while self.sock and self.can_write and #self.buff_write > 0 do
        local len, errstr, errno = self.sock:send(self.buff_write)

        if len then -- oke
            if #self.buff_write > len then  -- buff is full
                self.can_write = false
            end

            self.buff_write = self.buff_write:sub(len+1)
        elseif errno == net.e.EWOULDBLOCK then -- buff is full
            self.can_write = false
            break
        else -- epic error on the sock
            self:e_onhup()
            break
        end
    end
end

function c:process_read_buffer()
    local packets, unused_len = fcgi.unpack(self.buff_read)

    if unused_len == 0 then
        self.buff_read = ""
    elseif packets then
        self.buff_read = self.buff_read:sub(#self.buff_read - unused_len + 1)
    end

    if packets then
        for _,p in ipairs(packets) do
            if p.id then
                if not self.requests[p.id] then
                    self.requests[p.id] = {
                        client = self,
                        id = p.id,
                        params = {},
                        stdin = "",
                        params_ready = false,
                        stdin_ready = false,
                    }
                end

                local request = self.requests[p.id]

                if p.type == fcgi.f.FCGI_BEGIN_REQUEST then
                    request.role = p.role
                    request.keepalive = p.keepalive
                elseif p.type == fcgi.f.FCGI_STDIN then
                    if p.body then
                        request.stdin = request.stdin .. p.body
                    else
                        request.stdin_ready = true
                    end
                elseif p.type == fcgi.f.FCGI_PARAMS then
                    if p.params then
                        if request.params then
                            for k,v in pairs(p.params) do
                                request.params[k] = v
                            end
                        else
                            request.params = p.params
                        end
                    else
                        request.params_ready = true
                    end
                end

                if request.params_ready and request.stdin_ready then
                    local tid, t = self.worker:get_thread()
                    assert(coroutine.resume(t, tid, t, request))
                end
            end
        end
    end
end

function c:request_done( request, response )
    if not request.keepalive then
        self.close_after_write = true
    end

    self.requests[request.id] = nil

    -- response.status, response.stdout, response.stderr
    self:send("\1\6\0\1\0005\3\0Content-type: text/html; charset=UTF-8\13\10\13\10hi from Lua\0\0\0\1\3\0\1\0\8\0\0\0\0\0\0\0\0\0\0")
end

--

return c
