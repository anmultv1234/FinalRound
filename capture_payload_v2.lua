--[[ capture_payload_v2.lua  (crash-safe)
     실행기에서 "실행만" 하면 됩니다. 그 다음 bsmt_source.lua를 유효 키로 실행하세요.
     원격 /script 본문(및 로드되는 모든 loadstring 문자열)을 파일로 저장합니다.

     특징
       * hookfunction / getrawmetatable / getgc 에 의존하지 않음  (모바일 실행기 OK)
       * 순수 Lua 래퍼로 loadstring / game.HttpGet 만 덮어씀
       * 모든 단계 pcall로 감쌈 → 실패해도 튕기지 않고 warn만 출력
       * 저장 실패 시 클립보드로 대체
       * 이미 훅이 걸려 있으면 중복 방지
--]]

-- 이전 실행본이 남아 중복 실행된 경우 조용히 종료
if _G.__bsmt_capture_armed then
    warn("[capture] already armed (중복 실행 방지) — skip")
    return
end
_G.__bsmt_capture_armed = true

local g = (getgenv and pcall(getgenv)) and getgenv() or _G
local counter = 0

local function next_path()
    counter = counter + 1
    return "bsmt_capture_" .. counter .. ".lua"
end

local function save(tag, data)
    if type(data) ~= "string" or #data < 64 then return end
    local path = next_path()
    local ok = false
    if type(writefile) == "function" then
        ok = pcall(writefile, path, data)
    end
    if ok then
        warn(("[capture] saved %d bytes -> %s  (%s)"):format(#data, path, tag))
        return
    end
    -- 대체: 클립보드
    local clip = (type(setclipboard) == "function" and setclipboard)
              or (type(toclipboard) == "function" and toclipboard)
              or (type(set_clipboard) == "function" and set_clipboard)
              or (type(write_clipboard) == "function" and write_clipboard)
    if type(clip) == "function" then
        if pcall(clip, data) then
            warn(("[capture] writefile 불가 → %d bytes를 클립보드에 복사함 (%s)"):format(#data, tag))
            return
        end
    end
    warn(("[capture] 저장/클립보드 모두 실패 (%s)"):format(tag))
end

-- 1) loadstring 래퍼 (hookfunction 미사용, 순수 Lua)
do
    local realLoad = loadstring or load
    if type(realLoad) == "function" then
        local function wrapped(code, chunkname, ...)
            pcall(save, "loadstring", code)
            return realLoad(code, chunkname, ...)
        end
        -- 전역/제네바 양쪽에 적용 시도
        local ok = pcall(function() _G.loadstring = wrapped end)
        if g ~= _G then pcall(function() g.loadstring = wrapped end) end
        if ok then
            warn("[capture] loadstring wrapper 설치 완료")
        else
            warn("[capture] loadstring 래핑 실패 (무시하고 계속)")
        end
    else
        warn("[capture] loadstring/load 없음 → HTTP 훅만 사용")
    end
end

-- 2) game:HttpGet / HttpGetAsync 래퍼 (래퍼는 game 객체 메타테이블에 걸어야 함)
local function wrap_game_method(method)
    local ok_any = false
    local first = nil

    -- 원본 함수 확보
    local ok = pcall(function() first = game[method] end)
    if not ok or type(first) ~= "function" then
        warn(("[capture] game.%s 접근 불가"):format(method))
        return
    end

    local function wrapped(self, url, ...)
        local args = { ... }
        local res = first(self, url, table.unpack and table.unpack(args) or unpack(args))
        local u = tostring(url)
        if u:find("/script", 1, true)
           or u:find("thebsmt", 1, true)
           or (type(res) == "string" and #res > 500 and res:find("function", 1, true)) then
            pcall(save, u, res)
        end
        return res
    end

    -- 방법 A: game에 직접 대입 (일부 실행기에서 통과)
    ok_any = pcall(function() game[method] = wrapped end)

    -- 방법 B: 메타테이블 __index 교체 (getrawmetatable 있을 때만)
    if not ok_any and type(getrawmetatable) == "function" then
        pcall(function()
            local mt = getrawmetatable(game)
            if not mt then return end
            if type(setreadonly) == "function" then pcall(setreadonly, mt, false) end
            local old = mt.__index
            if type(old) == "function" then
                mt.__index = function(t, k)
                    if k == method then return wrapped end
                    return old(t, k)
                end
                ok_any = true
            elseif type(old) == "table" then
                old[method] = wrapped
                ok_any = true
            else
                mt.__index = function(t, k)
                    if k == method then return wrapped end
                    return t[k]
                end
                ok_any = true
            end
            if type(setreadonly) == "function" then pcall(setreadonly, mt, true) end
        end)
    end

    warn(("[capture] game.%s wrap %s"):format(method, ok_any and "OK" or "실패(무시)"))
end

pcall(wrap_game_method, "HttpGet")
pcall(wrap_game_method, "HttpGetAsync")

warn("[capture] armed. 이제 bsmt_source.lua 를 유효 키로 실행하세요.")
