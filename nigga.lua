local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

print("▶ War Tycoon 카메라 떨림 수정 패치 실행 중...")

-- 1. 로비 UI(War Tycoon 로고 및 기지 선택 메뉴) 숨기기 함수
local function hideLobbyUI()
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("ScreenGui") or gui:IsA("Frame") then
            if gui.Name == "Menu" or gui.Name == "HUD" or gui.Name == "Container" or gui.Name:lower():find("tycoon") then
                pcall(function()
                    if gui:FindFirstChild("Quick Play") or gui:FindFirstChild("빠른플레이") or gui:FindFirstChild("기지 선택") or gui.Name == "Menu" then
                        gui.Visible = false
                    end
                end)
            end
        end
    end
    pcall(function()
        local mainUI = PlayerGui:FindFirstChild("UI", true)
        if mainUI and mainUI:FindFirstChild("Container") then
            local menu = mainUI.Container:FindFirstChild("Menu")
            if menu then menu.Visible = false end
        end
    end)
end

-- 2. 카메라 초기 설정 (한 번만 실행하여 떨림 방지)
local function initCamera(humanoid)
    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = humanoid
    Camera.FieldOfView = 70
end

-- 3. 메인 루프 (캐릭터 고정 해제 및 무기 강제 장착만 담당)
RunService.RenderStepped:Connect(function()
    local character = LocalPlayer.Character
    if not character then return end
    
    -- 캐릭터 앵커(고정) 강제 해제 (즉시 이동 가능)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart and rootPart.Anchored then
        rootPart.Anchored = false
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- 카메라 타입이 풀려있거나 대상이 다를 때만 안전하게 설정 (떨림 현상 원인 제거)
    if Camera.CameraType ~= Enum.CameraType.Custom or Camera.CameraSubject ~= humanoid then
        initCamera(humanoid)
    end

    -- Loading 팀 제어로 인해 손에서 빠진 무기(Tool)가 백팩에 있다면 자동으로 손에 장착
    if not character:FindFirstChildOfClass("Tool") then
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                pcall(function()
                    humanoid:EquipTool(tool)
                end)
            end
        end
    end
    
    -- 주기적으로 로비 UI 숨기기 시도
    hideLobbyUI()
end)

-- 캐릭터 리스폰 대응
LocalPlayer.CharacterAdded:Connect(function(newChar)
    local humanoid = newChar:WaitForChild("Humanoid")
    task.wait(0.5)
    initCamera(humanoid)
end)

print("▶ 패치 완료! 카메라 떨림이 해결되었습니다.")
