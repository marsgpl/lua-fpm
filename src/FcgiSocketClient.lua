--

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
        self.worker.static_epollrem(self.fd)
        self.sock:close()
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

    if #self.buff_write == 0 and self.close_after_write then
        self:e_onhup()
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
            elseif p.type == fcgi.f.FCGI_STDIN then
                if p.body then
                    request.stdin = request.stdin .. p.body
                else
                    request.stdin_ready = true
                end
            end

            if request.params_ready and request.stdin_ready then
                local tid, t = self.worker.threads:pop()

                request.t = t
                request.tid = tid

                assert(coroutine.resume(t, request))
            end
        end -- for
    end -- if packets
end

function c.process_request()
    local self, request, response, r, es, en, chunk, headers, stdout

    while true do
        request = coroutine.yield()
        self = request.client

        chunk, es, en = self.worker:prepare_lua_file(request.params.LUA_PATH, request.params.LUA_ARGS)

        if not chunk then
            if self.worker.logger then
                self.worker.logger:error(es, "; en: ", en)
            end

            response = self:build_response_error(en, es)
        else
            if self.worker.logger then
                self.worker.logger:log("file: ", request.params.LUA_PATH,
                    (#request.params.LUA_ARGS > 0 and "; args: " .. request.params.LUA_ARGS or ""),
                    (#request.stdin > 0 and "; #post: ".. #request.stdin or "")
                )
            end

            trace.use_colors = false

            r, headers, stdout = pcall(chunk, {
                params = request.params,
                path = request.params.LUA_PATH,
                get = request.params.LUA_ARGS,
                post = request.stdin,
                server = self.worker.exchange,
                client = {
                    t = request.t,
                    tid = request.tid,
                },
            })

            trace.use_colors = true

            if r then
                if type(headers)=="table" and type(stdout)=="string" then
                    response = self:build_response_success(200, headers, stdout)
                else
                    if self.worker.logger then
                        self.worker.logger:error("runtime: ",
                            (not r and headers or "process_request: chunk pcall: must return (table, string)")
                        )
                    end

                    response = self:build_response_error(500, "process_request: chunk pcall: must return (table, string)")
                end
            else
                if self.worker.logger then
                    self.worker.logger:error("runtime: ", headers)
                end

                response = self:build_response_error(500, headers)
            end
        end

        self:complete_request(request, response)
    end
end

function c:build_response_error( status, stderr )
    if self.worker.args.debug.show_errors then
        return {
            stdout = "Status: " .. status .. "\r\nContent-Length: " .. (#stderr+7) .. "\r\n\r\nError: " .. stderr,
            stderr = stderr,
        }
    else
        return {
            stdout = "Status: " .. status .. "\r\nContent-Length: 5\r\n\r\nError",
            stderr = stderr,
        }
    end
end

function c:build_response_success( status, headers, stdout )
    if headers[1] and headers[1]:sub(1,7):lower() ~= "status:" then
        table.insert(headers, 1, "Status: " .. status)
    end

    table.insert(headers, "Content-Length: " .. #stdout)

    if headers[#headers] ~= "" then
        table.insert(headers, "")
    end

    table.insert(headers, stdout)

    return {
        stdout = table.concat(headers, "\r\n"),
        stderr = "",
    }
end

function c:complete_request( request, response )
    if not request.keepalive then
        self.close_after_write = true
    end

    self.requests[request.id] = nil

    self.worker.threads:push(request.tid, request.t)

    local packets = {}

    if #response.stdout > 0 then
        table.insert(packets, fcgi.pack {
            id = request.id,
            type = fcgi.f.FCGI_STDOUT,
            body = response.stdout,
        })
    end

    table.insert(packets, fcgi.pack {
        id = request.id,
        type = fcgi.f.FCGI_STDOUT,
    })

    if #response.stderr > 0 then
        table.insert(packets, fcgi.pack {
            id = request.id,
            type = fcgi.f.FCGI_STDERR,
            body = response.stderr,
        })

        table.insert(packets, fcgi.pack {
            id = request.id,
            type = fcgi.f.FCGI_STDERR,
        })
    end

    table.insert(packets, fcgi.pack {
        id = request.id,
        type = fcgi.f.FCGI_END_REQUEST,
        app_status = 0,
        protocol_status = fcgi.f.FCGI_REQUEST_COMPLETE,
    })

    self:send(table.concat(packets))
end

--

return c
