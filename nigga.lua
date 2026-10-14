local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

print("▶ PC/모바일 입력 포커스 및 컨트롤러 강제 동기화 패치 시작...")

-- 1. PC 마우스 커서 및 입력 포커스 강제 해제 (UI가 입력을 가로채지 못하도록 차단)
UserInputService.ModalEnabled = false
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
task.wait(0.1)
UserInputService.MouseBehavior = Enum.MouseBehavior.Default

-- 2. 로블록스 플레이어 컨트롤러 강제 활성화 (WASD 입력 복구)
pcall(function()
    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    if playerScripts then
        local controls = playerScripts:FindFirstChild("PlayerModule")
        if controls then
            require(controls):GetControls():Enable()
        end
    end
end)

-- 3. 잔존 로비 GUI 완전 제거 및 비활성화 함수
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

-- 4. 메인 루프 (PC/모바일 공통 적용)
RunService.RenderStepped:Connect(function()
    local character = LocalPlayer.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not rootPart or not humanoid or humanoid.Health <= 0 then return end

    -- 캐릭터 앵커 해제
    if rootPart.Anchored then
        rootPart.Anchored = false
    end

    -- PC에서 입력이 씹히는 것을 방지하기 위해 휴마노이드 상태 강제 유지
    humanoid.PlatformStand = false

    -- 카메라가 공중으로 이탈하는 것을 막고 캐릭터를 정확히 추적하도록 고정
    if Camera.CameraSubject ~= humanoid or Camera.CameraType ~= Enum.CameraType.Custom then
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = humanoid
        Camera.FieldOfView = 70
    end
    
    hideLobbyUI()
end)

print("▶ 패치 적용 완료! PC에서도 입력 포커스가 풀리며 캐릭터와 카메라가 함께 움직입니다.")
