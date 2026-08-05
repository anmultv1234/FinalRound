-- War Tycoon Kill Aura Mobile v9
-- v8 로그 분석:
--   sig1/4: FireRocket 성공(fire=N/0) but 데미지 0
--   sig2/3: "Chaff is not a valid member of Vector3"
--     → 6-arg 호출 시 4번째 인자는 Vector3가 아니라 Settings 테이블(.Chaff 필드)
-- v9: Settings require, ACS Equip, FireRocketClient 9-arg, 원격 스파이, 시그니처 확장

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
if not LP then
    LP = Players.PlayerAdded:Wait()
end

local S = {
    killAura = false,
    teamCheck = true,
    autoEquip = true,
    useRpg = true,
    useGun = true,
    explode = true,
    range = 8000,
    speed = 8,
    shots = 4,
    debug = true,
    sig = 1,
    spy = false,
}

local RPG_NAMES = {
    RPG = true, Javelin = true, Stinger = true,
    ["RPG Launcher"] = true, ["Rocket Launcher"] = true,
}

local ORDER = {
    "RPG", "Javelin", "Stinger", "RPG Launcher", "Rocket Launcher",
    "M40 Sniper", "M107", "Barrett", "L96", "MSR", "AWP", "Intervention",
    "M4A1", "AK-47", "SCAR-H", "G36C", "AUG", "M16A4",
    "MP5", "UMP45", "P90", "Vector",
    "Remington 870", "SPAS-12", "AA-12",
}

local cache = {
    rpg = nil, bullet = nil, rocketModel = nil, acs = nil,
    t = 0, settings = {},
}
local setCheck = {}
local rocketNum = 1
local errOnce = {}
local stats = { fireOk = 0, fireFail = 0, hitOk = 0, hitFail = 0 }
local spyInstalled = false
local lastEquip = 0

local function dprint(...)
    if S.debug then
        print("[KA]", ...)
    end
end

local function noteErr(key, err)
    if not errOnce[key] then
        errOnce[key] = true
        warn("[KA] ERR " .. key .. ": " .. tostring(err))
    end
end

local function safeRequire(mod)
    if not mod then
        return nil
    end
    local ok, res = pcall(require, mod)
    if ok then
        return res
    end
    return nil
end

local function getNilInstances()
    local fn = rawget(_G, "getnilinstances")
    if type(fn) ~= "function" then
        local ok, v = pcall(function()
            return getnilinstances
        end)
        if ok and type(v) == "function" then
            fn = v
        end
    end
    if type(fn) == "function" then
        local ok, list = pcall(fn)
        if ok and type(list) == "table" then
            return list
        end
    end
    return {}
end

local nilWeaponCache = {}
local function findNilWeapon(name)
    if nilWeaponCache[name] then
        local ok = pcall(function()
            return nilWeaponCache[name].Name
        end)
        if ok then
            return nilWeaponCache[name]
        end
        nilWeaponCache[name] = nil
    end
    for _, obj in ipairs(getNilInstances()) do
        local ok, n = pcall(function()
            return obj.Name
        end)
        if ok and (n == name or n == "S" .. name) then
            nilWeaponCache[name] = obj
            return obj
        end
    end
    return nil
end

local function refresh()
    local now = tick()
    if now - cache.t < 2 and cache.rpg and cache.rpg.fire then
        return
    end
    cache.t = now

    local rocket = RS:FindFirstChild("RocketSystem")
    if rocket then
        local ev = rocket:FindFirstChild("Events")
        if ev then
            cache.rpg = {
                fire = ev:FindFirstChild("FireRocket"),
                fireClient = ev:FindFirstChild("FireRocketClient"),
                hit = ev:FindFirstChild("RocketHit"),
            }
        end
        local rockets = rocket:FindFirstChild("Rockets")
        if rockets then
            cache.rocketModel = rockets:FindFirstChild("RPG Rocket")
                or rockets:FindFirstChild("RPG")
                or rockets:FindFirstChildWhichIsA("Model")
                or rockets:FindFirstChildWhichIsA("BasePart")
        end
    end

    local bfs = RS:FindFirstChild("BulletFireSystem")
    if bfs then
        cache.bullet = {
            fire = bfs:FindFirstChild("FireGun"),
            hit = bfs:FindFirstChild("BulletHit")
                or bfs:FindFirstChild("HitEvent")
                or bfs:FindFirstChild("OnHit"),
        }
    end

    local acs = RS:FindFirstChild("ACS_Engine") or RS:FindFirstChild("ACS_Guns")
    if acs then
        local ev = acs:FindFirstChild("Events")
        cache.acs = ev and (ev:FindFirstChild("Equip") or ev:FindFirstChild("EquipWeapon"))
    end
end

local function enemy(p)
    if p == LP then
        return false
    end
    if not S.teamCheck then
        return true
    end
    if LP.Team and p.Team then
        return LP.Team ~= p.Team
    end
    return true
end

local function getWsPlayer()
    return WS:FindFirstChild(LP.Name)
end

local function findTool()
    local wsPlayer = getWsPlayer()
    if wsPlayer then
        for i = 1, #ORDER do
            local n = ORDER[i]
            local t = wsPlayer:FindFirstChild(n)
            if t and t:IsA("Tool") then
                return t, n, true, "workspace"
            end
        end
        for _, t in ipairs(wsPlayer:GetChildren()) do
            if t:IsA("Tool") then
                return t, t.Name, true, "workspace"
            end
        end
    end

    local char = LP.Character
    if char then
        for i = 1, #ORDER do
            local n = ORDER[i]
            local t = char:FindFirstChild(n)
            if t and t:IsA("Tool") then
                return t, n, true, "character"
            end
        end
        local held = char:FindFirstChildOfClass("Tool")
        if held then
            return held, held.Name, true, "character"
        end
    end

    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for i = 1, #ORDER do
            local n = ORDER[i]
            local t = bp:FindFirstChild(n)
            if t and t:IsA("Tool") then
                return t, n, false, "backpack"
            end
        end
    end
    return nil, nil, false, nil
end

local function resolveWeapon(tool, name)
    local wsPlayer = getWsPlayer()
    if wsPlayer and name then
        local w = wsPlayer:FindFirstChild(name)
        if w and w:IsA("Tool") then
            return w
        end
    end
    if wsPlayer and tool then
        local w = wsPlayer:FindFirstChild(tool.Name)
        if w and w:IsA("Tool") then
            return w
        end
    end
    return tool
end

-- Load Settings ModuleScript from weapon (contains Chaff etc.)
local function getSettings(tool)
    if not tool then
        return nil
    end
    local key = tostring(tool)
    if cache.settings[key] ~= nil then
        return cache.settings[key] ~= false and cache.settings[key] or nil
    end

    local mod = tool:FindFirstChild("Settings")
        or tool:FindFirstChild("Setting")
        or tool:FindFirstChild("ACS_Settings")
        or tool:FindFirstChild("GunSettings")

    if not mod then
        for _, c in ipairs(tool:GetDescendants()) do
            if c:IsA("ModuleScript") then
                local n = string.lower(c.Name)
                if n:find("setting") or n:find("config") or n == "module" then
                    mod = c
                    break
                end
            end
        end
    end

    if not mod then
        -- try nil instance weapon
        local nilW = findNilWeapon(tool.Name)
        if nilW then
            mod = nilW:FindFirstChild("Settings") or nilW:FindFirstChild("Setting")
        end
    end

    local settings = nil
    if mod and mod:IsA("ModuleScript") then
        settings = safeRequire(mod)
    end

    cache.settings[key] = settings or false

    if settings and S.debug and not errOnce["settings_dump_" .. tool.Name] then
        errOnce["settings_dump_" .. tool.Name] = true
        local keys = {}
        if type(settings) == "table" then
            for k, v in pairs(settings) do
                keys[#keys + 1] = tostring(k) .. "=" .. typeof(v)
                if #keys >= 25 then
                    break
                end
            end
        end
        dprint("Settings for", tool.Name, "type=", type(settings), "keys:", table.concat(keys, ", "))
        if type(settings) == "table" then
            dprint("Chaff=", tostring(settings.Chaff), "Damage=", tostring(settings.Damage or settings.ExplosionDamage))
        end
    end

    return settings
end

local function equipTool(tool)
    if not tool then
        return
    end
    local now = tick()
    if now - lastEquip < 0.5 then
        return
    end
    lastEquip = now

    local settings = getSettings(tool)
    if cache.acs then
        local ok, err = pcall(function()
            if settings then
                cache.acs:FireServer(tool, settings)
            else
                cache.acs:FireServer(tool, {})
            end
        end)
        if not ok then
            noteErr("acs_equip", err)
        else
            dprint("ACS Equip ok", tool.Name, "settings=", settings ~= nil)
        end
    end

    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum:EquipTool(tool)
        end)
    end
end

local function targets()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return {}
    end
    local origin = hrp.Position
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if enemy(p) and p.Character then
            local thrp = p.Character:FindFirstChild("HumanoidRootPart")
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if thrp and head and hum and hum.Health > 0 then
                local d = (thrp.Position - origin).Magnitude
                if d <= S.range then
                    list[#list + 1] = {
                        head = head,
                        thrp = thrp,
                        hum = hum,
                        pos = head.Position,
                        d = d,
                        origin = origin,
                        name = p.Name,
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return a.d < b.d
    end)
    return list
end

local RPG_PAYLOAD = {
    ["expShake"] = {
        ["fadeInTime"] = 0.05, ["magnitude"] = 3,
        ["rotInfluence"] = { 0.4, 0, 0.4 }, ["fadeOutTime"] = 0.5,
        ["posInfluence"] = { 1, 1, 0 }, ["roughness"] = 3,
    },
    ["gravity"] = Vector3.new(0, -20, 0),
    ["HelicopterDamage"] = 450, ["FireRate"] = 15,
    ["VehicleDamage"] = 350, ["ExpName"] = "RPG",
    ["ExpRadius"] = 12, ["BoatDamage"] = 300,
    ["TankDamage"] = 300, ["Acceleration"] = 8,
    ["ShieldDamage"] = 170, ["Distance"] = 4000,
    ["PlaneDamage"] = 500, ["GunshipDamage"] = 170,
    ["velocity"] = 200, ["ExplosionDamage"] = 120,
    ["Chaff"] = false,
}

local function describe(v)
    local t = typeof(v)
    if t == "Instance" then
        return v.ClassName .. ":" .. v.Name .. "@" .. (v.Parent and v.Parent.Name or "nil")
    elseif t == "Vector3" then
        return string.format("V3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z)
    elseif t == "table" then
        local n = 0
        for _ in pairs(v) do
            n = n + 1
        end
        return "table#" .. n
    end
    return t .. ":" .. tostring(v)
end

local function dumpArgs(tag, ...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do
        parts[i] = i .. "=" .. describe(select(i, ...))
    end
    print("[SPY]", tag, table.concat(parts, " | "))
end

-- Hook legitimate RPG fire to learn real arg patterns
local function installSpy()
    if spyInstalled then
        return true
    end

    local function shouldLog(self)
        local ok, name = pcall(function()
            return self.Name
        end)
        if not ok or type(name) ~= "string" then
            return false
        end
        local l = string.lower(name)
        return l:find("rocket") or l:find("fire") or l:find("bullet")
            or l:find("hit") or l:find("equip") or l:find("gun")
    end

    -- preferred: hookmetamethod
    local hm = rawget(_G, "hookmetamethod")
    local gnc = rawget(_G, "getnamecallmethod")
    local ncc = rawget(_G, "newcclosure")
    if type(hm) == "function" and type(gnc) == "function" then
        local old
        local wrapper = function(self, ...)
            local method = gnc()
            if S.spy and (method == "InvokeServer" or method == "FireServer") and shouldLog(self) then
                local ok2, full = pcall(function()
                    return self:GetFullName()
                end)
                dumpArgs(method .. " " .. (ok2 and full or self.Name), ...)
            end
            return old(self, ...)
        end
        if type(ncc) == "function" then
            wrapper = ncc(wrapper)
        end
        local ok, res = pcall(function()
            old = hm(game, "__namecall", wrapper)
        end)
        if ok then
            spyInstalled = true
            dprint("spy via hookmetamethod OK")
            return true
        else
            noteErr("spy_hookmetamethod", res)
        end
    end

    -- fallback: getrawmetatable
    local grm = rawget(_G, "getrawmetatable")
    local sro = rawget(_G, "setreadonly")
    if type(grm) == "function" then
        local ok, gmt = pcall(grm, game)
        if ok and type(gmt) == "table" and gmt.__namecall then
            local old = gmt.__namecall
            pcall(function()
                if type(sro) == "function" then
                    sro(gmt, false)
                end
            end)
            local ok2, err = pcall(function()
                gmt.__namecall = function(self, ...)
                    local method = type(gnc) == "function" and gnc() or "?"
                    if S.spy and (method == "InvokeServer" or method == "FireServer") and shouldLog(self) then
                        dumpArgs(tostring(method) .. " " .. tostring(self.Name), ...)
                    end
                    return old(self, ...)
                end
            end)
            pcall(function()
                if type(sro) == "function" then
                    sro(gmt, true)
                end
            end)
            if ok2 then
                spyInstalled = true
                dprint("spy via getrawmetatable OK")
                return true
            else
                noteErr("spy_metatable", err)
            end
        end
    end

    dprint("spy unavailable on this executor")
    return false
end

local function nextHitId(fmt)
    local n = rocketNum
    rocketNum = rocketNum + 1
    if rocketNum > 999999 then
        rocketNum = 1
    end
    if fmt == 1 then
        return LP.Name .. "Rocket" .. tostring(n)
    elseif fmt == 2 then
        return LP.Name .. "Rocket"
    elseif fmt == 3 then
        return LP.Name .. "_RK_" .. tostring(math.random(100000, 999999))
    elseif fmt == 4 then
        return LP.Name .. "RK" .. tostring(n)
    end
    return LP.Name .. "Rocket" .. tostring(n)
end

local function fireClient(r, wep, pos, dir, settings)
    if not r.fireClient then
        return
    end
    local model = cache.rocketModel or wep
    local payload = settings or RPG_PAYLOAD
    -- ensure Chaff key exists if settings lacks it
    if type(payload) == "table" and payload.Chaff == nil then
        -- don't mutate required module; wrap
        local okClone = false
        local wrap = {}
        local ok, _ = pcall(function()
            for k, v in pairs(payload) do
                wrap[k] = v
            end
            wrap.Chaff = false
            okClone = true
        end)
        if okClone then
            payload = wrap
        end
    end

    -- 7-arg common
    pcall(function()
        r.fireClient:Fire(pos, dir, payload, model, wep, wep, LP)
    end)
    -- 9-arg extended (from open source)
    pcall(function()
        r.fireClient:Fire(pos, dir, payload, model, wep, wep, LP, nil, { wep })
    end)
end

local function fireRpg(tool, t)
    local r = cache.rpg
    if not r or not r.fire then
        return
    end

    local wep = resolveWeapon(tool, tool.Name)
    local settings = getSettings(wep) or getSettings(tool)
    local nilWep = findNilWeapon(tool.Name)
    local dir = t.pos - t.origin
    if dir.Magnitude < 0.01 then
        return
    end
    dir = dir.Unit
    local pos = t.pos
    local head = t.head
    local terrain = WS:FindFirstChildOfClass("Terrain") or WS.Terrain
    local sig = S.sig
    local hitId = nextHitId(((sig - 1) % 4) + 1)

    -- merge payload: prefer real settings
    local payload = settings
    if type(settings) == "table" then
        -- ok
    else
        payload = RPG_PAYLOAD
    end

    local fireOk, fireErr, fireRet

    if sig == 1 then
        -- classic 4-arg (v8 confirmed Invoke succeeds)
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, wep, pos)
        end)
    elseif sig == 2 then
        -- 6-arg with Settings (Chaff fix): dir, wep, wep, settings, pos, terrain
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, wep, payload, pos, terrain)
        end)
    elseif sig == 3 then
        -- 6-arg: dir, wep, wep, settings, nil, terrain
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, wep, payload, nil, terrain)
        end)
    elseif sig == 4 then
        -- settings as 3rd tool slot alternative
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, payload, pos)
        end)
    elseif sig == 5 then
        -- nil weapon variant
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, nilWep or wep, pos)
        end)
    elseif sig == 6 then
        -- look vector from HRP + settings
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local look = hrp and hrp.CFrame.LookVector or dir
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(look, wep, wep, hrp and hrp.Position or pos, nil, terrain)
        end)
    else
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, wep, payload, pos, terrain)
        end)
    end

    if fireOk then
        stats.fireOk = stats.fireOk + 1
    else
        stats.fireFail = stats.fireFail + 1
        noteErr("FireRocket_sig" .. tostring(sig), fireErr)
    end

    fireClient(r, wep, pos, dir, payload)

    if not S.explode or not r.hit or not head then
        return
    end

    local hitOk, hitErr
    if sig == 1 or sig == 5 then
        hitOk, hitErr = pcall(function()
            r.hit:FireServer(pos, dir, wep, wep, head, head, hitId)
        end)
    elseif sig == 2 then
        hitOk, hitErr = pcall(function()
            r.hit:FireServer(pos, dir, wep, wep, head, head, LP.Name .. "Rocket" .. tostring(rocketNum - 1))
        end)
    elseif sig == 3 then
        hitOk, hitErr = pcall(function()
            r.hit:FireServer(pos, dir, wep, wep, terrain, terrain, LP.Name .. "Rocket")
        end)
    elseif sig == 4 then
        hitOk, hitErr = pcall(function()
            r.hit:FireServer(pos, dir, wep, wep, head, head, LP.Name .. "_RK_" .. tostring(math.random(100000, 999999)))
        end)
    elseif sig == 6 then
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local look = hrp and hrp.CFrame.LookVector or dir
        hitOk, hitErr = pcall(function()
            r.hit:FireServer(pos, look, wep, wep, terrain, terrain, LP.Name .. "Rocket")
        end)
    else
        hitOk, hitErr = pcall(function()
            r.hit:FireServer(pos, dir, wep, wep, head, head, hitId)
        end)
    end

    if hitOk then
        stats.hitOk = stats.hitOk + 1
    else
        stats.hitFail = stats.hitFail + 1
        noteErr("RocketHit_sig" .. tostring(sig), hitErr)
    end

    if S.debug and (stats.fireOk + stats.fireFail) <= 4 then
        dprint(string.format(
            "sig=%d wep=%s settings=%s fire=%s ret=%s hit=%s id=%s tgt=%s",
            sig, tostring(wep and wep.Name), tostring(settings ~= nil),
            tostring(fireOk), tostring(fireRet), tostring(hitOk), hitId, tostring(t.name)
        ))
        dprint("wep.parent=", wep and wep.Parent and wep.Parent.Name, "nilWep=", nilWep ~= nil)
    end
end

local function fireGun(tool, t)
    local b = cache.bullet
    if not b or not b.fire then
        return
    end
    local wep = resolveWeapon(tool, tool.Name)
    local nilWep = findNilWeapon(tool.Name)
    local dir = t.pos - t.origin
    if dir.Magnitude < 0.01 then
        return
    end
    dir = dir.Unit

    local ok, err = pcall(function()
        b.fire:FireServer({ dir }, wep, nilWep or wep, t.pos, false)
    end)
    if not ok then
        noteErr("FireGun", err)
    end
    if b.hit and t.head then
        pcall(function()
            b.hit:FireServer(
                t.pos, { dir }, wep, nilWep or wep,
                t.head, t.head, LP.Name .. "BL" .. tostring(rocketNum)
            )
        end)
    end
end

local acc = 0
local lastStat = 0
RunService.Heartbeat:Connect(function(dt)
    if not S.killAura then
        return
    end
    acc = acc + dt
    if acc < (1 / math.max(S.speed, 1)) then
        return
    end
    acc = 0

    refresh()
    local tool, name, equipped, where = findTool()
    if not tool then
        if S.debug and tick() - lastStat > 3 then
            lastStat = tick()
            dprint("no weapon. Hold RPG. wsPlayer=", getWsPlayer() ~= nil)
        end
        return
    end

    if S.autoEquip then
        equipTool(tool)
    end

    local isRpg = RPG_NAMES[name] or RPG_NAMES[tool.Name] or false
    if not isRpg then
        local ln = string.lower(tool.Name)
        if ln:find("rpg") or ln:find("javelin") or ln:find("stinger") or ln:find("rocket") then
            isRpg = true
        end
    end

    if isRpg and not S.useRpg then
        return
    end
    if not isRpg and not S.useGun then
        return
    end

    local list = targets()
    if #list == 0 then
        return
    end

    for i = 1, math.min(#list, 3) do
        if not S.killAura then
            break
        end
        for _ = 1, S.shots do
            if isRpg then
                fireRpg(tool, list[i])
            else
                fireGun(tool, list[i])
            end
        end
    end

    if S.debug and tick() - lastStat > 2 then
        lastStat = tick()
        dprint(string.format(
            "stat fire=%d/%d hit=%d/%d sig=%d wep=%s@%s settings=%s targets=%d",
            stats.fireOk, stats.fireFail, stats.hitOk, stats.hitFail,
            S.sig, tool.Name, tostring(where),
            tostring(getSettings(tool) ~= nil), #list
        ))
    end
end)

-- ========================= GUI =========================
local function guiParent()
    local ok = pcall(function()
        local t = Instance.new("ScreenGui")
        t.Parent = CoreGui
        t:Destroy()
    end)
    if ok then
        return CoreGui
    end
    return LP:FindFirstChild("PlayerGui") or CoreGui
end

local parent = guiParent()
pcall(function()
    local old = parent:FindFirstChild("WT_KA_v9")
    if old then
        old:Destroy()
    end
    -- cleanup old versions
    for _, n in ipairs({ "WT_KA_v8", "WT_KA_v7", "WT_KA_v6" }) do
        local o = parent:FindFirstChild(n)
        if o then
            o:Destroy()
        end
    end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "WT_KA_v9"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.DisplayOrder = 999999
sg.IgnoreGuiInset = true
sg.Parent = parent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 390)
main.Position = UDim2.new(0, 12, 0.25, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
main.BorderSizePixel = 0
main.Active = true
main.Parent = sg

local c1 = Instance.new("UICorner")
c1.CornerRadius = UDim.new(0, 10)
c1.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(55, 55, 70)
stroke.Thickness = 1
stroke.Parent = main

local title = Instance.new("TextButton")
title.Size = UDim2.new(1, 0, 0, 34)
title.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
title.BorderSizePixel = 0
title.Text = "  Kill Aura v9"
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.AutoButtonColor = false
title.Parent = main

local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 10)
tc.Parent = title

local tip = Instance.new("Frame")
tip.Size = UDim2.new(1, 0, 0, 12)
tip.Position = UDim2.new(0, 0, 1, -12)
tip.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
tip.BorderSizePixel = 0
tip.Parent = title

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 30, 0, 30)
close.Position = UDim2.new(1, -32, 0, 2)
close.BackgroundTransparency = 1
close.Text = "X"
close.TextColor3 = Color3.fromRGB(180, 180, 190)
close.TextSize = 14
close.Font = Enum.Font.GothamBold
close.Parent = title

local holder = Instance.new("Frame")
holder.Size = UDim2.new(1, -16, 1, -48)
holder.Position = UDim2.new(0, 8, 0, 42)
holder.BackgroundTransparency = 1
holder.Parent = main

local lay = Instance.new("UIListLayout")
lay.SortOrder = Enum.SortOrder.LayoutOrder
lay.Padding = UDim.new(0, 4)
lay.Parent = holder

local function addCheck(order, label, key, defaultOn)
    S[key] = defaultOn and true or false
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = true
    row.LayoutOrder = order
    row.Parent = holder

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 8)
    rc.Parent = row

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 18, 0, 18)
    box.Position = UDim2.new(0, 8, 0.5, -9)
    box.BorderSizePixel = 0
    box.Parent = row

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 5)
    bc.Parent = box

    local mark = Instance.new("TextLabel")
    mark.Size = UDim2.new(1, 0, 1, 0)
    mark.BackgroundTransparency = 1
    mark.TextColor3 = Color3.fromRGB(255, 255, 255)
    mark.TextSize = 12
    mark.Font = Enum.Font.GothamBold
    mark.Parent = box

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -36, 1, 0)
    txt.Position = UDim2.new(0, 34, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = label
    txt.TextColor3 = Color3.fromRGB(230, 230, 235)
    txt.TextSize = 12
    txt.Font = Enum.Font.Gotham
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = row

    local function paint()
        if S[key] then
            box.BackgroundColor3 = Color3.fromRGB(40, 170, 70)
            mark.Text = "v"
        else
            box.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            mark.Text = ""
        end
    end
    paint()
    setCheck[key] = function(v)
        S[key] = v and true or false
        paint()
        if key == "spy" and S.spy then
            installSpy()
            dprint("SPY ON - manually fire RPG once, check console [SPY] lines")
        end
    end

    local last = 0
    row.MouseButton1Click:Connect(function()
        local n = tick()
        if n - last < 0.2 then
            return
        end
        last = n
        setCheck[key](not S[key])
    end)
end

addCheck(1, "Kill Aura", "killAura", false)
addCheck(2, "Team Check", "teamCheck", true)
addCheck(3, "Auto Equip + ACS", "autoEquip", true)
addCheck(4, "RPG Mode", "useRpg", true)
addCheck(5, "Gun / Sniper", "useGun", true)
addCheck(6, "Explode Hit", "explode", true)
addCheck(7, "Remote Spy (manual fire)", "spy", false)

local SIG_MAX = 6
local sigBtn = Instance.new("TextButton")
sigBtn.Size = UDim2.new(1, 0, 0, 30)
sigBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
sigBtn.BorderSizePixel = 0
sigBtn.Text = "Signature: 1/" .. SIG_MAX .. " (tap cycle)"
sigBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
sigBtn.TextSize = 12
sigBtn.Font = Enum.Font.Gotham
sigBtn.LayoutOrder = 8
sigBtn.Parent = holder
local sc = Instance.new("UICorner")
sc.CornerRadius = UDim.new(0, 8)
sc.Parent = sigBtn
sigBtn.MouseButton1Click:Connect(function()
    S.sig = S.sig % SIG_MAX + 1
    errOnce = {}
    stats = { fireOk = 0, fireFail = 0, hitOk = 0, hitFail = 0 }
    sigBtn.Text = "Signature: " .. S.sig .. "/" .. SIG_MAX .. " (tap cycle)"
    dprint("signature", S.sig)
end)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 36)
info.BackgroundTransparency = 1
info.Text = "v9 | Spy ON → fire RPG once\nQ toggle | hold RPG"
info.TextColor3 = Color3.fromRGB(140, 140, 155)
info.TextSize = 11
info.Font = Enum.Font.Gotham
info.LayoutOrder = 99
info.Parent = holder

close.MouseButton1Click:Connect(function()
    S.killAura = false
    sg:Destroy()
end)

local dragging = false
local d0, p0
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        d0 = input.Position
        p0 = main.Position
    end
end)
title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragging then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - d0
        main.Position = UDim2.new(
            p0.X.Scale, p0.X.Offset + d.X,
            p0.Y.Scale, p0.Y.Offset + d.Y
        )
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then
        return
    end
    if input.KeyCode == Enum.KeyCode.Q then
        if setCheck.killAura then
            setCheck.killAura(not S.killAura)
        end
    end
end)

-- boot
refresh()
local function dumpBoot()
    dprint("v9 loaded parent=" .. tostring(sg.Parent))
    local r = cache.rpg
    dprint("FireRocket=", r and r.fire and r.fire.ClassName)
    dprint("RocketHit=", r and r.hit and r.hit.ClassName)
    dprint("FireRocketClient=", r and r.fireClient and r.fireClient.ClassName)
    dprint("rocketModel=", cache.rocketModel and cache.rocketModel.Name)
    dprint("ACS Equip=", cache.acs and cache.acs.ClassName)

    local wsp = getWsPlayer()
    dprint("workspace[LP]=", wsp and wsp.ClassName)
    if wsp then
        local tools = {}
        for _, c in ipairs(wsp:GetChildren()) do
            if c:IsA("Tool") then
                tools[#tools + 1] = c.Name
            end
        end
        dprint("ws tools:", table.concat(tools, ", "))
    end

    local tool = findTool()
    if tool then
        local st = getSettings(tool)
        dprint("boot tool=", tool.Name, "settings=", st ~= nil)
        if cache.acs and st then
            pcall(function()
                cache.acs:FireServer(tool, st)
                dprint("boot ACS Equip sent")
            end)
        end

        -- probe sig1 and sig2
        if r and r.fire then
            local wep = resolveWeapon(tool, tool.Name)
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dir = hrp.CFrame.LookVector
                local pos = hrp.Position + dir * 40
                local terrain = WS.Terrain

                local ok1, err1 = pcall(function()
                    local ret = r.fire:InvokeServer(dir, wep, wep, pos)
                    dprint("probe sig1 ret=", ret)
                end)
                if not ok1 then
                    warn("[KA] probe sig1 FAIL:", err1)
                else
                    dprint("probe sig1 OK")
                end

                if st then
                    local ok2, err2 = pcall(function()
                        local ret = r.fire:InvokeServer(dir, wep, wep, st, pos, terrain)
                        dprint("probe sig2(settings) ret=", ret)
                    end)
                    if not ok2 then
                        warn("[KA] probe sig2 FAIL:", err2)
                    else
                        dprint("probe sig2(settings) OK")
                    end
                else
                    dprint("probe sig2 skipped (no Settings module on weapon)")
                end
            end
        end
    else
        dprint("boot: no tool yet - equip RPG and re-run if needed")
    end

    dprint("TIP: enable Remote Spy, manually shoot RPG, send [SPY] lines")
end
dumpBoot()
