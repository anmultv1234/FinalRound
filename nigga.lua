local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

print("▶ 카메라 간섭 제거 버전 패치 실행 중...")

-- 1. 로비 UI 숨기기 함수
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

-- 2. 메인 루프 (카메라 코드는 완전히 제외하고 앵커와 무기만 제어)
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

    -- 백팩에 있는 무기를 자동으로 손에 장착
    if not character:FindFirstChildOfClass("Tool") then
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                pcall(function()
                    humanoid:EquipTool(tool)
                end)
            end
        end
    end
    
    -- 로비 UI 숨기기
    hideLobbyUI()
end)

-- 캐릭터 리스폰 대응
LocalPlayer.CharacterAdded:Connect(function(newChar)
    newChar:WaitForChild("Humanoid")
    task.wait(0.5)
end)

print("▶ 패치 완료! 카메라 튀 현상 없이 이동과 무기 장착이 가능합니다.")
