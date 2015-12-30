--

local class = require "class"

--

local c = class:FcgiConfigurator {
    data = false,
}

--

function c:check()
    local t = type(self.data)
    local es

    if t=="table" then
        -- do nothing - already loaded, or was provided inline
    elseif t=="string" then
        self.data, es = self:load(self.data)

        if not self.data then
            return false, es
        end
    else
        return false, "self.data must be a string/table"
    end

    return self
end

function c:load( path )
    local r, es

    r, es = loadfile(path, "bt")

    if not r then
        return false, es
    end

    r, es = pcall(r)

    if not r then
        return false, es
    elseif type(es) ~= "table" then
        return false, "conf file must return a table"
    else
        return es
    end
end

--

return c
