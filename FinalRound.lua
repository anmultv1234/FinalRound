local UIS = game:GetService("UserInputService")
if UIS.TouchEnabled and not UIS.MouseEnabled and not UIS.KeyboardEnabled then
    getgenv().bypass_adonis = true
    loadstring(game:HttpGet("https://raw.githubusercontent.com/anmultv1234/FinalRound/refs/heads/main/FinalRoundMobile.lua"))()
    return
end

getgenv().bypass_adonis = true

if not game:IsLoaded() then
    game.Loaded:Wait()
end

if not syn or not protectgui then
    getgenv().protectgui = function() end
end

if bypass_adonis then
    task.spawn(function()
        local g = getinfo or debug.getinfo
        local d = false
        local h = {}
        local x, y
        setthreadidentity(2)
        for i, v in getgc(true) do
            if typeof(v) == "table" then
                local a = rawget(v, "Detected")
                local b = rawget(v, "Kill")

                if typeof(a) == "function" and not x then
                    x = a
                    local o; o = hookfunction(x, function(c, f, n)
                        if c ~= "_" then
                            if d then
                            end
                        end
                        return true
                    end)
                    table.insert(h, x)
                end

                if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
                    y = b
                    local o; o = hookfunction(y, function(f)
                        if d then
                        end
                    end)
                    table.insert(h, y)
                end
            end
        end
        local o; o = hookfunction(getrenv().debug.info, newcclosure(function(...)
            local a, f = ...
            if x and a == x then
                return coroutine.yield(coroutine.running())
            end
            return o(...)
        end))
        setthreadidentity(7)
    end)
end

if not getgenv().ScriptState then
    getgenv().ScriptState = {
        isLockedOn = false,
        targetPlayer = nil,
        lockEnabled = false,
        aimLockKeyMode = "Toggle",
        aimLockVisibleCheck = false,
        aimLockAliveCheck = false,
        aimLockTeamCheck = false,
        targetVehicles = false,
        smoothingFactor = 0.1,
        predictionFactor = 0.0,
        bodyPartSelected = "Head",
        ClosestHitPart = nil,
        previousHighlight = nil,
        lockedTime = 12,
        reverseResolveIntensity = 5,
        Desync = false,
        antiLockEnabled = false,
        resolverIntensity = 1.0,
        resolverMethod = "Recalculate",
        fovEnabled = false,
        fovMode = "Mouse",
        nebulaEnabled = false,
        fovValue = 70,
        SelfChamsEnabled = false,
        RainbowChamsEnabled = false,
        SelfChamsColor = Color3.fromRGB(255, 255, 255),
        ChamsEnabled = false,
        isSpeedActive = false,
        isFlyActive = false,
        isNoClipActive = false,
        flySpeed = 1,
        Cmultiplier = 1,
        strafeEnabled = false,
        strafeSpeed = 50,
        strafeRadius = 5,
        strafeMode = "Horizontal",
        strafeTargetPart = nil,
        originalCameraMode = nil,
        HitboxEnabled = false,
        HitboxSize = 10,
    }
end

local ScriptState = getgenv().ScriptState

local SilentAimSettings = {
    Enabled = false,
    ClassName = "anmultv1234",
    ToggleKey = "None",
    KeyMode = "Toggle",
    TeamCheck = false,
    VisibleCheck = false,
    AliveCheck = false,
    TargetVehicles = false,
    TargetPart = "HumanoidRootPart",
    VehicleTargetPart = "TargetPart",
    SilentAimMethod = "Raycast",
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = false,
    HitChance = 100,
    MultiplyUnitBy = 1000,
    BlockedMethods = {},
    Include = { Character = true, Camera = true },
    Origin = { Camera = true },
    BulletTP = false,
    CheckForFireFunc = false,
}

getgenv().SilentAimSettings = SilentAimSettings

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    GuiService = game:GetService("GuiService"),
    UserInputService = game:GetService("UserInputService"),
    HttpService = game:GetService("HttpService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Lighting = game:GetService("Lighting"),
    SoundService = game:GetService("SoundService")
}

local Players = Services.Players
local RunService = Services.RunService
local GuiService = Services.GuiService
local UserInputService = Services.UserInputService
local HttpService = Services.HttpService
local ReplicatedStorage = Services.ReplicatedStorage
local SoundService = Services.SoundService
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Client = LocalPlayer

local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GetMouseLocation = UserInputService.GetMouseLocation

local ValidTargetParts = {"Head", "HumanoidRootPart", "None"}
local PredictionAmount = 0.165

local fov_circle = nil
if Drawing and Drawing.new then
    pcall(function()
        fov_circle = Drawing.new("Circle")
        fov_circle.Thickness = 1
        fov_circle.NumSides = 100
        fov_circle.Radius = 180
        fov_circle.Filled = false
        fov_circle.Visible = false
        fov_circle.ZIndex = 999
        fov_circle.Transparency = 1
        fov_circle.Color = Color3.fromRGB(54, 57, 241)
    end)
end

local ExpectedArguments = {
    ViewportPointToRay = { ArgCountRequired = 2, Args = { "number", "number" } },
    ScreenPointToRay = { ArgCountRequired = 2, Args = { "number", "number" } },
    Raycast = { ArgCountRequired = 3, Args = { "Instance", "Vector3", "Vector3", "RaycastParams" } },
    FindPartOnRay = { ArgCountRequired = 2, Args = { "Ray", "Instance?", "boolean?", "boolean?" } },
    FindPartOnRayWithIgnoreList = { ArgCountRequired = 2, Args = { "Ray", "table", "boolean?", "boolean?" } },
    FindPartOnRayWithWhitelist = { ArgCountRequired = 2, Args = { "Ray", "table", "boolean?" } }
}

function CalculateChance(Percentage)
    Percentage = math.floor(Percentage)
    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100
    return chance <= Percentage / 100
end

local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = Camera:WorldToScreenPoint(Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then return false end
    for Pos, Argument in next, Args do
        local Expected = RayMethod.Args[Pos]
        if not Expected then break end
        local IsOptional = Expected:sub(-1) == "?"
        local BaseType = IsOptional and Expected:sub(1, -2) or Expected
        if typeof(Argument) == BaseType then Matches = Matches + 1
        elseif IsOptional and Argument == nil then Matches = Matches + 1 end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit
end

local function getFovOrigin()
    if ScriptState.fovMode == "Center" then
        local viewportSize = Camera.ViewportSize
        return Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    end
    return GetMouseLocation(UserInputService)
end

local function playersOnSameTeam(player)
    if not player then return false end
    local okLocalTeam, localTeam = pcall(function() return LocalPlayer.Team end)
    local okTargetTeam, targetTeam = pcall(function() return player.Team end)
    if okLocalTeam and okTargetTeam and localTeam and targetTeam then return targetTeam == localTeam end
    return false
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player and Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    if not (PlayerCharacter and LocalPlayerCharacter) then return false end
    local targetPartOption = (Options and Options.TargetPart and Options.TargetPart.Value) or SilentAimSettings.TargetPart or "HumanoidRootPart"
    local PlayerRoot = FindFirstChild(PlayerCharacter, targetPartOption) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    if not PlayerRoot then return false end
    return #Camera:GetPartsObscuringTarget({ PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter }, { LocalPlayerCharacter, PlayerCharacter }) == 0
end

local function normalizeSelection(selection)
    if not selection then return {} end
    local normalized = {}
    if type(selection) ~= "table" then normalized[selection] = true return normalized end
    local hasNumericKeys = false
    for key in pairs(selection) do if type(key) == "number" then hasNumericKeys = true break end end
    if hasNumericKeys then for _, value in ipairs(selection) do normalized[value] = true end
    else for key, value in pairs(selection) do if type(key) == "string" and (value == true or type(value) == "string") then normalized[value == true and key or value] = true end end end
    return normalized
end

local function isSelectionActive(selection, option)
    return selection and selection[option] or false
end

SilentAimSettings.BlockedMethods = normalizeSelection(SilentAimSettings.BlockedMethods)
SilentAimSettings.Include = normalizeSelection(SilentAimSettings.Include)
SilentAimSettings.Origin = normalizeSelection(SilentAimSettings.Origin)

local VehicleCache = {}

local function findBestPart(vehicle)
    local vP = SilentAimSettings.VehicleTargetPart
    local part = vehicle:FindFirstChild(vP, true)
    if not part then
        for _, name in ipairs({"TargetPart", "PropellerBase", "PrimaryPart", "RudderPivotBase", "Body", "Engine", "Chassis", "Hull"}) do
            part = vehicle:FindFirstChild(name, true)
            if part and part:IsA("BasePart") then break end
        end
    end
    if not part then
        for _, child in ipairs(vehicle:GetDescendants()) do
            if child:IsA("BasePart") then return child end
        end
    end
    return part
end

local function onVehicleAdded(vehicle)
    VehicleCache[vehicle] = findBestPart(vehicle)
end
local function onVehicleRemoved(vehicle)
    VehicleCache[vehicle] = nil
end

local function setupFolder(folder)
    for _, vehicle in ipairs(folder:GetChildren()) do onVehicleAdded(vehicle) end
    folder.ChildAdded:Connect(onVehicleAdded)
    folder.ChildRemoved:Connect(onVehicleRemoved)
end

local gameSystemsInitial = workspace:FindFirstChild("Game Systems")
if gameSystemsInitial then setupFolder(gameSystemsInitial) end
workspace.ChildAdded:Connect(function(child) if child.Name == "Game Systems" then setupFolder(child) end end)

local function GetPlayerVehicle(player)
    if not player or not player.Character then return nil end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart then
        local currentSeat = humanoid.SeatPart
        for vehicle, _ in pairs(VehicleCache) do
            if typeof(vehicle) == "Instance" and currentSeat:IsDescendantOf(vehicle) then return vehicle.Name end
        end
    end
    return nil
end

local function getClosestPlayer(config)
    config = config or {}
    local targetPartOption = config.targetPart or (Options and Options.TargetPart and Options.TargetPart.Value) or SilentAimSettings.TargetPart
    local ignoredPlayers = config.ignoredPlayers or (Options and Options.PlayerDropdown and Options.PlayerDropdown.Value)
    local radiusOption = config.radius or (Options and Options.Radius and Options.Radius.Value) or SilentAimSettings.FOVRadius or 2000
    local visibleCheck = config.visibleCheck == nil and SilentAimSettings.VisibleCheck or config.visibleCheck
    local aliveCheck = config.aliveCheck == nil and SilentAimSettings.AliveCheck or config.aliveCheck
    local teamCheck = config.teamCheck == nil and ((Toggles and Toggles.TeamCheck and Toggles.TeamCheck.Value) or SilentAimSettings.TeamCheck) or config.teamCheck
    local originPosition = config.origin or getFovOrigin()
    local ClosestPart, ClosestPlayer, DistanceToMouse
    if targetPartOption ~= "None" then
        for _, Player in next, Players:GetPlayers() do
            if Player == LocalPlayer or (ignoredPlayers and ignoredPlayers[Player.Name]) or (teamCheck and playersOnSameTeam(Player)) or (visibleCheck and not IsPlayerVisible(Player)) then continue end
            local Character = Player.Character
            if not Character then continue end
            local Root = Character:FindFirstChild("HumanoidRootPart")
            local Hum = Character:FindFirstChild("Humanoid")
            if not Root or not Hum or (aliveCheck and Hum.Health <= 0) then continue end
            local ScreenPosition, OnScreen = getPositionOnScreen(Root.Position)
            if not OnScreen then continue end
            local Distance = (originPosition - ScreenPosition).Magnitude
            if Distance <= (DistanceToMouse or radiusOption) then
                local candidatePart = Character:FindFirstChild(targetPartOption == "Random" and ValidTargetParts[math.random(1, 2)] or targetPartOption)
                if candidatePart then ClosestPart, ClosestPlayer, DistanceToMouse = candidatePart, Player, Distance end
            end
        end
    end
    if SilentAimSettings.TargetVehicles or (ScriptState and ScriptState.targetVehicles) then
        local camPos, lookVector = Camera.CFrame.Position, Camera.CFrame.LookVector
        local IgnoredVehicleInstances = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer or (ignoredPlayers and ignoredPlayers[p.Name]) then
                local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.SeatPart then
                    for vehicle in pairs(VehicleCache) do
                        if hum.SeatPart:IsDescendantOf(vehicle) then IgnoredVehicleInstances[vehicle] = true break end
                    end
                end
            end
        end
        for vehicle, targetPart in pairs(VehicleCache) do
            if not vehicle.Parent or IgnoredVehicleInstances[vehicle] then continue end
            if targetPart and targetPart:IsA("BasePart") then
                if lookVector:Dot((targetPart.Position - camPos).Unit) > 0 then
                    local Pos, OnScreen = getPositionOnScreen(targetPart.Position)
                    if OnScreen then
                        local Dist = (originPosition - Pos).Magnitude
                        if Dist <= (DistanceToMouse or radiusOption) then
                            ClosestPart, ClosestPlayer, DistanceToMouse = targetPart, vehicle, Dist
                        end
                    end
                end
            end
        end
    end
    return ClosestPart, ClosestPlayer
end

local function getBodyPart(character, part) return character:FindFirstChild(part) and part or "Head" end
local function getNearestPlayerToMouse()
    local _, player = getClosestPlayer({ targetPart = ScriptState.bodyPartSelected, visibleCheck = ScriptState.aimLockVisibleCheck, aliveCheck = ScriptState.aimLockAliveCheck, teamCheck = ScriptState.aimLockTeamCheck })
    return (player and player ~= LocalPlayer) and player or nil
end

local function acquireLockTarget()
    local player = getNearestPlayerToMouse()
    if player and player.Character then
        local targetPart = player.Character:FindFirstChild(getBodyPart(player.Character, ScriptState.bodyPartSelected))
        if targetPart then ScriptState.isLockedOn = true ScriptState.targetPlayer = player return true end
    end
    ScriptState.isLockedOn = false ScriptState.targetPlayer = nil return false
end

local function toggleLockOnPlayer(forceState)
    ScriptState.lockEnabled = forceState ~= nil and forceState or not ScriptState.lockEnabled
    if ScriptState.lockEnabled then acquireLockTarget() else ScriptState.isLockedOn = false ScriptState.targetPlayer = nil end
    if Toggles and Toggles.aimLockKeyToggle and Toggles.aimLockKeyToggle.Value ~= ScriptState.lockEnabled then Toggles.aimLockKeyToggle:SetValue(ScriptState.lockEnabled) end
end

RunService.RenderStepped:Connect(function()
    if ScriptState.lockEnabled and not ScriptState.isLockedOn then acquireLockTarget() end
    if ScriptState.lockEnabled and ScriptState.isLockedOn and ScriptState.targetPlayer and ScriptState.targetPlayer.Character then
        if (ScriptState.aimLockTeamCheck and ScriptState.targetPlayer.Team == LocalPlayer.Team) or (ScriptState.aimLockVisibleCheck and not IsPlayerVisible(ScriptState.targetPlayer)) then ScriptState.isLockedOn = false ScriptState.targetPlayer = nil return end
        local part = ScriptState.targetPlayer.Character:FindFirstChild(getBodyPart(ScriptState.targetPlayer.Character, ScriptState.bodyPartSelected))
        if part and ScriptState.targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * ScriptState.predictionFactor)
            if ScriptState.antiLockEnabled then
                if ScriptState.resolverMethod == "Recalculate" then predictedPosition = predictedPosition + (part.AssemblyLinearVelocity * ScriptState.resolverIntensity)
                elseif ScriptState.resolverMethod == "Randomize" then predictedPosition = predictedPosition + Vector3.new(math.random()-0.5, math.random()-0.5, math.random()-0.5) * ScriptState.resolverIntensity
                elseif ScriptState.resolverMethod == "Invert" then predictedPosition = predictedPosition - (part.AssemblyLinearVelocity * ScriptState.resolverIntensity * 2) end
            end
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, predictedPosition) * CFrame.new(0, 0, ScriptState.smoothingFactor)
        else ScriptState.isLockedOn = false ScriptState.targetPlayer = nil end
    end
end)

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/anmultv1234/FinalRoundUI-Lib/refs/heads/main/%E2%80%8BPasteWareUIlib.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/anmultv1234/FinalRoundUI-Lib/refs/heads/main/%E2%80%8Bmanage2.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/anmultv1234/FinalRoundUI-Lib/refs/heads/main/%E2%80%8Bmanager.lua"))()
local Window = Library:CreateWindow({ Title = 'anmultv1234', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2 })

local GeneralTab = Window:AddTab("Main")
local aimbox = GeneralTab:AddRightGroupbox("AimLock")
local velbox = GeneralTab:AddRightGroupbox("Anti Lock")
local frabox = GeneralTab:AddRightGroupbox("Movement")
local ExploitTab = Window:AddTab("Exploits")
local ACSEngineBox = ExploitTab:AddLeftGroupbox("ACS Engine")
local VehicleModBox = ExploitTab:AddRightGroupbox("Vehicle Modifier")
local VisualsTab = Window:AddTab("Visuals")
local settingsTab = Window:AddTab("Settings")

local MenuGroup = settingsTab:AddLeftGroupbox("Menu")
MenuGroup:AddButton("Unload", function() Library:Unload() end)
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "None", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddToggle("ShowKeybinds", { Text = "Show Keybinds", Default = Library.KeybindFrame and Library.KeybindFrame.Visible or false, Callback = function(v) Library:SetKeybindListVisible(v) end })
if Library.KeybindFrame and Toggles.ShowKeybinds then Library:SetKeybindListVisible(Toggles.ShowKeybinds.Value) end
Library.ToggleKeybind = Options.MenuKeybind
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:ApplyToTab(settingsTab)
SaveManager:BuildConfigSection(settingsTab)

aimbox:AddToggle("aimLockKeyToggle", { Text = "aimlock", Default = false, Callback = function(v) toggleLockOnPlayer(v) end }):AddKeyPicker("aimLock_KeyPicker", { Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "AimLock", Callback = function() if Options.aimLock_KeyPicker.Mode == "Toggle" then toggleLockOnPlayer(Options.aimLock_KeyPicker:GetState()) end end })
aimbox:AddSlider("Smoothing", { Text = "Camera Smoothing", Default = 0.1, Min = 0, Max = 1, Rounding = 2, Callback = function(v) ScriptState.smoothingFactor = v end })
aimbox:AddSlider("Prediction", { Text = "Prediction Factor", Default = 0.0, Min = 0, Max = 2, Rounding = 2, Callback = function(v) ScriptState.predictionFactor = v end })
aimbox:AddToggle("aimLockVisibleCheck", { Text = "Visible Check", Default = false, Callback = function(v) ScriptState.aimLockVisibleCheck = v end })
aimbox:AddToggle("aimLockAliveCheck", { Text = "Alive Check", Default = false, Callback = function(v) ScriptState.aimLockAliveCheck = v end })
aimbox:AddToggle("aimLockTeamCheck", { Text = "Team Check", Default = false, Callback = function(v) ScriptState.aimLockTeamCheck = v end })
aimbox:AddDropdown("BodyParts", { Values = {"Head", "UpperTorso", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm"}, Default = "Head", Text = "Target Body Part", Callback = function(v) ScriptState.bodyPartSelected = v end })

RunService.Heartbeat:Connect(function()
    if getgenv().ScriptState.Desync then
        local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            local originalVelocity = rootPart.Velocity
            rootPart.Velocity = Vector3.new(math.random(-1,1), math.random(-1,1), math.random(-1,1)) * ScriptState.reverseResolveIntensity * 1000
            RunService.RenderStepped:Wait()
            rootPart.Velocity = originalVelocity
        end
    end
end)

velbox:AddToggle("desyncEnabled", { Text = "Desync", Default = false, Callback = function(v) getgenv().ScriptState.Desync = v end }):AddKeyPicker("desyncToggleKey", { Default = "None", Mode = "Toggle", Text = "Desync Toggle Key" })
velbox:AddSlider("ReverseResolveIntensity", { Text = "velocity intensity", Default = 5, Min = 1, Max = 10, Rounding = 0, Callback = function(v) ScriptState.reverseResolveIntensity = v end })
aimbox:AddToggle("antiLock_Enabled", { Text = "Anti Lock Resolver", Default = false, Callback = function(v) ScriptState.antiLockEnabled = v end })
aimbox:AddSlider("ResolverIntensity", { Text = "Resolver Intensity", Default = 1.0, Min = 0, Max = 5, Rounding = 2, Callback = function(v) ScriptState.resolverIntensity = v end })
aimbox:AddDropdown("ResolverMethods", { Values = {"Recalculate", "Randomize", "Invert"}, Default = "Recalculate", Text = "Resolver Method", Callback = function(v) ScriptState.resolverMethod = v end })

local MainBOX = GeneralTab:AddLeftTabbox("Silent Aim")
local Main = MainBOX:AddTab("Silent Aim")
local silentAimToggle = Main:AddToggle("silentAimEnabled", { Text = "Silent Aim", Default = SilentAimSettings.Enabled, Callback = function(v) SilentAimSettings.Enabled = v end })
silentAimToggle:AddKeyPicker("silentAim_KeyPicker", { Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "Enabled", Callback = function(s) silentAimToggle:SetValue(s) end })
Main:AddToggle("TeamCheck", { Text = "Team Check", Default = false }):OnChanged(function() SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value end)
Main:AddToggle("VisibleCheck", { Text = "Visible Check", Default = false }):OnChanged(function() SilentAimSettings.VisibleCheck = Toggles.VisibleCheck.Value end)
Main:AddToggle("AliveCheck", { Text = "Alive Check", Default = false }):OnChanged(function() SilentAimSettings.AliveCheck = Toggles.AliveCheck.Value end)
Main:AddToggle("TargetVehicles", { Text = "Target Vehicles", Default = false }):OnChanged(function() SilentAimSettings.TargetVehicles = Toggles.TargetVehicles.Value end)
Main:AddDropdown("VehicleTargetPart", { AllowNull = false, Text = "Vehicle Target Part", Default = "TargetPart", Values = {"TargetPart", "PropellerBase", "PrimaryPart", "RudderPivotBase"} }):OnChanged(function() SilentAimSettings.VehicleTargetPart = Options.VehicleTargetPart.Value end)
Main:AddToggle("BulletTP", { Text = "Bullet Teleport", Default = false }):OnChanged(function() SilentAimSettings.BulletTP = Toggles.BulletTP.Value end)
Main:AddToggle("CheckForFireFunc", { Text = "Check For Fire Function", Default = false }):OnChanged(function() SilentAimSettings.CheckForFireFunc = Toggles.CheckForFireFunc.Value end)
Main:AddDropdown("TargetPart", { AllowNull = true, Text = "Target Part", Default = "HumanoidRootPart", Values = {"Head", "HumanoidRootPart", "None", "Random"} }):OnChanged(function() SilentAimSettings.TargetPart = Options.TargetPart.Value end)
Main:AddDropdown("Method", { AllowNull = true, Text = "Silent Aim Method", Default = "Raycast", Values = {"ViewportPointToRay", "ScreenPointToRay", "Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "CounterBlox"} }):OnChanged(function() SilentAimSettings.SilentAimMethod = Options.Method.Value end)
Main:AddDropdown("Blocked Methods", { AllowNull = true, Multi = true, Text = "Blocked Methods", Values = {"BulkMoveTo", "PivotTo", "TranslateBy", "SetPrimaryPartCFrame"} }):OnChanged(function() SilentAimSettings.BlockedMethods = normalizeSelection(Options["Blocked Methods"].Value) end)
Main:AddDropdown("Include", { AllowNull = true, Multi = true, Text = "Include", Default = {["Camera"]=true, ["Character"]=true}, Values = {"Camera", "Character"} }):OnChanged(function() SilentAimSettings.Include = normalizeSelection(Options.Include.Value) end)
Main:AddDropdown("Origin", { AllowNull = true, Multi = true, Text = "Origin", Default = {["Camera"]=true}, Values = {"Camera"} }):OnChanged(function() SilentAimSettings.Origin = normalizeSelection(Options.Origin.Value) end)
Main:AddSlider("MultiplyUnitBy", { Text = "Multiply Unit By", Default = 1000, Min = 1, Max = 10000, Rounding = 0, Callback = function(v) SilentAimSettings.MultiplyUnitBy = v end })
Main:AddSlider("HitChance", { Text = "Hit Chance", Default = 100, Min = 0, Max = 100, Rounding = 1, Callback = function(v) SilentAimSettings.HitChance = v end })

local FieldOfViewBOX = GeneralTab:AddLeftTabbox("Field Of View") do
    local Main = FieldOfViewBOX:AddTab("Visuals")
    Main:AddToggle("Visible", {Text = "Show FOV Circle"}):AddColorPicker("Color", {Default = Color3.fromRGB(54, 57, 241)}):OnChanged(function() if fov_circle then fov_circle.Visible = Toggles.Visible.Value end SilentAimSettings.FOVVisible = Toggles.Visible.Value end)
    Main:AddSlider("Radius", { Text = "FOV Circle Radius", Min = 0, Max = 360, Default = 130, Rounding = 0 }):OnChanged(function() if fov_circle then fov_circle.Radius = Options.Radius.Value end SilentAimSettings.FOVRadius = Options.Radius.Value end)
    Main:AddDropdown("FovMode", { Values = {"Mouse", "Center"}, Default = "Mouse", Text = "FOV Origin", Callback = function(v) ScriptState.fovMode = v end })
    Main:AddToggle("MousePosition", {Text = "Show Silent Aim Target"}):AddColorPicker("MouseVisualizeColor", {Default = Color3.fromRGB(54, 57, 241)}):OnChanged(function() SilentAimSettings.ShowSilentAimTarget = Toggles.MousePosition.Value end)
    Main:AddDropdown("PlayerDropdown", { SpecialType = "Player", Text = "Ignore Player", Multi = true })
    Main:AddToggle("HitboxToggle", { Text = "Hitbox Expander", Default = false, Callback = function(v) ScriptState.HitboxEnabled = v end })
    Main:AddSlider("HitboxSize", { Text = "Hitbox Size", Default = 10, Min = 1, Max = 20, Rounding = 0, Callback = function(v) ScriptState.HitboxSize = v end })
end

local VehicleDrawings = {}
local function removeOldHighlight() if ScriptState.previousHighlight then ScriptState.previousHighlight:Destroy() ScriptState.previousHighlight = nil end end
task.spawn(function()
    RenderStepped:Connect(function()
        if Toggles.MousePosition.Value then
            local closestPart, closestPlayer = getClosestPlayer({ visibleCheck = SilentAimSettings.VisibleCheck or ScriptState.aimLockVisibleCheck, teamCheck = SilentAimSettings.TeamCheck or ScriptState.aimLockTeamCheck, aliveCheck = SilentAimSettings.AliveCheck or ScriptState.aimLockAliveCheck })
            if closestPart and closestPlayer then
                local char = (closestPlayer.Character or closestPart.Parent)
                if char and char:FindFirstChild("Humanoid") then
                    local Root = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
                    if Root then
                        local _, IsOnScreen = Camera:WorldToViewportPoint(Root.Position)
                        removeOldHighlight()
                        if IsOnScreen then
                            local highlight = char:FindFirstChildOfClass("Highlight") or Instance.new("Highlight", char)
                            highlight.Adornee = char highlight.FillColor = Options.MouseVisualizeColor.Value highlight.OutlineColor = Options.MouseVisualizeColor.Value ScriptState.previousHighlight = highlight
                        end
                    end
                end
            else removeOldHighlight() end
        end
        if fov_circle and Toggles.Visible then fov_circle.Visible = Toggles.Visible.Value fov_circle.Color = Options.Color.Value fov_circle.Position = getFovOrigin() end
        if ScriptState.HitboxEnabled then
            for _, v in pairs(Players:GetPlayers()) do
                if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("Head") then v.Character.Head.Size = Vector3.new(ScriptState.HitboxSize, ScriptState.HitboxSize, ScriptState.HitboxSize) v.Character.Head.Transparency = 0.9 end
            end
        end
    end)
end)

local hitSound = Instance.new("Sound", SoundService)
hitSound.Volume = 3
local HitSoundBox = GeneralTab:AddRightTabbox("HitSound")
HitSoundBox:AddTab("HitSound"):AddToggle("HitSoundEnabled", {Text = "Enable HitSound"}):AddDropdown("HitSoundSelect", { Values = {"RIFK7","Bubble","Minecraft","Cod","Bameware","Neverlose","Gamesense","Rust"}, Default = "Neverlose" }):OnChanged(function(v) local id = {["RIFK7"]="rbxassetid://9102080552",["Bubble"]="rbxassetid://9102092728",["Minecraft"]="rbxassetid://5869422451",["Cod"]="rbxassetid://160432334",["Bameware"]="rbxassetid://6565367558",["Neverlose"]="rbxassetid://6565370984",["Gamesense"]="rbxassetid://4817809188",["Rust"]="rbxassetid://6565371338"} hitSound.SoundId = id[v] end)

local soundPool = {}
local function playHitSound() local s = hitSound:Clone() s.Parent = workspace s:Play() game:GetService("Debris"):AddItem(s, 1) end
Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(function(char) char:WaitForChild("Humanoid").HealthChanged:Connect(function(newHp) if Toggles.HitSoundEnabled.Value and newHp < 100 then playHitSound() end end) end) end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local Method, Args = getnamecallmethod(), {...}
    if Toggles.silentAimEnabled and Toggles.silentAimEnabled.Value and self == workspace and not checkcaller() then
        local HitPart = getClosestPlayer()
        if HitPart then
            local function computeRay(origin)
                local dir = (HitPart.Position - origin).Unit * (SilentAimSettings.MultiplyUnitBy or 1000)
                return origin, dir
            end
            if Method == "Raycast" and SilentAimSettings.SilentAimMethod == "Raycast" then
                local O, D = computeRay(Args[1]) Args[1], Args[2] = O, D
                return oldNamecall(self, unpack(Args))
            elseif (Method == "FindPartOnRay" or Method == "FindPartOnRayWithIgnoreList") and SilentAimSettings.SilentAimMethod == Method then
                local O, D = computeRay(Args[1].Origin) Args[1] = Ray.new(O, D)
                return oldNamecall(self, unpack(Args))
            end
        end
    end
    return oldNamecall(self, ...)
end))

local worldbox = VisualsTab:AddRightGroupbox("World")
local lighting = Services.Lighting
worldbox:AddSlider("world_time", { Text = "Clock Time", Default = 12, Min = 0, Max = 24, Rounding = 1, Callback = function(v) lighting.ClockTime = v end })
worldbox:AddToggle("lock_time_toggle", { Text = "Lock Time", Default = false, Callback = function(v) ScriptState.lockTimeEnabled = v end })
RunService.RenderStepped:Connect(function() if ScriptState.lockTimeEnabled then lighting.ClockTime = ScriptState.lockedTime end end)

local VisualsEx = VisualsTab:AddLeftGroupbox("ESP")
VisualsEx:AddToggle("espEnabled", { Text = "Enable ESP", Default = false, Callback = function(v) if not ESP.Loaded then ESP:Load() end updateProperty({"Settings", "Enabled"}, v) refreshESPConfiguration() end })
VisualsEx:AddToggle("selfChamsEnabled", { Text = "Self Chams", Default = false, Callback = function(v) ScriptState.SelfChamsEnabled = v end })
VisualsEx:AddToggle("chamsEnabled", { Text = "Chams", Default = false, Callback = function(v) ScriptState.ChamsEnabled = v end })

frabox:AddToggle("speedEnabled", { Text = "Speed Toggle", Default = false, Callback = function(v) ScriptState.isSpeedActive = v end }):AddKeyPicker("speedToggleKey", { Default = "None", Mode = "Toggle" })
frabox:AddSlider("cframespeed", { Text = "CFrame Multiplier", Default = 1, Min = 1, Max = 20, Rounding = 1, Callback = function(v) ScriptState.Cmultiplier = v end })
frabox:AddToggle("flyEnabled", { Text = "CFly Toggle", Default = false, Callback = function(v) ScriptState.isFlyActive = v end }):AddKeyPicker("flyToggleKey", { Default = "None", Mode = "Toggle" })
frabox:AddSlider("flySpeed", { Text = "CFly Speed", Default = 1, Min = 1, Max = 50, Rounding = 1, Callback = function(v) ScriptState.flySpeed = v end })
frabox:AddToggle("noClipEnabled", { Text = "NoClip Toggle", Default = false, Callback = function(v) ScriptState.isNoClipActive = v end }):AddKeyPicker("noClipToggleKey", { Default = "None", Mode = "Toggle" })

ACSEngineBox:AddButton('INF AMMO', function() modifyWeaponSettings("Ammo", math.huge) end)
ACSEngineBox:AddButton('NO RECOIL', function() modifyWeaponSettings("VRecoil", Vector2.new(0,0)) modifyWeaponSettings("MinSpread", 0) end)
VehicleModBox:AddToggle("AutoVehicleModToggle", { Text = "Auto Mod Vehicle Weapons", Default = false, Callback = function(v) getgenv().AutoVehicleMod = v end })

local function strafeAroundTarget()
    if ScriptState.strafeTargetPart and ScriptState.strafeTargetPart.Parent then
        local angle = tick() * (ScriptState.strafeSpeed / 10)
        local offset = Vector3.new(math.cos(angle) * ScriptState.strafeRadius, 0, math.sin(angle) * ScriptState.strafeRadius)
        LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(ScriptState.strafeTargetPart.Position + offset))
    end
end

RunService.RenderStepped:Connect(function() if ScriptState.strafeEnabled then strafeAroundTarget() end end)
task.spawn(function()
    while true do task.wait()
        if ScriptState.isSpeedActive and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame + (LocalPlayer.Character.Humanoid.MoveDirection * ScriptState.Cmultiplier)
        end
        if ScriptState.isNoClipActive and LocalPlayer.Character then for _, v in pairs(LocalPlayer.Character:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end end
    end
end)
