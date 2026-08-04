-- War Tycoon Kill Aura Mobile v6
-- Fixed: workspace weapon path, RocketHit ID format, FireRocketClient call, getnilinstances polyfill

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
}

local RPG = { RPG = true, Javelin = true, Stinger = true }
local ORDER = {
    "RPG", "Javelin", "Stinger",
    "M40 Sniper", "M107", "Barrett", "L96", "MSR", "AWP",
    "M4A1", "AK-47", "SCAR-H", "G36C", "AUG", "M16A4",
    "MP5", "UMP45", "P90", "Vector",
    "Remington 870", "SPAS-12", "AA-12",
}

local cache = { rpg = nil, bullet = nil, rocketModel = nil, acs = nil, t = 0 }
local setCheck = {}

local function getNilInstances()
    local ok, fn = pcall(function()
        return rawget(_G, "getnilinstances")
    end)
    if ok and type(fn) == "function" then
        local ok2, list = pcall(fn)
        if ok2 and type(list) == "table" then
            return list
        end
    end
    return {}
end

local nilWeaponCache = {}
local function findNilWeapon(name)
    if nilWeaponCache[name] then
        local ok = pcall(function()
            local _ = nilWeaponCache[name].Name
        end)
        if ok then
            return nilWeaponCache[name]
        end
        nilWeaponCache[name] = nil
    end
    local list = getNilInstances()
    for _, obj in ipairs(list) do
        if type(obj) == "userdata" or type(obj) == "table" then
            local ok, n = pcall(function()
                return obj.Name
            end)
            if ok and (n == name or n == "S" .. name) then
                nilWeaponCache[name] = obj
                return obj
            end
        end
    end
    local bfs = RS:FindFirstChild("BulletFireSystem")
    if bfs then
        for _, obj in ipairs(bfs:GetDescendants()) do
            if obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart") then
                if obj.Name == name or obj.Name == "S" .. name then
                    nilWeaponCache[name] = obj
                    return obj
                end
            end
        end
    end
    return nil
end

local function refresh()
    local now = tick()
    if now - cache.t < 2 and (cache.rpg or cache.bullet) then
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

    local acs = RS:FindFirstChild("ACS_Engine")
    if acs then
        local ev = acs:FindFirstChild("Events")
        cache.acs = ev and ev:FindFirstChild("Equip")
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

-- War Tycoon weapons are in workspace[PlayerName], NOT Character/Backpack
local function findTool()
    local wsPlayer = WS:FindFirstChild(LP.Name)
    if not wsPlayer then
        return nil, nil, false
    end
    for i = 1, #ORDER do
        local n = ORDER[i]
        local t = wsPlayer:FindFirstChild(n)
        if t and t:IsA("Tool") then
            -- Check if equipped (parent is wsPlayer, not inside a container)
            if t.Parent == wsPlayer then
                return t, n, true
            end
            return t, n, false
        end
    end
    -- Fallback: try Character and Backpack
    local char = LP.Character
    if char then
        for i = 1, #ORDER do
            local n = ORDER[i]
            local t = char:FindFirstChild(n)
            if t and t:IsA("Tool") then
                return t, n, true
            end
        end
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for i = 1, #ORDER do
            local n = ORDER[i]
            local t = bp:FindFirstChild(n)
            if t and t:IsA("Tool") then
                return t, n, false
            end
        end
    end
    return nil, nil, false
end

local function equipTool(tool)
    if not tool then
        return
    end
    -- ACS Equip first (server registration)
    if cache.acs then
        local settings = nil
        local mod = tool:FindFirstChild("Settings")
        if mod and mod:IsA("ModuleScript") then
            pcall(function()
                settings = require(mod)
            end)
        end
        pcall(function()
            cache.acs:FireServer(tool, settings or {})
        end)
    end
    -- Humanoid equip
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
            if thrp and head then
                local d = (thrp.Position - origin).Magnitude
                if d <= S.range then
                    list[#list + 1] = {
                        head = head,
                        pos = head.Position,
                        d = d,
                        origin = origin,
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

local rocketNum = 0

local RPG_PAYLOAD = {
    ["expShake"] = { ["fadeInTime"] = 0.05, ["magnitude"] = 3,
        ["rotInfluence"] = {0.4, 0, 0.4}, ["fadeOutTime"] = 0.5,
        ["posInfluence"] = {1, 1, 0}, ["roughness"] = 3},
    ["gravity"] = Vector3.new(0, -20, 0),
    ["HelicopterDamage"] = 450, ["FireRate"] = 15,
    ["VehicleDamage"] = 350, ["ExpName"] = "RPG",
    ["ExpRadius"] = 12, ["BoatDamage"] = 300,
    ["TankDamage"] = 300, ["Acceleration"] = 8,
    ["ShieldDamage"] = 170, ["Distance"] = 4000,
    ["PlaneDamage"] = 500, ["GunshipDamage"] = 170,
    ["velocity"] = 200, ["ExplosionDamage"] = 120,
}

local function fireRpg(tool, t)
    local r = cache.rpg
    if not r or not r.fire then
        return
    end
    local dir = t.pos - t.origin
    if dir.Magnitude < 0.01 then
        return
    end
    dir = dir.Unit

    -- InvokeServer registers the rocket
    pcall(function()
        r.fire:InvokeServer(dir, tool, tool, t.pos)
    end)

    -- Rocket mode: show visual + travel
    if not S.explode then
        if r.fireClient and cache.rocketModel then
            pcall(function()
                r.fireClient:Fire(
                    t.pos,
                    dir,
                    RPG_PAYLOAD,
                    cache.rocketModel,
                    tool,
                    tool,
                    LP
                )
            end)
        end
        return
    end

    -- Explode mode: instant hit via RocketHit
    if r.hit and t.head then
        rocketNum = rocketNum + 1
        pcall(function()
            r.hit:FireServer(
                t.pos,
                dir,
                tool,
                tool,
                t.head,
                t.head,
                LP.Name .. "Rocket" .. tostring(rocketNum)
            )
        end)
    end
end

local function fireGun(tool, t)
    local b = cache.bullet
    if not b or not b.fire then
        return
    end
    local dir = t.pos - t.origin
    if dir.Magnitude < 0.01 then
        return
    end
    dir = dir.Unit

    local nilWep = findNilWeapon(tool.Name)

    pcall(function()
        b.fire:FireServer(
            { dir },
            tool,
            nilWep or tool,
            t.pos,
            false
        )
    end)

    if b.hit and t.head then
        pcall(function()
            b.hit:FireServer(
                t.pos,
                { dir },
                tool,
                nilWep or tool,
                t.head,
                t.head,
                LP.Name .. "BL" .. tostring(rocketNum)
            )
        end)
    end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
    if not S.killAura then
        acc = 0
        return
    end
    acc = acc + dt
    local interval = 1 / math.max(1, S.speed)
    if acc < interval then
        return
    end
    acc = acc - interval

    refresh()
    local tool, name, equipped = findTool()
    if not tool then
        return
    end
    if S.autoEquip and not equipped then
        equipTool(tool)
    end

    local isRpg = RPG[name] == true
    if isRpg and not S.useRpg then
        return
    end
    if (not isRpg) and not S.useGun then
        return
    end

    local list = targets()
    for i = 1, #list do
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
    local old = parent:FindFirstChild("WT_KA_v6")
    if old then
        old:Destroy()
    end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "WT_KA_v6"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.DisplayOrder = 999999
sg.IgnoreGuiInset = true
sg.Parent = parent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 240, 0, 290)
main.Position = UDim2.new(0, 12, 0.35, 0)
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
title.Text = "  Kill Aura v6"
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
lay.Padding = UDim.new(0, 6)
lay.Parent = holder

local function addCheck(order, label, key, defaultOn)
    S[key] = defaultOn and true or false
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 34)
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
    box.Size = UDim2.new(0, 22, 0, 22)
    box.Position = UDim2.new(0, 8, 0.5, -11)
    box.BorderSizePixel = 0
    box.Parent = row

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 5)
    bc.Parent = box

    local mark = Instance.new("TextLabel")
    mark.Size = UDim2.new(1, 0, 1, 0)
    mark.BackgroundTransparency = 1
    mark.TextColor3 = Color3.fromRGB(255, 255, 255)
    mark.TextSize = 14
    mark.Font = Enum.Font.GothamBold
    mark.Parent = box

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -44, 1, 0)
    txt.Position = UDim2.new(0, 40, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = label
    txt.TextColor3 = Color3.fromRGB(230, 230, 235)
    txt.TextSize = 14
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

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 28)
info.BackgroundTransparency = 1
info.Text = "Range 8000 | Q toggle | hold weapon"
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

refresh()
print("[KA] v6 loaded parent=" .. tostring(sg.Parent))
print("[KA] rpg=" .. tostring(cache.rpg ~= nil) .. " gun=" .. tostring(cache.bullet ~= nil) .. " acs=" .. tostring(cache.acs ~= nil))
