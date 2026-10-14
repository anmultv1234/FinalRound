local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

print("▶ PC/모바일 카메라-캐릭터 동기화 패치 실행...")

-- 1. 팀 스푸핑 설정 (ACS_CLIENT 속이기)
local targetTeamName = "DefaultTeam"
pcall(function()
    local tycoons = workspace:WaitForChild("Tycoon", 2):WaitForChild("Tycoons", 2)
    for _, tycoon in ipairs(tycoons:GetChildren()) do
        if tycoon:IsA("Model") or tycoon:IsA("Folder") then
            targetTeamName = tycoon.Name
            break
        end
    end
end)

local fakeTeam = setmetatable({
    Name = targetTeamName
}, {
    __index = function(t, k)
        if k == "Name" then return targetTeamName end
        return rawget(t, k)
    end
})

local mt = getrawmetatable(LocalPlayer)
if mt then
    setreadonly(mt, false)
    local oldIndex = mt.__index
    mt.__index = function(self, key)
        if self == LocalPlayer and key == "Team" then
            return fakeTeam
        end
        if type(oldIndex) == "function" then
            return oldIndex(self, key)
        elseif type(oldIndex) == "table" then
            return oldIndex[key]
        end
        return nil
    end
    setreadonly(mt, true)
end

-- 2. PC 입력 포커스 해제
UserInputService.ModalEnabled = false
UserInputService.MouseBehavior = Enum.MouseBehavior.Default
LocalPlayer.CameraMode = Enum.CameraMode.Classic

-- 3. 로비 UI 숨기기
local function hideLobbyUI()
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("ScreenGui") or gui:IsA("Frame") or gui:IsA("CanvasGroup") then
            local nameLower = gui.Name:lower()
            if nameLower:find("loading") or nameLower:find("menu") or nameLower:find("container") or nameLower:find("tycoon") or nameLower:find("hud") then
                pcall(function()
                    gui.Visible = false
                    if gui:IsA("ScreenGui") then
                        gui.Enabled = false
                    end
                end)
            end
        end
    end
end

-- 4. 메인 루프 (PC 카메라 이탈 방지 및 캐릭터 물리 강제 동기화)
RunService.RenderStepped:Connect(function()
    local character = LocalPlayer.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if rootPart and rootPart.Anchored then
        rootPart.Anchored = false
    end
    
    if not humanoid or humanoid.Health <= 0 then return end

    -- [핵심] PC에서 카메라가 캐릭터를 놓치고 분리되는 현상을 막기 위해 강제 바인딩
    if Camera.CameraSubject ~= humanoid or Camera.CameraType ~= Enum.CameraType.Custom then
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = humanoid
        Camera.FieldOfView = 70
    end

    -- 캐릭터가 카메라 방향을 바라보도록 입력 연동 보장
    pcall(function()
        LocalPlayer.ReplicationFocus = rootPart
    end)
    
    hideLobbyUI()
end)

print("▶ 패치 적용 완료! 카메라와 캐릭터가 함께 정상 연동됩니다.")
