local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

print("▶ 클라이언트 팀 스푸핑(Team Spoofing) 패치 실행 중...")

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

-- 2. ACS_CLIENT가 참조하는 LocalPlayer.Team을 속이기 위한 가짜 팀(Proxy) 객체 생성
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

-- 3. LocalPlayer 메타메소드 후킹 (클라이언트 전용 팀 속이기)
local mt = getrawmetatable(LocalPlayer)
if mt then
    setreadonly(mt, false)
    local oldIndex = mt.__index
    mt.__index = function(self, key)
        if self == LocalPlayer and key == "Team" then
            return fakeTeam -- ACS_CLIENT가 Team을 조회할 때 가짜 팀 반환
        end
        if type(oldIndex) == "function" then
            return oldIndex(self, key)
        elseif type(oldIndex) == "table" then
            return oldIndex[key]
        end
        return nil
    end
    setreadonly(mt, true)
    print("▶ 팀 스푸핑 후킹 완료! 인식된 팀:", targetTeamName)
end

-- 4. PC 입력 포커스 및 잔존 로비 GUI 제거
UserInputService.ModalEnabled = false
UserInputService.MouseBehavior = Enum.MouseBehavior.Default

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

-- 5. 캐릭터 앵커 해제 및 시점 안정화 루프
RunService.RenderStepped:Connect(function()
    local character = LocalPlayer.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart and rootPart.Anchored then
        rootPart.Anchored = false
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    if Camera.CameraType == Enum.CameraType.Scriptable or Camera.CameraType == Enum.CameraType.Attach then
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = humanoid
    end
    
    hideLobbyUI()
end)

print("▶ 모든 패치 완료! 이제 무기를 정상적으로 장착하고 사용할 수 있습니다.")
