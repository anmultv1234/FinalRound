local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

print("▶ PC/모바일 통합 완벽 호환 패치 실행 중...")

-- 1. 서버에 실제로 존재하는 유효한 기지(Tycoon) 이름을 정확히 탐색 (에러 방지 핵심)
local realTycoonName = "Loading"
pcall(function()
    local tycoonsFolder = workspace:WaitForChild("Tycoon", 3):WaitForChild("Tycoons", 3)
    for _, tycoon in ipairs(tycoonsFolder:GetChildren()) do
        if tycoon.Name ~= "Loading" then
            realTycoonName = tycoon.Name
            break
        end
    end
end)

-- 2. ACS_CLIENT가 에러 없이 인식할 수 있는 정교한 가짜 팀 객체 생성
local fakeTeam = setmetatable({
    Name = realTycoonName
}, {
    __index = function(t, k)
        if k == "Name" then
            return realTycoonName
        end
        return rawget(t, k)
    end
})

-- 3. 메타메소드 후킹으로 LocalPlayer.Team 완벽 속이기
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
    print("▶ 팀 스푸핑 성공, 인식된 기지/팀:", realTycoonName)
end

-- 4. PC 입력 포커스 및 마우스 잠금 해제
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

-- 6. 메인 루프 (앵커 해제, 카메라 Subject 강제 고정, GUI 숨김)
RunService.RenderStepped:Connect(function()
    local character = LocalPlayer.Character
    if not character then return end
    
    -- 캐릭터 앵커(고정) 해제
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart and rootPart.Anchored then
        rootPart.Anchored = false
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- PC와 모바일 모두 카메라가 캐릭터를 정확히 바라보도록 강제 동기화
    if Camera.CameraSubject ~= humanoid or Camera.CameraType ~= Enum.CameraType.Custom then
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = humanoid
        Camera.FieldOfView = 70
    end
    
    hideLobbyUI()
end)

print("▶ 패치 완료! PC와 모바일 모두 정상적으로 동작합니다.")
