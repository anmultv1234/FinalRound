local UIS = game:GetService("UserInputService")
if UIS.TouchEnabled and not UIS.MouseEnabled and not UIS.KeyboardEnabled then
    getgenv().bypass_adonis = true
    loadstring(game:HttpGet(getMainUrl("PasteWareV2LegacyMobile.lua")))() return
end

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
        unswimEnabled = false,
    }
end

local SilentAimSettings = {
    Enabled = false,
    ClassName = "CustomWare",
    ToggleKey = "None",
    KeyMode = "Toggle",
    TeamCheck = false,
    VisibleCheck = false,
    AliveCheck = false,
    TargetPart = "HumanoidRootPart",
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
    TargetVehicles = false,
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

local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GetMouseLocation = UserInputService.GetMouseLocation

local ValidTargetParts = {"Head", "HumanoidRootPart"}

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 180
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

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
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
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
        if typeof(Argument) == BaseType then
            Matches = Matches + 1
        elseif IsOptional and Argument == nil then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position) return (Position - Origin).Unit end
local function getMousePosition() return GetMouseLocation(UserInputService) end

local function getFovOrigin()
    if ScriptState.fovMode == "Center" then
        local viewportSize = Camera.ViewportSize
        return Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    end
    return getMousePosition()
end

local function getTeamComparisonOption()
    local esp = rawget(getgenv(), "ExunysDeveloperESP")
    if esp and esp.DeveloperSettings and esp.DeveloperSettings.TeamCheckOption then
        return esp.DeveloperSettings.TeamCheckOption
    end
end

local function playersOnSameTeam(player)
    if not player then return false end
    local option = getTeamComparisonOption()
    if option then
        local okLocal, localValue = pcall(function() return LocalPlayer[option] end)
        local okTarget, targetValue = pcall(function() return player[option] end)
        if okLocal and okTarget and localValue ~= nil and targetValue ~= nil then
            return targetValue == localValue
        end
    end
    local okLocalTeam, localTeam = pcall(function() return LocalPlayer.Team end)
    local okTargetTeam, targetTeam = pcall(function() return player.Team end)
    if okLocalTeam and okTargetTeam and localTeam and targetTeam then return targetTeam == localTeam end
    local okLocalColor, localColor = pcall(function() return LocalPlayer.TeamColor end)
    local okTargetColor, targetColor = pcall(function() return player.TeamColor end)
    if okLocalColor and okTargetColor and localColor and targetColor then return targetColor == localColor end
    return false
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player and Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    if not (PlayerCharacter and LocalPlayerCharacter) then return false end
    local targetPartOption = (Options and Options.TargetPart and Options.TargetPart.Value) or SilentAimSettings.TargetPart or "HumanoidRootPart"
    local PlayerRoot = FindFirstChild(PlayerCharacter, targetPartOption) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    if not PlayerRoot then return false end
    local CastPoints, IgnoreList = { PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter }, { LocalPlayerCharacter, PlayerCharacter }
    return #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList) == 0
end

local function normalizeSelection(selection)
    if not selection then return {} end
    local normalized = {}
    if type(selection) ~= "table" then
        normalized[selection] = true
        return normalized
    end
    local hasNumericKeys = false
    for key in pairs(selection) do
        if type(key) == "number" then hasNumericKeys = true; break end
    end
    if hasNumericKeys then
        for _, value in ipairs(selection) do normalized[value] = true end
    else
        for key, value in pairs(selection) do
            if type(key) == "string" then
                if value == true then normalized[key] = true or type(value) == "string" then normalized[value] = true end
            end
        end
    end
    return normalized
end

local function isSelectionActive(selection, option) return selection and selection[option] or false end

SilentAimSettings.BlockedMethods = normalizeSelection(SilentAimSettings.BlockedMethods)
SilentAimSettings.Include = normalizeSelection(SilentAimSettings.Include)
SilentAimSettings.Origin = normalizeSelection(SilentAimSettings.Origin)

local function getVehicleTargetPart(vehicleModel)
    local body = FindFirstChild(vehicleModel, "Body")
    if body then
        local targetPart = FindFirstChild(body, "TargetPart")
        if targetPart and targetPart:IsA("BasePart") then return targetPart end
    end
    local func = FindFirstChild(vehicleModel, "Functionality")
    if func then
        local targetPart = FindFirstChild(func, "TargetPart")
        if targetPart and targetPart:IsA("BasePart") then return targetPart end
    end
    return nil
end

local function getClosestPlayer(config)
    config = config or {}
    local targetPartOption = config.targetPart or (Options and Options.TargetPart and Options.TargetPart.Value) or SilentAimSettings.TargetPart
    if not targetPartOption then return nil, nil end
    local ignoredPlayers = config.ignoredPlayers or (Options and Options.PlayerDropdown and Options.PlayerDropdown.Value)
    local radiusOption = config.radius or (Options and Options.Radius and Options.Radius.Value) or SilentAimSettings.FOVRadius or 2000
    local visibleCheck = config.visibleCheck if visibleCheck == nil then visibleCheck = SilentAimSettings.VisibleCheck end
    local aliveCheck = config.aliveCheck if aliveCheck == nil then aliveCheck = SilentAimSettings.AliveCheck end
    local teamCheck = config.teamCheck
    if teamCheck == nil then
        teamCheck = (Toggles and Toggles.TeamCheck and Toggles.TeamCheck.Value) or SilentAimSettings.TeamCheck or (ScriptState and ScriptState.aimLockTeamCheck) or false
    end
    local teamEvaluator = config.teamEvaluator or playersOnSameTeam
    local originPosition = config.origin if typeof(originPosition) == "function" then originPosition = originPosition() end
    originPosition = originPosition or getFovOrigin()

    local ClosestPart, ClosestPlayer, DistanceToMouse
    
    if SilentAimSettings.TargetVehicles then
        local gameSystems = workspace:FindFirstChild("Game Systems")
        if gameSystems then
            for _, folder in next, gameSystems:GetChildren() do
                if folder:IsA("Folder") and string.find(folder.Name, "Workspace") then
                    for _, vehicle in next, folder:GetChildren() do
                        if vehicle:IsA("Model") then
                            local targetPart = getVehicleTargetPart(vehicle)
                            if targetPart then
                                local ownerVal = vehicle:FindFirstChild("Owner") or vehicle:FindFirstChild("Player")
                                if ownerVal and ownerVal:IsA("ObjectValue") and ownerVal.Value == LocalPlayer then continue end
                                if teamCheck and ownerVal and ownerVal:IsA("ObjectValue") and ownerVal.Value and teamEvaluator(ownerVal.Value) then continue end
                                
                                local ScreenPosition, OnScreen = getPositionOnScreen(targetPart.Position)
                                if not OnScreen then continue end
                                local Distance = (originPosition - ScreenPosition).Magnitude
                                if Distance <= (DistanceToMouse or radiusOption) then
                                    ClosestPart = targetPart; ClosestPlayer = vehicle; DistanceToMouse = Distance
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if ClosestPart then return ClosestPart, ClosestPlayer end

    for _, Player in next, Players:GetPlayers() do
        if Player == LocalPlayer then continue end
        if ignoredPlayers and ignoredPlayers[Player.Name] then continue end
        if teamCheck and teamEvaluator(Player) then continue end
        if visibleCheck and not IsPlayerVisible(Player) then continue end
        local Character = Player.Character if not Character then continue end
        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid then continue end
        if aliveCheck and Humanoid.Health <= 0 then continue end
        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end
        local Distance = (originPosition - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or radiusOption) then
            local targetPartName = targetPartOption == "Random" and ValidTargetParts[math.random(1, #ValidTargetParts)] or targetPartOption
            local candidatePart = Character[targetPartName]
            if candidatePart then ClosestPart = candidatePart; ClosestPlayer = Player; DistanceToMouse = Distance end
        end
    end
    return ClosestPart, ClosestPlayer
end

local function getBodyPart(character, part) return character:FindFirstChild(part) and part or "Head" end
local function getNearestPlayerToMouse()
    local _, player = getClosestPlayer({targetPart = ScriptState.bodyPartSelected, visibleCheck = ScriptState.aimLockVisibleCheck, aliveCheck = ScriptState.aimLockAliveCheck, teamCheck = ScriptState.aimLockTeamCheck})
    return (player and player ~= LocalPlayer) and player or nil
end

local function acquireLockTarget()
    local player = getNearestPlayerToMouse()
    if player and player.Character then
        local partName = getBodyPart(player.Character, ScriptState.bodyPartSelected)
        if player.Character:FindFirstChild(partName) then
            ScriptState.isLockedOn = true; ScriptState.targetPlayer = player; return true
        end
    end
    ScriptState.isLockedOn = false; ScriptState.targetPlayer = nil; return false
end

local function toggleLockOnPlayer(forceState)
    local desiredState = forceState if desiredState == nil then desiredState = not ScriptState.lockEnabled end
    ScriptState.lockEnabled = desiredState
    if desiredState then acquireLockTarget() else ScriptState.isLockedOn = false; ScriptState.targetPlayer = nil end
    if Toggles.aimLockKeyToggle and Toggles.aimLockKeyToggle.Value ~= desiredState then Toggles.aimLockKeyToggle:SetValue(desiredState) end
end

RunService.RenderStepped:Connect(function()
    if ScriptState.lockEnabled and not ScriptState.isLockedOn then acquireLockTarget() end
    if ScriptState.lockEnabled and ScriptState.isLockedOn and ScriptState.targetPlayer and ScriptState.targetPlayer.Character then
        if ScriptState.aimLockTeamCheck and ScriptState.targetPlayer.Team == LocalPlayer.Team then ScriptState.isLockedOn = false; ScriptState.targetPlayer = nil; return end
        if ScriptState.aimLockVisibleCheck and not IsPlayerVisible(ScriptState.targetPlayer) then ScriptState.isLockedOn = false; ScriptState.targetPlayer = nil; return end
        local partName = getBodyPart(ScriptState.targetPlayer.Character, ScriptState.bodyPartSelected)
        local part = ScriptState.targetPlayer.Character:FindFirstChild(partName)
        if part and ScriptState.targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * ScriptState.predictionFactor)
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, predictedPosition) * CFrame.new(0, 0, ScriptState.smoothingFactor)
        else
            ScriptState.isLockedOn = false; ScriptState.targetPlayer = nil
        end
    end
end)

local Library = loadstring(game:HttpGet(getUiUrl("PasteWareUIlib.lua")))()
local ThemeManager = loadstring(game:HttpGet(getUiUrl("manage2.lua")))()
local SaveManager = loadstring(game:HttpGet(getGitUrl("manager.lua")))()

local Window = Library:CreateWindow({
    Title = 'CustomWare  |  GitHub 이관 완료',
    Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2
})

local GeneralTab = Window:AddTab("Main")
local aimbox = GeneralTab:AddRightGroupbox("AimLock")
local velbox = GeneralTab:AddRightGroupbox("Anti Lock")
local frabox = GeneralTab:AddRightGroupbox("Movement")
local ExploitTab = Window:AddTab("Exploits")
local ACSEngineBox = ExploitTab:AddLeftGroupbox("ACS Engine")
local VisualsTab = Window:AddTab("Visuals")
local settingsTab = Window:AddTab("Settings")
local MenuGroup = settingsTab:AddLeftGroupbox("Menu")

MenuGroup:AddButton("Unload", function() Library:Unload() end)
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "None", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddToggle("ShowKeybinds", {
    Text = "Show Keybinds",
    Default = Library.KeybindFrame and Library.KeybindFrame.Visible or false,
    Callback = function(value) Library:SetKeybindListVisible(value) end,
})

if Library.KeybindFrame and Toggles.ShowKeybinds then Library:SetKeybindListVisible(Toggles.ShowKeybinds.Value) end
Library.ToggleKeybind = Options.MenuKeybind
ThemeManager:SetLibrary(Library); SaveManager:SetLibrary(Library)
ThemeManager:ApplyToTab(settingsTab); SaveManager:BuildConfigSection(settingsTab)

local lastAimLockKeyState = false
local lastAimLockKeyMode = ScriptState.aimLockKeyMode

aimbox:AddToggle("aimLockKeyToggle", {
    Text = "aimlock", Default = false, Tooltip = "Toggle AimLock on or off.",
    Callback = function(value) if ScriptState.lockEnabled ~= value then toggleLockOnPlayer(value) end end,
}):AddKeyPicker("aimLock_KeyPicker", {
    Default = "None", SyncToggleState = true, Mode = ScriptState.aimLockKeyMode, Text = "AimLock", Tooltip = "Keybind for AimLock",
    Callback = function() if Options.aimLock_KeyPicker.Mode == "Toggle" then toggleLockOnPlayer(Options.aimLock_KeyPicker:GetState()) end end,
    ChangedCallback = function() lastAimLockKeyState = Options.aimLock_KeyPicker:GetState() end
})

lastAimLockKeyState = Options.aimLock_KeyPicker:GetState()
lastAimLockKeyMode = Options.aimLock_KeyPicker.Mode or lastAimLockKeyMode
ScriptState.aimLockKeyMode = lastAimLockKeyMode

RunService.RenderStepped:Connect(function()
    local keyPicker = Options.aimLock_KeyPicker if not keyPicker then return end
    local currentMode = keyPicker.Mode or "Toggle"
    if currentMode ~= lastAimLockKeyMode then
        ScriptState.aimLockKeyMode = currentMode; lastAimLockKeyMode = currentMode; lastAimLockKeyState = keyPicker:GetState()
        toggleLockOnPlayer(lastAimLockKeyState)
    end
    if currentMode ~= "Toggle" then
        local currentState = keyPicker:GetState()
        if currentState ~= lastAimLockKeyState then toggleLockOnPlayer(currentState); lastAimLockKeyState = currentState
        elseif currentMode == "Always" and not ScriptState.lockEnabled then toggleLockOnPlayer(true); lastAimLockKeyState = keyPicker:GetState()
        elseif currentMode == "Hold" and currentState then toggleLockOnPlayer(true) end
    else lastAimLockKeyState = keyPicker:GetState() end
end)

aimbox:AddSlider("Smoothing", {Text = "Camera Smoothing", Default = 0.1, Min = 0, Max = 1, Rounding = 2, Callback = function(value) ScriptState.smoothingFactor = value end})
aimbox:AddSlider("Prediction", {Text = "Prediction Factor", Default = 0.0, Min = 0, Max = 2, Rounding = 2, Callback = function(value) ScriptState.predictionFactor = value end})
aimbox:AddToggle("aimLockVisibleCheck", {Text = "Visible Check", Default = ScriptState.aimLockVisibleCheck, Callback = function(value) ScriptState.aimLockVisibleCheck = value end})
aimbox:AddToggle("aimLockAliveCheck", {Text = "Alive Check", Default = ScriptState.aimLockAliveCheck, Callback = function(value) ScriptState.aimLockAliveCheck = value end})
aimbox:AddToggle("aimLockTeamCheck", {Text = "Team Check", Default = ScriptState.aimLockTeamCheck, Callback = function(value) ScriptState.aimLockTeamCheck = value end})
aimbox:AddDropdown("BodyParts", {Values = {"Head", "UpperTorso", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm"}, Default = "Head", Multi = false, Text = "Target Body Part", Callback = function(value) ScriptState.bodyPartSelected = value end})

getgenv().ScriptState.Desync = false
RunService.Heartbeat:Connect(function()
    if getgenv().ScriptState.Desync then
        local character = LocalPlayer.Character if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart") if not root then return end
        local origVel = root.Velocity
        root.Velocity = Vector3.new(math.random(-1, 1), math.random(-1, 1), math.random(-1, 1)) * ScriptState.reverseResolveIntensity * 1000
        root.CFrame = root.CFrame * CFrame.Angles(0, math.random(-1, 1) * ScriptState.reverseResolveIntensity * 0.001, 0)
        RunService.RenderStepped:Wait()
        root.Velocity = origVel
    end
end)

velbox:AddToggle("desyncEnabled", {Text = "Desync", Default = false, Callback = function(value) getgenv().ScriptState.Desync = value end})
    :AddKeyPicker("desyncToggleKey", {Default = "None", SyncToggleState = true, Mode = "Toggle", Text = "Desync Toggle Key", Callback = function(value) getgenv().ScriptState.Desync = value end})
velbox:AddSlider("ReverseResolveIntensity", {Text = "velocity intensity", Default = 5, Min = 1, Max = 10, Rounding = 0, Callback = function(value) ScriptState.reverseResolveIntensity = value end})

RunService.RenderStepped:Connect(function()
    if ScriptState.isLockedOn and ScriptState.targetPlayer and ScriptState.targetPlayer.Character then
        local partName = getBodyPart(ScriptState.targetPlayer.Character, ScriptState.bodyPartSelected)
        local part = ScriptState.targetPlayer.Character:FindFirstChild(partName)
        if part and ScriptState.targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * ScriptState.predictionFactor)
            if ScriptState.antiLockEnabled then
                if ScriptState.resolverMethod == "Recalculate" then predictedPosition = predictedPosition + (part.AssemblyLinearVelocity * ScriptState.resolverIntensity)
                elseif ScriptState.resolverMethod == "Randomize" then predictedPosition = predictedPosition + Vector3.new(math.random()-.5, math.random()-.5, math.random()-.5)*ScriptState.resolverIntensity
                elseif ScriptState.resolverMethod == "Invert" then predictedPosition = predictedPosition - (part.AssemblyLinearVelocity * ScriptState.resolverIntensity * 2) end
            end
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, predictedPosition) * CFrame.new(0, 0, ScriptState.smoothingFactor)
        else ScriptState.isLockedOn = false; ScriptState.targetPlayer = nil end
    end
end)

aimbox:AddToggle("antiLock_Enabled", {Text = "Anti Lock Resolver", Default = false, Callback = function(value) ScriptState.antiLockEnabled = value end})
aimbox:AddSlider("ResolverIntensity", {Text = "Resolver Intensity", Default = 1.0, Min = 0, Max = 5, Rounding = 2, Callback = function(value) ScriptState.resolverIntensity = value end})
aimbox:AddDropdown("ResolverMethods", {Values = {"Recalculate", "Randomize", "Invert"}, Default = "Recalculate", Multi = false, Text = "Resolver Method", Callback = function(value) ScriptState.resolverMethod = value end})

local MainBOX = GeneralTab:AddLeftTabbox("Silent Aim")
local Main = MainBOX:AddTab("Silent Aim")
local silentAimToggle = Main:AddToggle("silentAimEnabled", {Text = "Silent Aim", Default = SilentAimSettings.Enabled, Callback = function(value) SilentAimSettings.Enabled = value end})

silentAimToggle:AddKeyPicker("silentAim_KeyPicker", {
    Default = SilentAimSettings.ToggleKey or "None", SyncToggleState = true, Mode = SilentAimSettings.KeyMode or "Toggle", Text = "Enabled", NoUI = false,
    Callback = function(state) if silentAimToggle.Value ~= state then silentAimToggle:SetValue(state) end end,
    ChangedCallback = function() SilentAimSettings.ToggleKey = Options.silentAim_KeyPicker.Value; SilentAimSettings.KeyMode = Options.silentAim_KeyPicker.Mode end
})

Main:AddToggle("TeamCheck", {Text = "Team Check", Default = SilentAimSettings.TeamCheck}):OnChanged(function() SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value end)
Main:AddToggle("VisibleCheck", {Text = "Visible Check", Default = SilentAimSettings.VisibleCheck}):OnChanged(function() SilentAimSettings.VisibleCheck = Toggles.VisibleCheck.Value end)
Main:AddToggle("AliveCheck", {Text = "Alive Check", Default = SilentAimSettings.AliveCheck}):OnChanged(function() SilentAimSettings.AliveCheck = Toggles.AliveCheck.Value end)
Main:AddToggle("BulletTP", {Text = "Bullet Teleport", Default = SilentAimSettings.BulletTP}):OnChanged(function() SilentAimSettings.BulletTP = Toggles.BulletTP.Value end)
Main:AddToggle("CheckForFireFunc", {Text = "Check For Fire Function", Default = SilentAimSettings.CheckForFireFunc}):OnChanged(function() SilentAimSettings.CheckForFireFunc = Toggles.CheckForFireFunc.Value end)
Main:AddToggle("TargetVehiclesToggle", {Text = "Target Vehicles", Default = false}):OnChanged(function() SilentAimSettings.TargetVehicles = Toggles.TargetVehiclesToggle.Value end)
Main:AddDropdown("TargetPart", {AllowNull = true, Text = "Target Part", Default = SilentAimSettings.TargetPart, Values = {"Head", "HumanoidRootPart", "Random"}}):OnChanged(function() SilentAimSettings.TargetPart = Options.TargetPart.Value end)
Main:AddDropdown("Method", {AllowNull = true, Text = "Silent Aim Method", Default = SilentAimSettings.SilentAimMethod, Values = {"ViewportPointToRay", "ScreenPointToRay", "Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "CounterBlox"}}):OnChanged(function() SilentAimSettings.SilentAimMethod = Options.Method.Value end)

SilentAimSettings.BlockedMethods = normalizeSelection(SilentAimSettings.BlockedMethods)
Main:AddDropdown("Blocked Methods", {AllowNull = true, Multi = true, Text = "Blocked Methods", Default = SilentAimSettings.BlockedMethods, Values = {"BulkMoveTo", "PivotTo", "TranslateBy", "SetPrimaryPartCFrame"}}):OnChanged(function() SilentAimSettings.BlockedMethods = normalizeSelection(Options["Blocked Methods"].Value) end)
Main:AddDropdown("Include", {AllowNull = true, Multi = true, Text = "Include", Default = SilentAimSettings.Include, Values = {"Camera", "Character"}}):OnChanged(function() SilentAimSettings.Include = normalizeSelection(Options.Include.Value) end)
Main:AddDropdown("Origin", {AllowNull = true, Multi = true, Text = "Origin", Default = SilentAimSettings.Origin, Values = {"Camera"}}):OnChanged(function() SilentAimSettings.Origin = normalizeSelection(Options.Origin.Value) end)
Main:AddSlider("MultiplyUnitBy", {Text = "Multiply Unit By", Default = SilentAimSettings.MultiplyUnitBy, Min = 1, Max = 10000, Rounding = 0}):OnChanged(function() SilentAimSettings.MultiplyUnitBy = Options.MultiplyUnitBy.Value end)
Main:AddSlider("HitChance", {Text = "Hit Chance", Default = 100, Min = 0, Max = 100, Rounding = 1}):OnChanged(function() SilentAimSettings.HitChance = Options.HitChance.Value end)

local FieldOfViewBOX = GeneralTab:AddLeftTabbox("Field Of View") do
    local Main = FieldOfViewBOX:AddTab("Visuals")
    Main:AddToggle("Visible", {Text = "Show FOV Circle"}):AddColorPicker("Color", {Default = Color3.fromRGB(54, 57, 241)}):OnChanged(function() fov_circle.Visible = Toggles.Visible.Value; SilentAimSettings.FOVVisible = Toggles.Visible.Value end)
    Main:AddSlider("Radius", {Text = "FOV Circle Radius", Min = 0, Max = 360, Default = 130, Rounding = 0}):OnChanged(function() fov_circle.Radius = Options.Radius.Value; SilentAimSettings.FOVRadius = Options.Radius.Value end)
    Main:AddDropdown("FovMode", {Values = {"Mouse", "Center"}, Default = ScriptState.fovMode, Text = "FOV Origin"}):OnChanged(function() ScriptState.fovMode = Options.FovMode.Value end)
    Main:AddToggle("MousePosition", {Text = "Show Silent Aim Target"}):AddColorPicker("MouseVisualizeColor", {Default = Color3.fromRGB(54, 57, 241)}):OnChanged(function() SilentAimSettings.ShowSilentAimTarget = Toggles.MousePosition.Value end)
    Main:AddDropdown("PlayerDropdown", {SpecialType = "Player", Text = "Ignore Player", Multi = true})
    
    Main:AddToggle("unswimToggle", {Text = "Unswim Loop", Default = false}):OnChanged(function()
        ScriptState.unswimEnabled = Toggles.unswimToggle.Value
        if not ScriptState.unswimEnabled then
            pcall(function()
                local character = LocalPlayer.Character
                if character then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                    end
                end
            end)
        end
    end)
end

task.spawn(function()
    while true do
        if ScriptState.unswimEnabled then
            pcall(function()
                local character = LocalPlayer.Character
                if character then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
                        humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end)
        end
        task.wait(0.01)
    end
end)

local function removeOldHighlight() if ScriptState.previousHighlight then ScriptState.previousHighlight:Destroy(); ScriptState.previousHighlight = nil end end

task.spawn(function()
    RenderStepped:Connect(function()
        if Toggles.MousePosition.Value then
            local closestPart, closestPlayer = getClosestPlayer({visibleCheck = SilentAimSettings.VisibleCheck or ScriptState.aimLockVisibleCheck, teamCheck = SilentAimSettings.TeamCheck or ScriptState.aimLockTeamCheck, aliveCheck = SilentAimSettings.AliveCheck or ScriptState.aimLockAliveCheck})
            if closestPart and closestPlayer then
                local char = closestPlayer.Character or closestPlayer
                if char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Body") or char:FindFirstChild("Functionality")) then
                    local root = char:FindFirstChild("HumanoidRootPart") or closestPart
                    local _, IsOnScreen = WorldToViewportPoint(Camera, root.Position)
                    removeOldHighlight()
                    if IsOnScreen then
                        local highlight = char:FindFirstChildOfClass("Highlight") or Instance.new("Highlight", char)
                        highlight.Adornee = char; highlight.FillColor = Options.MouseVisualizeColor.Value; highlight.FillTransparency = 0.5; highlight.OutlineColor = Options.MouseVisualizeColor.Value; highlight.OutlineTransparency = 0
                        ScriptState.previousHighlight = highlight
                    end
                end
            else removeOldHighlight() end
        end
        if Toggles.Visible.Value then fov_circle.Visible = true; fov_circle.Color = Options.Color.Value; fov_circle.Position = getFovOrigin() end
    end)
end)

local sounds = { ["RIFK7"] = "rbxassetid://9102080552", ["Bubble"] = "rbxassetid://9102092728", ["Minecraft"] = "rbxassetid://5869422451", ["Cod"] = "rbxassetid://160432334", ["Bameware"] = "rbxassetid://6565367558", ["Neverlose"] = "rbxassetid://6565370984", ["Gamesense"] = "rbxassetid://4817809188", ["Rust"] = "rbxassetid://6565371338" }
local hitSound = Instance.new("Sound", SoundService) hitSound.Volume = 3

local HitSoundBox = GeneralTab:AddRightTabbox("HitSound") do
    local Main = HitSoundBox:AddTab("HitSound [beta]")
    Main:AddToggle("HitSoundEnabled", {Text = "Enable HitSound", Default = false})
    Main:AddDropdown("HitSoundSelect", {Values = {"RIFK7","Bubble","Minecraft","Cod","Bameware","Neverlose","Gamesense","Rust"}, Default = "Neverlose", Text = "HitSound"}):OnChanged(function() hitSound.SoundId = sounds[Options.HitSoundSelect.Value] end)
end
hitSound.SoundId = sounds[Options.HitSoundSelect.Value]

local soundPool, soundIndex = {}, 1
local function getNextSound()
    if soundIndex > #soundPool then local s = hitSound:Clone() s.Parent = workspace; table.insert(soundPool, s) end
    local s = soundPool[soundIndex]; soundIndex = soundIndex + 1; return s
end

local function trackPlayer(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 10) if not hum then return end
        local lastHealth = hum.Health
        hum.HealthChanged:Connect(function(newHp)
            if Toggles.HitSoundEnabled.Value then
                local _, closestPlayer = getClosestPlayer()
                if closestPlayer == plr and (newHp < lastHealth or (lastHealth > 0 and newHp <= 0)) then
                    local s = getNextSound() s:Stop(); s:Play()
                end
            end
            lastHealth = newHp
        end)
    end)
end
for _, plr in ipairs(Players:GetPlayers()) do trackPlayer(plr) end
Players.PlayerAdded:Connect(trackPlayer)

RunService.Heartbeat:Connect(function()
    ScriptState.ClosestHitPart = (Toggles.silentAimEnabled and Toggles.silentAimEnabled.Value) and getClosestPlayer() or nil
end)

local function updateFireMode(tool)
    if tool:IsA("Tool") then
        pcall(function()
            tool:SetAttribute("Ammo", math.huge)
            if tool:GetAttribute("FireMode") then tool:SetAttribute("FireMode", "Auto") end
            if tool:GetAttribute("Mode") then tool:SetAttribute("Mode", "Auto") end
            local config = tool:FindFirstChild("Configuration") or tool:FindFirstChild("Settings")
            if config then
                local mode = config:FindFirstChild("FireMode") or config:FindFirstChild("Mode")
                if mode and (mode:IsA("StringValue") or mode:IsA("ValueObject")) then mode.Value = "Auto" end
            end
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    char.ChildAdded:Connect(updateFireMode)
end)
if LocalPlayer.Character then
    LocalPlayer.Character.ChildAdded:Connect(updateFireMode)
    for _, child in next, LocalPlayer.Character:GetChildren() do updateFireMode(child) end
end
local backpack = LocalPlayer:WaitForChild("Backpack", 5)
if backpack then
    backpack.ChildAdded:Connect(updateFireMode)
    for _, child in next, backpack:GetChildren() do updateFireMode(child) end
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method, Arguments = getnamecallmethod(), {...}
    local self, chance = Arguments[1], CalculateChance(SilentAimSettings.HitChance)
    if Method == "Destroy" and self == Client then return end
    if SilentAimSettings.BlockedMethods[Method] then return end

    local function computeRay(origin, HitPart)
        local adjustedOrigin = SilentAimSettings.BulletTP and (HitPart.CFrame * CFrame.new(0, 0, 1)).p or origin
        return adjustedOrigin, getDirection(adjustedOrigin, HitPart.Position) * (SilentAimSettings.MultiplyUnitBy or 1000)
    end

    if Toggles.silentAimEnabled and Toggles.silentAimEnabled.Value and self == workspace and not checkcaller() and chance then
        local HitPart = ScriptState.ClosestHitPart or getClosestPlayer()
        if HitPart then
            if Method == "Raycast" and SilentAimSettings.SilentAimMethod == Method then
                if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
                    local Origin, Direction = computeRay(Arguments[2], HitPart)
                    Arguments[2], Arguments[3] = Origin, Direction; return oldNamecall(unpack(Arguments))
                end
            elseif Method == "FindPartOnRayWithIgnoreList" and SilentAimSettings.SilentAimMethod == Method then
                if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                    local Origin, Direction = computeRay(Arguments[2].Origin, HitPart)
                    Arguments[2] = Ray.new(Origin, Direction); return oldNamecall(unpack(Arguments))
                end
            end
        end
    end
    return oldNamecall(...)
end))

if not _G.ExunysESPLoaded then
    loadstring(game:HttpGet(getMainUrl("ExLib.lua")))()
end

local ESP = getgenv().ExunysDeveloperESP
if not ESP then return end

local function ensurePath(path)
    local ref = ESP for index = 1, #path - 1 do local key = path[index] if type(ref[key]) ~= "table" then ref[key] = {} end ref = ref[key] end
    return ref, path[#path]
end
local function getProperty(path) local ref = ESP for index = 1, #path do if not ref then return nil end ref = ref[path[index]] end return ref end
local function updateProperty(path, value) local ref, key = ensurePath(path) if ref and key then ref[key] = value end end

local VisualsEx = VisualsTab:AddLeftGroupbox("ESP Settings")
VisualsEx:AddToggle("espEnabled", { Text = "Enable ESP", Default = ESP.Settings and ESP.Settings.Enabled or false, Callback = function(value) if value and ESP and not ESP.Loaded and ESP.Load then pcall(function() ESP:Load() end) end; updateProperty({"Settings", "Enabled"}, value); if ESP.UpdateConfiguration then ESP.UpdateConfiguration(ESP.DeveloperSettings, ESP.Settings, ESP.Properties) end end })

local worldbox = VisualsTab:AddRightGroupbox("World")
local lighting = Services.Lighting
ScriptState.lockedTime, ScriptState.fovValue, ScriptState.nebulaEnabled = 12, 70, false
local originalAmbient, originalOutdoorAmbient = lighting.Ambient, lighting.OutdoorAmbient

worldbox:AddSlider("world_time", {Text = "Clock Time", Default = 12, Min = 0, Max = 24, Rounding = 1, Callback = function(v) ScriptState.lockedTime = v; if ScriptState.lockTimeEnabled then lighting.ClockTime = v end end})
worldbox:AddToggle("lock_time_toggle", {Text = "Lock Time", Default = false, Callback = function(v) ScriptState.lockTimeEnabled = v; if v then lighting.ClockTime = ScriptState.lockedTime end end})

task.spawn(function()
    while true do
        task.wait()
        if ScriptState.isSpeedActive or ScriptState.isFlyActive or ScriptState.isNoClipActive then
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local humanoid = character:FindFirstChild("Humanoid")
                if ScriptState.isSpeedActive and humanoid and humanoid.MoveDirection.Magnitude > 0 then
                    rootPart.CFrame = rootPart.CFrame + humanoid.MoveDirection.Unit * ScriptState.Cmultiplier
                end
                if ScriptState.isFlyActive then
                    local flyDir = Vector3.zero
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then flyDir = flyDir + Camera.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then flyDir = flyDir - Camera.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then flyDir = flyDir - Camera.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then flyDir = flyDir - Camera.CFrame.RightVector end
                    if flyDir.Magnitude > 0 then rootPart.CFrame = CFrame.new(rootPart.Position + flyDir.Unit * ScriptState.flySpeed) end
                    rootPart.Velocity = Vector3.zero
                end
            end
        end
    end
end)

ThemeManager:LoadDefaultTheme()
