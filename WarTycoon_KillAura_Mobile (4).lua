-- War Tycoon Kill Aura Mobile v8
-- v7 문제: InvokeServer 반환값(nil)을 rocket ID로 가정 → 잘못된 가설
-- 오픈소스 검증 시그니처:
--   FireRocket:InvokeServer(dir, workspace[LP][wep], workspace[LP][wep], pos)
--   RocketHit:FireServer(pos, dir, wep, wep, head, head, LP.Name.."Rocket"..n)
-- FireRocket은 보통 nil 반환. rocketNumber는 클라 카운터(1부터).
-- pcall 에러를 노출하고 여러 시그니처를 로테이션 테스트.

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
    speed = 10,
    shots = 6,
    debug = true,
    sig = 1,
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

local cache = { rpg = nil, bullet = nil, rocketModel = nil, acs = nil, t = 0 }
local setCheck = {}
local rocketNum = 1
local errOnce = {}
local stats = { fireOk = 0, fireFail = 0, hitOk = 0, hitFail = 0 }

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
    local list = getNilInstances()
    for _, obj in ipairs(list) do
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

-- CRITICAL: War Tycoon weapons live under workspace[PlayerName]
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

-- Prefer workspace clone of the same weapon name
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

local function equipTool(tool)
    if not tool then
        return
    end
    if cache.acs then
        local settings = nil
        for _, child in ipairs(tool:GetChildren()) do
            if child:IsA("ModuleScript") and (child.Name == "Settings" or child.Name:find("Setting")) then
                pcall(function()
                    settings = require(child)
                end)
                break
            end
        end
        local ok, err = pcall(function()
            cache.acs:FireServer(tool, settings or {})
        end)
        if not ok then
            noteErr("acs_equip", err)
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
}

local function nextHitId()
    local id = LP.Name .. "Rocket" .. tostring(rocketNum)
    rocketNum = rocketNum + 1
    if rocketNum > 999999 then
        rocketNum = 1
    end
    return id
end

-- Signature set from working open-source War Tycoon scripts
local function fireRpg(tool, t)
    local r = cache.rpg
    if not r or not r.fire then
        return
    end

    local wep = resolveWeapon(tool, tool.Name)
    local dir = t.pos - t.origin
    if dir.Magnitude < 0.01 then
        return
    end
    dir = dir.Unit
    local pos = t.pos
    local head = t.head
    local terrain = WS:FindFirstChildOfClass("Terrain") or WS.Terrain
    local hitId = nextHitId()
    local sig = S.sig

    -- FireRocket variants (nil return is normal)
    local fireOk, fireErr, fireRet
    if sig == 1 then
        -- most common open-source
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, wep, pos)
        end)
    elseif sig == 2 then
        -- camera/terrain style
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, wep, t.origin, nil, terrain)
        end)
    elseif sig == 3 then
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, wep, pos, nil, terrain)
        end)
    elseif sig == 4 then
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, tool, pos)
        end)
    else
        fireOk, fireErr = pcall(function()
            fireRet = r.fire:InvokeServer(dir, wep, wep, pos)
        end)
    end

    if fireOk then
        stats.fireOk = stats.fireOk + 1
    else
        stats.fireFail = stats.fireFail + 1
        noteErr("FireRocket_sig" .. tostring(sig), fireErr)
    end

    -- FireRocketClient (visual / some servers track this)
    if r.fireClient and cache.rocketModel then
        pcall(function()
            r.fireClient:Fire(pos, dir, RPG_PAYLOAD, cache.rocketModel, wep, wep, LP)
        end)
    elseif r.fireClient then
        pcall(function()
            r.fireClient:Fire(pos, dir, RPG_PAYLOAD, wep, wep, wep, LP)
        end)
    end

    if not S.explode or not r.hit then
        return
    end

    -- RocketHit variants
    local hitOk, hitErr
    if sig == 1 then
        hitOk, hitErr = pcall(function()
            r.hit:FireServer(pos, dir, wep, wep, head, head, hitId)
        end)
    elseif sig == 2 then
        -- Terrain hit + plain "NameRocket"
        hitOk, hitErr = pcall(function()
            r.hit:FireServer(pos, dir, wep, wep, terrain, terrain, LP.Name .. "Rocket")
        end)
    elseif sig == 3 then
        hitOk, hitErr = pcall(function()
            r.hit:FireServer(pos, dir, wep, wep, head, head, LP.Name .. "Rocket")
        end)
    elseif sig == 4 then
        hitOk, hitErr = pcall(function()
            r.hit:FireServer(pos, dir, wep, wep, head, head, hitId)
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

    if S.debug and (stats.fireOk + stats.fireFail) <= 3 then
        dprint(string.format(
            "sig=%d wep=%s src_ok=%s ret=%s hit_ok=%s id=%s tgt=%s d=%.0f",
            sig, tostring(wep and wep.Name), tostring(fireOk), tostring(fireRet),
            tostring(hitOk), hitId, tostring(t.name), t.d
        ))
        dprint("wep parent=", wep and wep.Parent and wep.Parent.Name)
    end
end

local function fireGun(tool, t)
    local b = cache.bullet
    if not b or not b.fire then
        return
    end
    local wep = resolveWeapon(tool, tool.Name)
    local dir = t.pos - t.origin
    if dir.Magnitude < 0.01 then
        return
    end
    dir = dir.Unit
    local nilWep = findNilWeapon(tool.Name)

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
            dprint("no weapon found. Hold RPG. wsPlayer=", tostring(getWsPlayer() ~= nil))
        end
        return
    end

    if S.autoEquip and not equipped then
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

    for i = 1, math.min(#list, 4) do
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
            "stat fire=%d/%d hit=%d/%d sig=%d wep=%s@%s targets=%d",
            stats.fireOk, stats.fireFail, stats.hitOk, stats.hitFail,
            S.sig, tool.Name, tostring(where), #list
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
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        return pg
    end
    return CoreGui
end

local parent = guiParent()
pcall(function()
    local old = parent:FindFirstChild("WT_KA_v8")
    if old then
        old:Destroy()
    end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "WT_KA_v8"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.DisplayOrder = 999999
sg.IgnoreGuiInset = true
sg.Parent = parent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 250, 0, 340)
main.Position = UDim2.new(0, 12, 0.3, 0)
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
title.Text = "  Kill Aura v8"
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
lay.Padding = UDim.new(0, 5)
lay.Parent = holder

local function addCheck(order, label, key, defaultOn)
    S[key] = defaultOn and true or false
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 32)
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
    box.Size = UDim2.new(0, 20, 0, 20)
    box.Position = UDim2.new(0, 8, 0.5, -10)
    box.BorderSizePixel = 0
    box.Parent = row

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 5)
    bc.Parent = box

    local mark = Instance.new("TextLabel")
    mark.Size = UDim2.new(1, 0, 1, 0)
    mark.BackgroundTransparency = 1
    mark.TextColor3 = Color3.fromRGB(255, 255, 255)
    mark.TextSize = 13
    mark.Font = Enum.Font.GothamBold
    mark.Parent = box

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -40, 1, 0)
    txt.Position = UDim2.new(0, 36, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = label
    txt.TextColor3 = Color3.fromRGB(230, 230, 235)
    txt.TextSize = 13
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
    end

    local last = 0
    local function flip()
        local n = tick()
        if n - last < 0.2 then
            return
        end
        last = n
        setCheck[key](not S[key])
    end
    row.MouseButton1Click:Connect(flip)
end

addCheck(1, "Kill Aura", "killAura", false)
addCheck(2, "Team Check", "teamCheck", true)
addCheck(3, "Auto Equip", "autoEquip", true)
addCheck(4, "RPG Mode", "useRpg", true)
addCheck(5, "Gun / Sniper", "useGun", true)
addCheck(6, "Explode Hit", "explode", true)

-- Signature cycle button
local sigBtn = Instance.new("TextButton")
sigBtn.Size = UDim2.new(1, 0, 0, 32)
sigBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
sigBtn.BorderSizePixel = 0
sigBtn.Text = "Signature: 1/4  (tap cycle)"
sigBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
sigBtn.TextSize = 12
sigBtn.Font = Enum.Font.Gotham
sigBtn.LayoutOrder = 7
sigBtn.Parent = holder
local sc = Instance.new("UICorner")
sc.CornerRadius = UDim.new(0, 8)
sc.Parent = sigBtn
sigBtn.MouseButton1Click:Connect(function()
    S.sig = S.sig % 4 + 1
    errOnce = {}
    stats = { fireOk = 0, fireFail = 0, hitOk = 0, hitFail = 0 }
    sigBtn.Text = "Signature: " .. S.sig .. "/4  (tap cycle)"
    dprint("switched to signature", S.sig)
end)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 28)
info.BackgroundTransparency = 1
info.Text = "v8 | Q toggle | hold RPG"
info.TextColor3 = Color3.fromRGB(140, 140, 155)
info.TextSize = 11
info.Font = Enum.Font.Gotham
info.LayoutOrder = 99
info.Parent = holder

local function killGui()
    S.killAura = false
    sg:Destroy()
end
close.MouseButton1Click:Connect(killGui)

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

-- boot diagnostics
refresh()
local function dumpBoot()
    dprint("v8 loaded parent=" .. tostring(sg.Parent))
    local r = cache.rpg
    dprint("FireRocket=", r and r.fire and r.fire.ClassName)
    dprint("RocketHit=", r and r.hit and r.hit.ClassName)
    dprint("FireRocketClient=", r and r.fireClient and r.fireClient.ClassName)
    dprint("rocketModel=", cache.rocketModel and cache.rocketModel.Name)
    dprint("FireGun=", cache.bullet and cache.bullet.fire and cache.bullet.fire.ClassName)
    dprint("ACS Equip=", cache.acs and cache.acs.ClassName)

    local wsp = getWsPlayer()
    dprint("workspace[LP]=", wsp and wsp.ClassName, wsp and wsp.Name)
    if wsp then
        local tools = {}
        for _, c in ipairs(wsp:GetChildren()) do
            if c:IsA("Tool") then
                tools[#tools + 1] = c.Name
            end
        end
        dprint("ws tools:", table.concat(tools, ", "))
    end

    local tool, name, eq, where = findTool()
    dprint("findTool:", name, "eq=", eq, "where=", where)

    -- one-shot probe of FireRocket (no hit) if RPG present
    if tool and RPG_NAMES[tool.Name] and r and r.fire then
        local wep = resolveWeapon(tool, tool.Name)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dir = hrp.CFrame.LookVector
            local ok, err = pcall(function()
                local ret = r.fire:InvokeServer(dir, wep, wep, hrp.Position + dir * 50)
                dprint("probe InvokeServer ret type=", type(ret), "val=", ret)
            end)
            if not ok then
                warn("[KA] probe FireRocket FAILED:", err)
            else
                dprint("probe FireRocket call succeeded (nil ret is normal)")
            end
        end
    end
end
dumpBoot()
