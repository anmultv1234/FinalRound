local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

print("▶ PC/모바일 통합 팀 스푸핑 및 캐릭터 분리 패치 실행...")

-- 1. 워타이쿤 서버 내 실제 존재하는 유효한 기지 팀 이름 자동 탐색
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

-- 2. 가짜 팀 객체 생성
local fakeTeam = setmetatable({
    Name = targetTeamName
}, {
    __index = function(t, k)
        if k == "Name" then
            return targetTeamName
        end
        return rawget(t, k)
    end
})

-- 3. ACS_CLIENT가 실행되기 전(또는 즉시) LocalPlayer.Team 후킹 가로채기
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

-- 4. PC 입력 포커스 및 마우스 제어 해제
UserInputService.ModalEnabled = false
UserInputService.MouseBehavior = Enum.MouseBehavior.Default

-- 5. 잔존 로비 GUI 완전 제거 함수
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

-- 6. 메인 루프 (캐릭터 앵커 해제 및 카메라 Subject를 캐릭터 휴마노이드로 강제 고정)
RunService.RenderStepped:Connect(function()
    local character = LocalPlayer.Character
    if not character then return end
    
    -- 캐릭터 고정(앵커) 해제
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart and rootPart.Anchored then
        rootPart.Anchored = false
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- PC에서 카메라가 캐릭터를 벗어나 다른 곳을 보는 현상 방지
    if Camera.CameraSubject ~= humanoid or Camera.CameraType ~= Enum.CameraType.Custom then
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = humanoid
        Camera.FieldOfView = 70
    end
    
    hideLobbyUI()
end)

print("▶ 패치 완료! PC와 모바일 모두 정상적으로 캐릭터가 분리되고 무기를 사용할 수 있습니다.")
