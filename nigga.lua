local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

print("▶ War Tycoon Loading 팀 및 잔존 GUI 완전 우회 패치 실행 중...")

-- 1. PC 마우스 잠금 및 모달 포커스 해제 (화면 전환 가능하도록)
UserInputService.ModalEnabled = false
UserInputService.MouseBehavior = Enum.MouseBehavior.Default

-- 2. 잔존 로비 GUI 및 UIBlox Loading 컨테이너 강제 비활성화 함수
local function hideAllLoadingElements()
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("ScreenGui") or gui:IsA("Frame") or gui:IsA("CanvasGroup") then
            local nameLower = gui.Name:lower()
            -- 메뉴, 로딩, 컨테이너, 빠른 플레이, 기지 선택 관련 모든 요소 강제 숨김 및 무력화
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
    
    -- UIBlox LoadingStateContainer 관련 잔존 프레임 직접 타겟팅 숨김
    pcall(function()
        local mainUI = PlayerGui:FindFirstChild("UI", true)
        if mainUI then
            local container = mainUI:FindFirstChild("Container")
            if container then
                container.Visible = false
            end
        end
    end)
end

-- 3. 카메라 강제 전환 (시점 풀기)
local function forceNormalCamera(humanoid)
    if humanoid then
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = humanoid
        Camera.FieldOfView = 70
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
    end
end

-- 4. 메인 루프 (앵커 해제, 무기 강제 장착, 잔존 GUI 차단)
RunService.RenderStepped:Connect(function()
    local character = LocalPlayer.Character
    if not character then return end
    
    -- 캐릭터 앵커(고정) 해제 (즉시 이동 가능)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart and rootPart.Anchored then
        rootPart.Anchored = false
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- 카메라 타입이 Scriptable로 묶이는 것 방지
    if Camera.CameraType == Enum.CameraType.Scriptable or Camera.CameraType == Enum.CameraType.Attach then
        forceNormalCamera(humanoid)
    end

    -- 백팩에 있는 무기(Tool)를 강제로 손에 쥐여주기 (총 들기 불가 현상 해결)
    if not character:FindFirstChildOfClass("Tool") then
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                pcall(function()
                    humanoid:EquipTool(tool)
                end)
            end
        end
    end
    
    -- 잔존 GUI 및 로딩 컨테이너 주기적 제거
    hideAllLoadingElements()
end)

-- 캐릭터 리스폰 대응
LocalPlayer.CharacterAdded:Connect(function(newChar)
    local humanoid = newChar:WaitForChild("Humanoid")
    task.wait(0.3)
    forceNormalCamera(humanoid)
end)

print("▶ 패치 완료! 잔존 GUI가 제거되고 시점 전환 및 무기 장착이 가능합니다.")
