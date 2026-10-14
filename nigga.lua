local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

print("▶ PC/모바일 컨트롤러 및 물리 강제 해제 패치 실행...")

-- 1. PC 입력 마우스/키보드 포커스 강제 해제 (컨트롤러 활성화)
UserInputService.ModalEnabled = false
UserInputService.MouseBehavior = Enum.MouseBehavior.Default

-- 2. 로블록스 기본 플레이어 컨트롤러(PlayerModule) 강제 활성화 유도
pcall(function()
    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    if playerScripts then
        local playerModule = playerScripts:FindFirstChild("PlayerModule")
        if playerModule then
            require(playerModule):GetControls():Enable()
        end
    end
end)

-- 3. 잔존 로비 GUI 완전 제거
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

-- 4. 메인 루프 (캐릭터 앵커 해제, 물리 속도 초기화, 카메라 및 입력 제어 강제 고정)
RunService.RenderStepped:Connect(function()
    local character = LocalPlayer.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not rootPart or not humanoid or humanoid.Health <= 0 then return end

    -- [핵심] 캐릭터 고정(앵커)을 매 프레임 강제로 풀어버림
    if rootPart.Anchored then
        rootPart.Anchored = false
    end

    -- PC에서 키보드 입력(WASD)이 캐릭터 이동으로 직결되도록 휴마노이드 상태 강제 갱신
    humanoid.PlatformStand = false
    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

    -- 카메라가 캐릭터를 정확히 잡도록 설정
    if Camera.CameraSubject ~= humanoid or Camera.CameraType ~= Enum.CameraType.Custom then
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = humanoid
        Camera.FieldOfView = 70
    end
    
    hideLobbyUI()
end)

print("▶ 패치 완료! PC에서도 모바일처럼 캐릭터가 즉시 분리되어 이동할 수 있습니다.")
