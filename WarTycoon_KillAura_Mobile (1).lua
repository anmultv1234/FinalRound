-- War Tycoon Kill Aura Mobile v4
-- Checkbox UI + CoreGui | no WaitForChild hang | no goto | no task

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
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

local cache = { rpg = nil, bullet = nil, acs = nil, t = 0 }
local setCheck = {}

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
                hit = ev:FindFirstChild("RocketHit"),
            }
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

local function findTool()
    local char = LP.Character
    local bp = LP:FindFirstChild("Backpack")
    for i = 1, #ORDER do
        local n = ORDER[i]
        if char then
            local t = char:FindFirstChild(n)
            if t and t:IsA("Tool") then
                return t, n, true
            end
        end
        if bp then
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
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum:EquipTool(tool)
        end)
    end
    if cache.acs then
        local mod = tool:FindFirstChild("Settings")
        local settings = nil
        if mod and mod:IsA("ModuleScript") then
            pcall(function()
                settings = require(mod)
            end)
        end
        pcall(function()
            cache.acs:FireServer(tool, settings or {})
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
    local pls = Players:GetPlayers()
    for i = 1, #pls do
        local p = pls[i]
        if enemy(p) and p.Character then
            local thrp = p.Character:FindFirstChild("HumanoidRootPart")
            local head = p.Character:FindFirstChild("Head") or thrp
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
    pcall(function()
        r.fire:InvokeServer(dir, tool, tool, t.pos)
    end)
    if S.explode and r.hit and t.head then
        pcall(function()
            r.hit:FireServer(
                t.pos,
                dir,
                tool,
                tool,
                t.head,
                t.head,
                LP.Name .. "_" .. tostring(math.random(100000, 999999))
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
    pcall(function()
        b.fire:FireServer({ dir }, tool, tool, t.pos, false)
    end)
    if b.hit and t.head then
        pcall(function()
            b.hit:FireServer(
                t.pos,
                { dir },
                tool,
                tool,
                t.head,
                t.head,
                LP.Name .. "_" .. tostring(math.random(100000, 999999))
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

-- GUI parent: CoreGui first
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
    local old = parent:FindFirstChild("WT_KA_v4")
    if old then
        old:Destroy()
    end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "WT_KA_v4"
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
title.Text = "  Kill Aura"
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
            p0.X.Scale,
            p0.X.Offset + d.X,
            p0.Y.Scale,
            p0.Y.Offset + d.Y
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
print("[KA] v4 loaded parent=" .. tostring(sg.Parent))
print("[KA] rpg=" .. tostring(cache.rpg ~= nil) .. " gun=" .. tostring(cache.bullet ~= nil))
