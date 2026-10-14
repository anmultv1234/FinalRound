-- ACS Framework Compatible Exploit GUI (v2)
-- War Tycoon (ACS) — verified against recovered BSMT script (remote names/payload keys)
--
-- 변경점 (v1 대비):
--  * Service 미정의 버그 수정
--  * 로켓 페이로드를 실제 스크립트와 동일하게: Origin/Direction/Settings/RocketModel/
--    Vehicle/Weapon/PlrFired/Label/Target  +  FireRocketBindable:Fire(LocalPlayer, payload)
--  * RocketModel 경로 수정: RocketSystem.Rockets 에서 "<무기이름> G-Rocket" 검색
--  * Gun Mods: 개별 토글 6종 + 원본값 저장/복원, 장착 중인 총에도 즉시 적용
--  * 모든 토글이 getgenv() 키도 함께 세팅 (BSMT 스크립트가 로드되어 있으면 연동)
--  * Kill Aura / 이동기(Fly, Noclip, Inf Jump, WalkSpeed) 추가
--  * UI: UIListLayout 자동 정렬, 토글 상태 표시, 우측 Ctrl 로 GUI 숨김/표시

local CoreGui           = game:GetService("CoreGui")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer

-- 재실행 시 이전 GUI 정리
if CoreGui:FindFirstChild("ACS_ExploitGUI") then
	CoreGui.ACS_ExploitGUI:Destroy()
end

----------------------------------------------------------------
-- BSMT 호환: 기능 토글 시 getgenv() 키도 함께 갱신
-- (recovered_full.lua 스크립트가 함께 실행 중이면 그 쪽 루프가 이 키를 읽음)
----------------------------------------------------------------
local function syncEnv(key, value)
	pcall(function()
		getgenv()[key] = value
	end)
end

----------------------------------------------------------------
-- GUI 골격
----------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ACS_ExploitGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -230)
MainFrame.Size = UDim2.new(0, 320, 0, 460)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.BorderSizePixel = 0

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Title.Size = UDim2.new(1, 0, 0, 36)
Title.Font = Enum.Font.GothamBold
Title.Text = "ACS Framework Exploit Panel"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.BorderSizePixel = 0

local Hint = Instance.new("TextLabel")
Hint.Parent = MainFrame
Hint.BackgroundTransparency = 1
Hint.Position = UDim2.new(0, 0, 1, -18)
Hint.Size = UDim2.new(1, 0, 0, 18)
Hint.Font = Enum.Font.Gotham
Hint.Text = "RightCtrl = GUI 숨김/표시"
Hint.TextColor3 = Color3.fromRGB(160, 160, 160)
Hint.TextSize = 11

local Scroll = Instance.new("ScrollingFrame")
Scroll.Parent = MainFrame
Scroll.BackgroundTransparency = 1
Scroll.Position = UDim2.new(0, 8, 0, 42)
Scroll.Size = UDim2.new(1, -16, 1, -56)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ScrollBarThickness = 6

local ListLayout = Instance.new("UIListLayout")
ListLayout.Parent = Scroll
ListLayout.Padding = UDim.new(0, 6)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local SectionOrder = 0
local function addSectionLabel(text)
	SectionOrder = SectionOrder + 1
	local lbl = Instance.new("TextLabel")
	lbl.Parent = Scroll
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(120, 190, 255)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextSize = 13
	lbl.LayoutOrder = SectionOrder
end

local ToggleOrder = 0
local function addToggle(text, onSet)
	ToggleOrder = ToggleOrder + 1
	local btn = Instance.new("TextButton")
	btn.Parent = Scroll
	btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	btn.Size = UDim2.new(1, 0, 0, 30)
	btn.Font = Enum.Font.Gotham
	btn.Text = text .. ": OFF"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 12
	btn.BorderSizePixel = 0
	btn.LayoutOrder = SectionOrder * 1000 + ToggleOrder

	local state = false
	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.BackgroundColor3 = state and Color3.fromRGB(0, 160, 80) or Color3.fromRGB(60, 60, 60)
		btn.Text = text .. (state and ": ON" or ": OFF")
		task.spawn(onSet, state)
	end)
	return btn
end

----------------------------------------------------------------
-- 공용 헬퍼
----------------------------------------------------------------
local function getChar()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return char, hum, root
end

local function getEquippedTool()
	local char = getChar()
	return char and char:FindFirstChildOfClass("Tool")
end

-- RocketSystem 캐시
local RocketSystem = ReplicatedStorage:WaitForChild("RocketSystem", 10)
local RocketEvents = RocketSystem and RocketSystem:WaitForChild("Events", 10)
local FireBindable = RocketEvents and RocketEvents:WaitForChild("FireRocketBindable", 10)
local RocketsFolder = RocketSystem and RocketSystem:FindFirstChild("Rockets")

-- 실제 스크립트와 동일한 로켓 모델 검색: "<무기이름> G-Rocket"
local function getRocketModel(tool)
	if not RocketsFolder then return nil end
	local model = RocketsFolder:FindFirstChild(tool.Name .. " G-Rocket")
	if not model and tool.Name == "RPG" then
		model = RocketsFolder:FindFirstChild("RPG Rocket") or RocketsFolder:FindFirstChild("RPG G-Rocket")
	end
	return model
end

local rocketCounter = 0
local function fireRocket(tool, origin, direction, target)
	if not FireBindable or not tool then return false end
	local ok, settings = pcall(require, tool:FindFirstChild("RocketSettings") or tool:WaitForChild("RocketSettings", 5))
	if not ok or not settings then return false end
	rocketCounter = rocketCounter + 1
	local payload = {
		Origin      = origin,
		Direction   = direction,
		Settings    = settings,
		RocketModel = getRocketModel(tool),
		Vehicle     = tool,
		Weapon      = tool,
		PlrFired    = LocalPlayer,
		Label       = LocalPlayer.Name .. "Rocket" .. rocketCounter, -- 실제 스크립트와 동일한 라벨 규칙
		Target      = target,
	}
	return pcall(function()
		FireBindable:Fire(LocalPlayer, payload)
	end)
end

----------------------------------------------------------------
-- [1] Gun Mods — ACS 설정 모듈 변조 (원본 백업/복원 지원)
-- ACS는 장착 시 설정 모듈을 require 해 재사용하므로, 모듈 테이블을
-- 패치하면 이후 장착되는 총기에도 적용된다.
----------------------------------------------------------------
local GUN_KEYS = { "VRecoil", "HRecoil", "MinSpread", "MaxSpread", "FireRate", "Mode", "Ammo" }
local gunOrig = {}

local function collectGunSettings()
	local out = {}
	local acsGuns = ReplicatedStorage:FindFirstChild("Configurations")
		 and ReplicatedStorage.Configurations:FindFirstChild("ACS_Guns")
	if not acsGuns then return out end
	for _, folder in ipairs(acsGuns:GetChildren()) do
		local mod = folder:FindFirstChild("Settings") or folder:FindFirstChildOfClass("ModuleScript")
		if mod then
			local ok, settings = pcall(require, mod)
			if ok and type(settings) == "table" then
				table.insert(out, settings)
			end
		end
	end
	return out
end

local function patchGuns(field, value)
	for _, settings in ipairs(collectGunSettings()) do
		if settings[field] ~= nil then
			if gunOrig[settings] == nil then
				gunOrig[settings] = {}
				for _, k in ipairs(GUN_KEYS) do
					if type(settings[k]) == "table" then
						gunOrig[settings][k] = { table.unpack(settings[k]) }
					else
						gunOrig[settings][k] = settings[k]
					end
				end
			end
			if type(settings[field]) == "table" and type(value) == "table" then
				settings[field][1], settings[field][2] = value[1], value[2]
			else
				settings[field] = value
			end
		end
	end
	-- 장착 중인 툴에도 즉시 반영 (모듈 캐시가 재생성된 경우 대비)
	local tool = getEquippedTool()
	local mod = tool and (tool:FindFirstChild("Settings") or tool:FindFirstChildOfClass("ModuleScript"))
	if mod then
		local ok, settings = pcall(require, mod)
		if ok and type(settings) == "table" and settings[field] ~= nil then
			if type(settings[field]) == "table" and type(value) == "table" then
				settings[field][1], settings[field][2] = value[1], value[2]
			else
				settings[field] = value
			end
		end
	end
end

local function restoreGuns()
	for settings, orig in pairs(gunOrig) do
		for k, v in pairs(orig) do
			if type(v) == "table" and type(settings[k]) == "table" then
				settings[k][1], settings[k][2] = v[1], v[2]
			elseif type(v) == "table" then
				settings[k] = { v[1], v[2] }
			else
				settings[k] = v
			end
		end
	end
	gunOrig = {}
end

-- 개별 토글이 켜질 때마다 전체 상태를 다시 계산해 적용
local gunState = { norecoil = false, nospread = false, infammo = false, fullauto = false, firerate = false }
local function applyGunState()
	if not (gunState.norecoil or gunState.nospread or gunState.infammo
		or gunState.fullauto or gunState.firerate) then
		restoreGuns()
		return
	end
	if gunState.norecoil then
		patchGuns("VRecoil", { 0, 0 })
		patchGuns("HRecoil", { 0, 0 })
	end
	if gunState.nospread then
		patchGuns("MinSpread", 0)
		patchGuns("MaxSpread", 0)
	end
	if gunState.fullauto then
		patchGuns("Mode", "Auto")
	end
	if gunState.firerate then
		patchGuns("FireRate", 1200)
	end
	if gunState.infammo then
		-- ACS는 탄약을 NumberValue("ammo")로 관리 → 값 고정
		local tool = getEquippedTool()
		local ammoVal = tool and tool:FindFirstChild("ammo")
		if ammoVal then ammoVal.Value = 600 end -- 실제 스크립트가 쓰는 값
	end
end

addSectionLabel("== Gun Mods ==")
addToggle("No Recoil", function(s)
	gunState.norecoil = s
	syncEnv("gm_norecoil", s)
	applyGunState()
end)
addToggle("No Spread", function(s)
	gunState.nospread = s
	syncEnv("gm_nospread", s)
	applyGunState()
end)
addToggle("Infinite Ammo", function(s)
	gunState.infammo = s
	syncEnv("gm_infammo", s)
	applyGunState()
end)
addToggle("Full Auto", function(s)
	gunState.fullauto = s
	syncEnv("gm_fullauto", s)
	applyGunState()
end)
addToggle("High Fire Rate", function(s)
	gunState.firerate = s
	syncEnv("gm_firerate", s)
	applyGunState()
end)

----------------------------------------------------------------
-- [2] RPG / Rocket 메뉴 — 실제 FireRocketBindable 경로 사용
----------------------------------------------------------------
local rocketSpamConn
addSectionLabel("== RPG / Rockets ==")
addToggle("Rocket Spam", function(s)
	syncEnv("spamrockets", s)
	if rocketSpamConn then rocketSpamConn:Disconnect(); rocketSpamConn = nil end
	if s then
		rocketSpamConn = RunService.Heartbeat:Connect(function()
			local tool = getEquippedTool()
			if tool and tool:FindFirstChild("RocketSettings") then
				local char, _, root = getChar()
				if char and root then
					pcall(fireRocket, tool, root.Position, root.CFrame.LookVector, nil)
				end
			end
			task.wait(0.2)
		end)
	end
end)

local instantHitRunning = false
addToggle("RPG Instant Hit", function(s)
	syncEnv("rpginstanthit", s)
	instantHitRunning = s
	if s then
		task.spawn(function()
			while instantHitRunning do
				pcall(function()
					for _, obj in ipairs(workspace:GetChildren()) do
						if obj.Name:find("Rocket") and obj:GetAttribute("Owner") == LocalPlayer.Name then
							local mainPart = obj:FindFirstChild("MainPart") or obj:FindFirstChild("Rocket")
							if mainPart then
								-- 가장 가까운 적에게 즉시 전송
								local best, bestDist
								for _, player in ipairs(Players:GetPlayers()) do
									if player ~= LocalPlayer and player.Character
										and player.Character:FindFirstChild("HumanoidRootPart") then
										local d = (player.Character.HumanoidRootPart.Position - mainPart.Position).Magnitude
										if not bestDist or d < bestDist then
											best, bestDist = player.Character.HumanoidRootPart, d
										end
									end
								end
								if best then mainPart.CFrame = best.CFrame end
							end
						end
					end
				end)
				task.wait(0.05)
			end
		end)
	end
end)

local auraRunning = false
addToggle("Rocket Aura", function(s)
	syncEnv("rocketaura", s)
	auraRunning = s
	if s then
		task.spawn(function()
			while auraRunning do
				pcall(function()
					local tool = getEquippedTool()
					local char, _, root = getChar()
					if tool and tool:FindFirstChild("RocketSettings") and root then
						for _, player in ipairs(Players:GetPlayers()) do
							if player ~= LocalPlayer and player.Character
								and player.Character:FindFirstChild("HumanoidRootPart") then
								local tpos = player.Character.HumanoidRootPart.Position
								if (root.Position - tpos).Magnitude < 4000 then
									-- 실제 스크립트 방식: 목표 위에서 아래로 발사
									fireRocket(tool, tpos + Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), player.Character)
								end
							end
						end
					end
				end)
				task.wait(0.5)
			end
		end)
	end
end)

addToggle("Rocket Stat Boost", function(s)
	pcall(function()
		if RocketSystem then
			for _, desc in ipairs(RocketSystem:GetDescendants()) do
				if desc.Name == "RocketSettings" then
					local ok, cfg = pcall(require, desc)
					if ok and type(cfg) == "table" then
						cfg.TurnSpeed    = s and 9999 or 50
						cfg.Acceleration = s and 500  or 50
						cfg.ExpRadius    = s and 50   or 15
					end
				end
			end
		end
	end)
end)

----------------------------------------------------------------
-- [3] Kill Aura — 근처 플레이어에게 로켓 발사 (직접 구현)
----------------------------------------------------------------
local killAuraConn
addSectionLabel("== Rage ==")
addToggle("Kill Aura (150m)", function(s)
	syncEnv("killAuraEnabled", s)
	if killAuraConn then killAuraConn:Disconnect(); killAuraConn = nil end
	if s then
		killAuraConn = RunService.Heartbeat:Connect(function()
			local tool = getEquippedTool()
			local char, _, root = getChar()
			if not (tool and root and tool:FindFirstChild("RocketSettings")) then return end
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character
					and player.Character:FindFirstChild("HumanoidRootPart") then
					local hrp = player.Character.HumanoidRootPart
					if (hrp.Position - root.Position).Magnitude < 8000 then
						pcall(fireRocket, tool, root.Position, (hrp.Position - root.Position).Unit, player.Character)
					end
				end
			end
			task.wait(0.35)
		end)
	end
end)

----------------------------------------------------------------
-- [4] Movement — 범용 구현
----------------------------------------------------------------
local flyConn, noclipConn
local flySpeed = 60
addSectionLabel("== Movement ==")
addToggle("Fly", function(s)
	if flyConn then flyConn:Disconnect(); flyConn = nil end
	local char, hum, root = getChar()
	if s and root then
		flyConn = RunService.RenderStepped:Connect(function(dt)
			local c, h, r = getChar()
			if not (c and h and r) or h.Health <= 0 then return end
			r.AssemblyLinearVelocity = Vector3.zero
			local cam = workspace.CurrentCamera
			local dir = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
			if dir.Magnitude > 0 then
				r.CFrame = r.CFrame + dir.Unit * flySpeed * dt
			end
		end)
	end
	if hum then hum.PlatformStand = false end
end)

addToggle("Noclip", function(s)
	if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
	if s then
		noclipConn = RunService.Stepped:Connect(function()
			local char = getChar()
			if char then
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") and part.CanCollide then
						part.CanCollide = false
					end
				end
			end
		end)
	end
end)

local infJumpConn
addToggle("Infinite Jump", function(s)
	if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
	if s then
		infJumpConn = UserInputService.JumpRequest:Connect(function()
			local _, hum = getChar()
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end
end)

addToggle("WalkSpeed Boost", function(s)
	local _, hum = getChar()
	if hum then
		if s then
			hum.WalkSpeed = 60
		else
			hum.WalkSpeed = 16
		end
	end
end)

----------------------------------------------------------------
-- 우측 Ctrl: GUI 토글
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		ScreenGui.Enabled = not ScreenGui.Enabled
	end
end)

print("[ACS Exploit] Panel loaded — verified rocket payload + BSMT getgenv sync")
