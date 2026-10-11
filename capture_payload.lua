--[[ capture_payload.lua
     Run this FIRST in your executor, then execute bsmt_source.lua with a valid key.
     It intercepts the remote payload that BASEMENT HUB loads and saves it to disk.

     Place in your executor's workspace / autoexec folder. It hooks:
       * loadstring   -> catches the /script body before execution
       * game.HttpGet / game.HttpGetAsync / request -> catches the raw HTTP body
     Saves to: bsmt_capture_<n>.lua  (Workspace folder of the executor)
--]]

local function save(name, data)
    if type(data) ~= "string" then return end
    if #data < 64 then return end                 -- ignore tiny/irrelevant strings
    local i = 0
    while isfile and isfile("bsmt_capture_" .. i .. ".lua") do i = i + 1 end
    local path = "bsmt_capture_" .. i .. ".lua"
    local ok = pcall(function()
        if writefile then writefile(path, data) else error("no writefile") end
    end)
    if ok then
        warn(("[capture] saved %d bytes -> %s (%s)"):format(#data, path, name))
    else
        -- fallback: dump to clipboard
        if setclipboard then setclipboard(data) end
        warn(("[capture] writefile failed; %d bytes copied to clipboard (%s)"):format(#data, name))
    end
end

local g = (getgenv and getgenv()) or _G

-- 1) hook loadstring (the loader calls loadstring(response.Body))
local ls = loadstring
if hookfunction then
    hookfunction(ls, function(code, ...)
        pcall(save, "loadstring", code)
        return ls(code, ...)
    end)
elseif debug and debug.getinfo then
    -- executor without hookfunction: best-effort via closure spy
    warn("[capture] no hookfunction(); loadstring hook skipped, HTTP hook may still work")
end

-- 2) hook HTTP entry points on the game object
local function patch(holder, key)
    local orig = holder[key]
    if type(orig) ~= "function" then return end
    local wrapped = function(self, url, ...)
        local res = orig(self, url, ...)
        local isUrl = type(url) == "string" and url:find("/script", 1, true) ~= nil
        if isUrl or (type(res) == "string" and
                     res:find("function", 1, true) and #res > 500) then
            pcall(save, tostring(url), res)
        end
        return res
    end
    if hookfunction then
        pcall(hookfunction, orig, wrapped)
    end
    local ok = pcall(function() holder[key] = wrapped end)
    if not ok and getrawmetatable and setreadonly then
        local mt = getrawmetatable(holder)
        if mt and mt.__index then
            pcall(function()
                setreadonly(mt, false)
                local idx = mt.__index
                if type(idx) == "table" then idx[key] = wrapped else mt.__index = wrapped end
                setreadonly(mt, true)
            end)
        end
    end
end

pcall(patch, game, "HttpGet")
pcall(patch, game, "HttpGetAsync")

-- 3) hook the generic request/http_request libraries if present
for _, name in ipairs({ "request", "http_request", "http" }) do
    local fn = rawget(_G, name)
    if type(fn) == "function" then
        local wrapped = function(opts, ...)
            local res = fn(opts, ...)
            local body = type(res) == "table" and (res.Body or res.body) or res
            local url  = type(opts) == "table" and (opts.Url or opts.url) or tostring(opts)
            if url and tostring(url):find("/script", 1, true) then
                pcall(save, tostring(url), body)
            end
            return res
        end
        if hookfunction then pcall(hookfunction, fn, wrapped) end
        pcall(function() _G[name] = wrapped end)
    end
end

warn("[capture] armed — now run bsmt_source.lua and enter a valid key")
