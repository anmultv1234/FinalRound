-- War Tycoon Kill Aura - Mobile Safe v3
-- ASCII only / no goto / no Draggable / no TouchTap / task polyfill

print("[KA] boot")

local function safeCall(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then
        return a, b, c
    end
    return nil
end

-- task/wait polyfill without bare global lookups
local waitFn, spawnFn, delayFn
do
    local tOk, tTbl = pcall(function()
        return rawget(_G, "task")
    end)
    if tOk and type(tTbl) == "table" and type(tTbl.wait) == "function" then
        waitFn = tTbl.wait
        spawnFn = tTbl.spawn or function(f, ...)
            coroutine.wrap(f)(...)
        end
        delayFn = tTbl.delay or function(sec, f)
            spawnFn(function()
                waitFn(sec)
                f()
            end)
        end
    else
        local wOk, wFn = pcall(function()
            return rawget(_G, "wait")
        end)
        waitFn = (wOk and wFn) or function(n)
            local t0 = tick()
            n = n or 0.03
            while tick() - t0 < n do
            end
        end
        spawnFn = function(f, ...)
            coroutine.wrap(f)(...)
        end
        delayFn = function(sec, f)
            spawnFn(function()
                waitFn(sec)
                f()
            end)
        end
    end
end

local okBoot, bootErr = pcall(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local CoreGui = game:GetService("CoreGui")

    local LocalPlayer = Players.LocalPlayer
    local guard = 0
    while not LocalPlayer and guard < 200 do
        waitFn(0.05)
        LocalPlayer = Players.LocalPlayer
        guard = guard + 1
    end
    if not LocalPlayer then
        error("LocalPlayer missing")
    end

    ------------------------------------------------------------------
    -- CONFIG
    ------------------------------------------------------------------
    local CFG = {
        enabled = false,
        mode = "Explode", -- Explode | Rocket
        spamSpeed = 8,
        shotsPerTick = 5,
        killRange = 8000,
        targetMode = "All", -- All | Closest | Random
        teamCheck = true,
        autoEquip = true,
        useAcsEquip = true,
    }

    local RPG_NAMES = {
        RPG = true,
        Javelin = true,
        Stinger = true,
    }

    local WEAPON_PRIORITY = {
        "M40 Sniper", "M107", "Barrett", "L96", "MSR", "AWP",
        "RPG", "Javelin", "Stinger",
        "M4A1", "AK-47", "SCAR-H", "G36C", "AUG", "M16A4",
        "MP5", "UMP45", "P90", "Vector",
        "Remington 870", "SPAS-12", "AA-12",
    }

    ------------------------------------------------------------------
    -- REMOTE CACHE
    ------------------------------------------------------------------
    local cache = {
        rpg = nil,
        bullet = nil,
        acsEquip = nil,
        nilMesh = {},
    }

    local function refreshRemotes()
        cache.rpg = nil
        cache.bullet = nil
        cache.acsEquip = nil
        cache.nilMesh = {}
    end

    local function getRPG()
        if cache.rpg and cache.rpg.FireRocket then
            return cache.rpg
        end
        local rs = ReplicatedStorage:FindFirstChild("RocketSystem")
        if not rs then
            return nil
        end
        local ev = rs:FindFirstChild("Events")
        if not ev then
            return nil
        end
        local rockets = rs:FindFirstChild("Rockets")
        cache.rpg = {
            FireRocket = ev:FindFirstChild("FireRocket"),
            FireRocketClient = ev:FindFirstChild("FireRocketClient"),
            RocketHit = ev:FindFirstChild("RocketHit"),
            RocketModel = rockets and rockets:FindFirstChild("RPG Rocket") or nil,
        }
        if not cache.rpg.FireRocket then
            cache.rpg = nil
            return nil
        end
        return cache.rpg
    end

    local function getBullet()
        if cache.bullet and cache.bullet.FireGun then
            return cache.bullet
        end
        local bfs = ReplicatedStorage:FindFirstChild("BulletFireSystem")
        if not bfs then
            return nil
        end
        cache.bullet = {
            FireGun = bfs:FindFirstChild("FireGun"),
            HitEvent = bfs:FindFirstChild("HitEvent")
                or bfs:FindFirstChild("BulletHit")
                or bfs:FindFirstChild("OnHit"),
        }
        if not cache.bullet.FireGun then
            cache.bullet = nil
            return nil
        end
        return cache.bullet
    end

    local function getAcsEquip()
        if cache.acsEquip ~= nil then
            return cache.acsEquip
        end
        local acs = ReplicatedStorage:FindFirstChild("ACS_Engine")
        if not acs then
            cache.acsEquip = false
            return false
        end
        local events = acs:FindFirstChild("Events")
        local equip = events and events:FindFirstChild("Equip")
        cache.acsEquip = equip or false
        return cache.acsEquip
    end

    local function getExecFn(name)
        local ok, fn = pcall(function()
            return rawget(_G, name)
        end)
        if ok and type(fn) == "function" then
            return fn
        end
        return nil
    end

    local function findNilMesh(name)
        if cache.nilMesh[name] ~= nil then
            local obj = cache.nilMesh[name]
            if obj == false then
                return nil
            end
            local alive = pcall(function()
                return obj.Name
            end)
            if alive then
                return obj
            end
            cache.nilMesh[name] = nil
        end

        local gn = getExecFn("getnilinstances")
        if type(gn) == "function" then
            local ok, list = pcall(gn)
            if ok and type(list) == "table" then
                for i = 1, #list do
                    local o = list[i]
                    if o then
                        local n = safeCall(function()
                            return o.Name
                        end)
                        if n == name or (type(n) == "string" and string.find(n, name, 1, true)) then
                            cache.nilMesh[name] = o
                            return o
                        end
                    end
                end
            end
        end

        local bfs = ReplicatedStorage:FindFirstChild("BulletFireSystem")
        if bfs then
            local ok, desc = pcall(function()
                return bfs:GetDescendants()
            end)
            if ok and type(desc) == "table" then
                for i = 1, #desc do
                    local c = desc[i]
                    if c and (c:IsA("Model") or c:IsA("Tool") or c:IsA("BasePart") or c:IsA("MeshPart")) then
                        if c.Name == name or string.find(c.Name, name, 1, true) then
                            cache.nilMesh[name] = c
                            return c
                        end
                    end
                end
            end
        end

        cache.nilMesh[name] = false
        return nil
    end

    ------------------------------------------------------------------
    -- WEAPONS
    ------------------------------------------------------------------
    local function findToolByName(name)
        local char = LocalPlayer.Character
        if char then
            local t = char:FindFirstChild(name)
            if t and t:IsA("Tool") then
                return t, "Character"
            end
        end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            local t = bp:FindFirstChild(name)
            if t and t:IsA("Tool") then
                return t, "Backpack"
            end
        end
        return nil, nil
    end

    local function getActiveWeapon()
        for i = 1, #WEAPON_PRIORITY do
            local name = WEAPON_PRIORITY[i]
            local tool, loc = findToolByName(name)
            if tool then
                return tool, name, loc
            end
        end
        -- any tool in character first
        local char = LocalPlayer.Character
        if char then
            for _, c in ipairs(char:GetChildren()) do
                if c:IsA("Tool") then
                    return c, c.Name, "Character"
                end
            end
        end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, c in ipairs(bp:GetChildren()) do
                if c:IsA("Tool") then
                    return c, c.Name, "Backpack"
                end
            end
        end
        return nil, nil, nil
    end

    local function acsRegister(tool)
        if not CFG.useAcsEquip or not tool then
            return
        end
        local equip = getAcsEquip()
        if not equip then
            return
        end
        pcall(function()
            equip:FireServer(tool, {})
        end)
    end

    local function equipBestWeapon()
        local char = LocalPlayer.Character
        if not char then
            return
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        for i = 1, #WEAPON_PRIORITY do
            local name = WEAPON_PRIORITY[i]
            local tool, loc = findToolByName(name)
            if tool then
                acsRegister(tool)
                if loc == "Backpack" and hum then
                    pcall(function()
                        hum:EquipTool(tool)
                    end)
                end
                return tool, name
            end
        end
        return nil, nil
    end

    ------------------------------------------------------------------
    -- TARGETS
    ------------------------------------------------------------------
    local function teamTag(plr)
        local ok, t = pcall(function()
            return plr.Team
        end)
        if ok and t then
            return t
        end
        local ok2, tc = pcall(function()
            return tostring(plr.TeamColor)
        end)
        if ok2 and tc then
            return tc
        end
        local ls = plr:FindFirstChild("leaderstats")
        if ls then
            local tv = ls:FindFirstChild("Team")
            if tv then
                return tv.Value
            end
        end
        return nil
    end

    local function isEnemy(plr)
        if plr == LocalPlayer then
            return false
        end
        if not CFG.teamCheck then
            return true
        end
        local a = teamTag(LocalPlayer)
        local b = teamTag(plr)
        if a == nil or b == nil then
            return true
        end
        return a ~= b
    end

    local function getTargets()
        local char = LocalPlayer.Character
        if not char then
            return {}
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            return {}
        end
        local origin = hrp.Position
        local out = {}
        local list = Players:GetPlayers()
        for i = 1, #list do
            local plr = list[i]
            if isEnemy(plr) then
                local c = plr.Character
                if c then
                    local ehrp = c:FindFirstChild("HumanoidRootPart")
                    local head = c:FindFirstChild("Head") or ehrp
                    local hum = c:FindFirstChildOfClass("Humanoid")
                    if ehrp and hum and hum.Health > 0 then
                        local d = (ehrp.Position - origin).Magnitude
                        if d <= CFG.killRange then
                            out[#out + 1] = {
                                player = plr,
                                distance = d,
                                head = head,
                                headPos = head and head.Position or ehrp.Position,
                                hrp = ehrp,
                                hrpPos = ehrp.Position,
                            }
                        end
                    end
                end
            end
        end
        table.sort(out, function(a, b)
            return a.distance < b.distance
        end)

        if #out == 0 then
            return out
        end
        if CFG.targetMode == "Closest" then
            return { out[1] }
        end
        if CFG.targetMode == "Random" then
            return { out[math.random(1, #out)] }
        end
        return out
    end

    ------------------------------------------------------------------
    -- FIRE
    ------------------------------------------------------------------
    local RPG_PAYLOAD = {
        expShake = {
            fadeInTime = 0.05,
            magnitude = 3,
            rotInfluence = { 0.4, 0, 0.4 },
            fadeOutTime = 0.5,
            posInfluence = { 1, 1, 0 },
            roughness = 3,
        },
        gravity = Vector3.new(0, -20, 0),
        HelicopterDamage = 450,
        FireRate = 15,
        VehicleDamage = 350,
        ExpName = "RPG",
        ExpRadius = 12,
        BoatDamage = 300,
        TankDamage = 300,
        Acceleration = 8,
        ShieldDamage = 170,
        Distance = 4000,
        PlaneDamage = 500,
        GunshipDamage = 170,
        velocity = 200,
        ExplosionDamage = 120,
    }

    local function dirTo(fromPos, toPos)
        local d = toPos - fromPos
        if d.Magnitude < 0.001 then
            return Vector3.new(0, 0, -1)
        end
        return d.Unit
    end

    local function myHrpPos()
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        return h and h.Position or nil
    end

    local function fireRPGExplode(target, tool)
        local r = getRPG()
        if not r then
            return
        end
        local origin = myHrpPos()
        if not origin then
            return
        end
        local pos = target.headPos or target.hrpPos
        local dir = dirTo(origin, pos)

        pcall(function()
            r.FireRocket:InvokeServer(dir, tool, tool, pos)
        end)

        if r.RocketHit and target.head then
            pcall(function()
                r.RocketHit:FireServer(
                    pos,
                    dir,
                    tool,
                    tool,
                    target.head,
                    target.head,
                    LocalPlayer.Name .. "_RK_" .. tostring(math.random(100000, 999999))
                )
            end)
        end
    end

    local function fireRPGRocket(target, tool)
        local r = getRPG()
        if not r then
            return
        end
        local origin = myHrpPos()
        if not origin then
            return
        end
        local pos = target.headPos or target.hrpPos
        local dir = dirTo(origin, pos)

        pcall(function()
            r.FireRocket:InvokeServer(dir, tool, tool, pos)
        end)

        if r.FireRocketClient and r.RocketModel then
            pcall(function()
                r.FireRocketClient:Fire(pos, dir, RPG_PAYLOAD, r.RocketModel, tool, tool, LocalPlayer)
            end)
        end
    end

    local function fireGun(target, weaponName, tool)
        local b = getBullet()
        if not b then
            return
        end
        local origin = myHrpPos()
        if not origin then
            return
        end
        local pos = target.headPos or target.hrpPos
        local dir = dirTo(origin, pos)
        local mesh = findNilMesh("S" .. weaponName) or findNilMesh(weaponName) or tool

        pcall(function()
            b.FireGun:FireServer({ dir }, tool, mesh, pos, false)
        end)

        if b.HitEvent and target.head then
            pcall(function()
                b.HitEvent:FireServer(
                    pos,
                    { dir },
                    tool,
                    mesh,
                    target.head,
                    target.head,
                    LocalPlayer.Name .. "_BL_" .. tostring(math.random(100000, 999999))
                )
            end)
        end
    end

    ------------------------------------------------------------------
    -- LOOP
    ------------------------------------------------------------------
    local function tickOnce()
        if not CFG.enabled then
            return
        end

        local tool, wname, loc = getActiveWeapon()
        if not tool then
            if CFG.autoEquip then
                equipBestWeapon()
            end
            return
        end

        -- backpack tools work for FireGun; still register via ACS
        if loc == "Backpack" then
            acsRegister(tool)
        end

        local isRpg = RPG_NAMES[wname] == true
        if isRpg then
            if not getRPG() then
                return
            end
        else
            if not getBullet() then
                return
            end
        end

        local targets = getTargets()
        if #targets == 0 then
            return
        end

        for i = 1, #targets do
            if not CFG.enabled then
                break
            end
            local t = targets[i]
            if t and (t.head or t.hrp) then
                for s = 1, CFG.shotsPerTick do
                    if not CFG.enabled then
                        break
                    end
                    if isRpg then
                        if CFG.mode == "Explode" then
                            fireRPGExplode(t, tool)
                        else
                            fireRPGRocket(t, tool)
                        end
                    else
                        fireGun(t, wname, tool)
                    end
                end
            end
        end
    end

    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        if not CFG.enabled then
            acc = 0
            return
        end
        local interval = math.max(0.05, 1 / math.max(1, CFG.spamSpeed))
        acc = acc + (dt or 0.016)
        if acc >= interval then
            acc = acc - interval
            local ok, err = pcall(tickOnce)
            if not ok then
                warn("[KA] tick:", err)
            end
        end
    end)

    ------------------------------------------------------------------
    -- GUI PARENT
    ------------------------------------------------------------------
    local function resolveParent()
        local gethuiFn = getExecFn("gethui")
        if gethuiFn then
            local ok, h = pcall(gethuiFn)
            if ok and h then
                return h
            end
        end

        local okCg, cg = pcall(function()
            local gui = Instance.new("ScreenGui")
            local synTbl = nil
            pcall(function()
                synTbl = rawget(_G, "syn")
            end)
            if type(synTbl) == "table" and type(synTbl.protect_gui) == "function" then
                pcall(synTbl.protect_gui, gui)
            end
            local clonerefFn = getExecFn("cloneref")
            if clonerefFn then
                local okc, c = pcall(clonerefFn, CoreGui)
                if okc and c then
                    gui.Parent = c
                    local p = gui.Parent
                    gui:Destroy()
                    return p
                end
            end
            gui.Parent = CoreGui
            local p = gui.Parent
            gui:Destroy()
            return p or CoreGui
        end)
        if okCg and cg then
            return cg
        end

        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then
            pcall(function()
                pg = LocalPlayer:WaitForChild("PlayerGui", 5)
            end)
        end
        return pg or CoreGui
    end

    local parent = resolveParent()

    -- destroy old
    pcall(function()
        local old = parent:FindFirstChild("WT_KillAura_Mobile")
        if old then
            old:Destroy()
        end
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local old = pg:FindFirstChild("WT_KillAura_Mobile")
            if old then
                old:Destroy()
            end
        end
    end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "WT_KillAura_Mobile"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999999
    ScreenGui.IgnoreGuiInset = true
    pcall(function()
        ScreenGui.Parent = parent
    end)
    if not ScreenGui.Parent then
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        ScreenGui.Parent = pg or CoreGui
    end

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 220, 0, 210)
    Main.Position = UDim2.new(0, 16, 0.35, 0)
    Main.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = Main

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 70)
    stroke.Thickness = 1
    stroke.Parent = Main

    local Title = Instance.new("TextButton")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, 0, 0, 36)
    Title.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    Title.BorderSizePixel = 0
    Title.Text = "KILL AURA"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 16
    Title.Font = Enum.Font.GothamBold
    Title.AutoButtonColor = false
    Title.Parent = Main

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 12)
    tc.Parent = Title

    local tfix = Instance.new("Frame")
    tfix.Size = UDim2.new(1, 0, 0, 14)
    tfix.Position = UDim2.new(0, 0, 1, -14)
    tfix.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    tfix.BorderSizePixel = 0
    tfix.Parent = Title

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, -16, 0, 28)
    Status.Position = UDim2.new(0, 8, 0, 44)
    Status.BackgroundTransparency = 1
    Status.Text = "OFF"
    Status.TextColor3 = Color3.fromRGB(255, 70, 70)
    Status.TextSize = 22
    Status.Font = Enum.Font.GothamBold
    Status.Parent = Main

    local Toggle = Instance.new("TextButton")
    Toggle.Size = UDim2.new(1, -32, 0, 52)
    Toggle.Position = UDim2.new(0, 16, 0, 80)
    Toggle.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    Toggle.Text = "ENABLE"
    Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Toggle.TextSize = 18
    Toggle.Font = Enum.Font.GothamBold
    Toggle.BorderSizePixel = 0
    Toggle.AutoButtonColor = true
    Toggle.Parent = Main

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 10)
    bc.Parent = Toggle

    local Info1 = Instance.new("TextLabel")
    Info1.Size = UDim2.new(1, -16, 0, 18)
    Info1.Position = UDim2.new(0, 8, 0, 142)
    Info1.BackgroundTransparency = 1
    Info1.Text = "Mode: " .. CFG.mode
    Info1.TextColor3 = Color3.fromRGB(170, 170, 180)
    Info1.TextSize = 12
    Info1.Font = Enum.Font.Gotham
    Info1.Parent = Main

    local Info2 = Instance.new("TextLabel")
    Info2.Size = UDim2.new(1, -16, 0, 18)
    Info2.Position = UDim2.new(0, 8, 0, 162)
    Info2.BackgroundTransparency = 1
    Info2.Text = "Range: " .. tostring(CFG.killRange)
    Info2.TextColor3 = Color3.fromRGB(170, 170, 180)
    Info2.TextSize = 12
    Info2.Font = Enum.Font.Gotham
    Info2.Parent = Main

    local Info3 = Instance.new("TextLabel")
    Info3.Size = UDim2.new(1, -16, 0, 18)
    Info3.Position = UDim2.new(0, 8, 0, 182)
    Info3.BackgroundTransparency = 1
    Info3.Text = "Target: " .. CFG.targetMode .. " | Team ON"
    Info3.TextColor3 = Color3.fromRGB(170, 170, 180)
    Info3.TextSize = 12
    Info3.Font = Enum.Font.Gotham
    Info3.Parent = Main

    local Close = Instance.new("TextButton")
    Close.Size = UDim2.new(0, 28, 0, 28)
    Close.Position = UDim2.new(1, -32, 0, 4)
    Close.BackgroundTransparency = 1
    Close.Text = "X"
    Close.TextColor3 = Color3.fromRGB(200, 200, 200)
    Close.TextSize = 16
    Close.Font = Enum.Font.GothamBold
    Close.Parent = Title

    local function setEnabled(on)
        CFG.enabled = on and true or false
        if CFG.enabled then
            Status.Text = "ON"
            Status.TextColor3 = Color3.fromRGB(60, 255, 100)
            Toggle.Text = "DISABLE"
            Toggle.BackgroundColor3 = Color3.fromRGB(30, 160, 50)
            print("[KA] ON")
        else
            Status.Text = "OFF"
            Status.TextColor3 = Color3.fromRGB(255, 70, 70)
            Toggle.Text = "ENABLE"
            Toggle.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
            print("[KA] OFF")
        end
    end

    local lastToggle = 0
    local function onToggle()
        local now = tick()
        if now - lastToggle < 0.25 then
            return
        end
        lastToggle = now
        setEnabled(not CFG.enabled)
    end

    Toggle.MouseButton1Click:Connect(onToggle)
    Toggle.Activated:Connect(onToggle)

    Close.MouseButton1Click:Connect(function()
        CFG.enabled = false
        ScreenGui:Destroy()
        print("[KA] closed")
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then
            return
        end
        if input.KeyCode == Enum.KeyCode.Q then
            setEnabled(not CFG.enabled)
        end
    end)

    -- manual drag
    local dragging = false
    local dragStart = nil
    local startPos = nil

    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)

    Title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    spawnFn(function()
        while ScreenGui.Parent do
            waitFn(30)
            refreshRemotes()
        end
    end)

    local notif = Instance.new("TextLabel")
    notif.Size = UDim2.new(0, 300, 0, 32)
    notif.Position = UDim2.new(0.5, -150, 0, 24)
    notif.BackgroundColor3 = Color3.fromRGB(30, 160, 50)
    notif.BackgroundTransparency = 0.15
    notif.Text = "Kill Aura Loaded - tap ENABLE"
    notif.TextColor3 = Color3.fromRGB(255, 255, 255)
    notif.TextSize = 14
    notif.Font = Enum.Font.Gotham
    notif.Parent = ScreenGui

    local nc = Instance.new("UICorner")
    nc.CornerRadius = UDim.new(0, 8)
    nc.Parent = notif

    delayFn(4, function()
        pcall(function()
            local tw = TweenService:Create(notif, TweenInfo.new(0.4), {
                BackgroundTransparency = 1,
                TextTransparency = 1,
            })
            tw:Play()
            tw.Completed:Wait()
            notif:Destroy()
        end)
    end)

    print("[KA] loaded parent=", tostring(ScreenGui.Parent))
    print("[KA] RocketSystem=", getRPG() and "YES" or "NO")
    print("[KA] BulletFireSystem=", getBullet() and "YES" or "NO")
    print("[KA] ACS Equip=", getAcsEquip() and "YES" or "NO")
end)

if not okBoot then
    warn("[KA] FATAL:", bootErr)
    print("[KA] FATAL:", tostring(bootErr))
end
