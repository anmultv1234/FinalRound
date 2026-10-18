-- ACS Framework Compatible Exploit GUI (v3)
-- War Tycoon (ACS) — 검증 완료: recovered_full.lua 실제 메커니즘 기반
--
-- v2 → v3 변경점 (사용자 지시 반영):
--  * RPG Aura 거리 150 → 4000 스터드 (getgenv().rocketaura_range = 4000 도 동기화)
--  * Kill Aura 거리 150 → 8000 스터드
--  * Full Auto: 모드(Mode)를 "Auto"로 바꾸지 않고, 서버는 Semi/Bolt 로 인식하게 유지한 채
--    클라이언트에서 tool:Activate() 를 서버-안전 주기(FireRate/60 초당, 최대 20/s)로 반복 호출.
--    → recovered SGA auto-trigger(root.47) 의 (r1 - u3) < (1 / r5) 메커니즘을 그대로 재현.
--    (Mode="Auto" 로 패치하면 서버가 Auto 로 믿고 레이트리밋/거부하여 데미지가 안 들어갔음)
--  * Infinite Ammo: 한 번 설정이 아니라 Heartbeat 루프로 tool.ammo.Value = 600 지속 고정.
--    → recovered root.89 의 r10[ammo][Value] = 600 지속 설정 메커니즘 재현.
--
-- 근거 (recovered_full.lua):
--   root.88  (gun-mods 설정 패치: Ammo/AmmoVal/Mode/FireRate/Recoil)
--   root.89  (getgenv() gm_* 토글 상태 → 설정 테이블 지속 적용 루프)
--   root.47  (SGA auto-trigger: 1/FireRate 주기로 자동 발사)
--   root.103/104 (rocket aura: getgenv().rocketaura_range, (posA-posB).Magnitude <= range)
--   root.105/106 (rocketaura 토글 / rocketaura_range 세터)

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
Title.Text = "ACS Framework Exploit Panel (v3)"
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
----------------------------------------------------------------
local GUN_KEYS = { "VRecoil", "HRecoil", "MinSpread", "MaxSpread", "FireRate", "Mode", "Ammo", "AmmoVal" }
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
	-- 장착 중인 툴에도 즉시 반영
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

-- 장착 툴의 설정(fireRate 등) 반환
local function getToolSettings(tool)
	tool = tool or getEquippedTool()
	if not tool then return nil end
	local mod = tool:FindFirstChild("Settings") or tool:FindFirstChildOfClass("ModuleScript")
	if not mod then return nil end
	local ok, settings = pcall(require, mod)
	if ok and type(settings) == "table" then return settings end
	return nil
end

-- 서버-안전 발사 주기 계산 (recovered root.47: FireRate/60 초당, 최대 20/s)
--   반환: interval(초). rps = clamp(FireRate/60, 1, 20)
local function serverSafeInterval(settings)
	local fr = tonumber(settings and settings.FireRate) or 600
	local rps = math.clamp(fr / 60, 1, 20)
	return 1 / rps
end

local gunState = { norecoil = false, nospread = false, infammo = false, fullauto = false, firerate = false }

-- Full Auto 전용 루프 (Mode 는 건드리지 않음 → 서버는 Semi/Bolt 유지)
local fullAutoConn
local function setFullAuto(on)
	if fullAutoConn then fullAutoConn:Disconnect(); fullAutoConn = nil end
	if not on then return end
	fullAutoConn = RunService.Heartbeat:Connect(function()
		local tool = getEquippedTool()
		if not tool or not tool:IsA("Tool") then return end
		-- Mode 는 원본(Semi/Bolt) 그대로 두고, 클라이언트에서만 반복 활성화
		local settings = getToolSettings(tool)
		local interval = serverSafeInterval(settings)
		if not tool._acsLastFire or (tick() - tool._acsLastFire) >= interval then
			tool._acsLastFire = tick()
			pcall(function()
				tool:Activate() -- 서버에는 정상 세미/볼트 1발로 등록 → 데미지 정상 적용
			end)
		end
	end)
end

-- Infinite Ammo 전용 루프 (recovered root.89: ammo.Value 지속 고정)
local infAmmoConn
local AMMO_VALUE = 600
local function setInfiniteAmmo(on)
	if infAmmoConn then infAmmoConn:Disconnect(); infAmmoConn = nil end
	if not on then return end
	infAmmoConn = RunService.Heartbeat:Connect(function()
		local tool = getEquippedTool()
		if not tool then return end
		local ammoVal = tool:FindFirstChild("ammo")
		if ammoVal and ammoVal:IsA("NumberValue") and ammoVal.Value ~= AMMO_VALUE then
			ammoVal.Value = AMMO_VALUE
		end
		-- ACS 설정 모듈의 AmmoVal 도 동기화 (root.88: r2[AmmoVal] = ammo.Value)
		local settings = getToolSettings(tool)
		if settings and settings.AmmoVal ~= nil then
			settings.AmmoVal = AMMO_VALUE
		end
	end)
end

local function applyGunState()
	if not (gunState.norecoil or gunState.nospread or gunState.infammo
		or gunState.fullauto or gunState.firerate) then
		restoreGuns()
		setFullAuto(false)
		setInfiniteAmmo(false)
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
	if gunState.firerate then
		patchGuns("FireRate", 1200)
	end
	-- Full Auto / Infinite Ammo 는 설정 패치가 아니라 지속 루프로 처리
	setFullAuto(gunState.fullauto)
	setInfiniteAmmo(gunState.infammo)
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
addToggle("Full Auto (server-safe)", function(s)
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

-- RPG Aura: 거리 4000 스터드 (recovered root.103/104 의 rocketaura_range 사용)
local ROCKET_AURA_RANGE = 4000
local auraRunning = false
addToggle("Rocket Aura (4000 studs)", function(s)
	syncEnv("rocketaura", s)
	syncEnv("rocketaura_range", ROCKET_AURA_RANGE)
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
								-- 팀 필터 (recovered: 같은 팀이면 스킵, 팀 없으면 통과)
								local sameTeam = LocalPlayer.Team and player.Team
									and (player.Team == LocalPlayer.Team)
								local tpos = player.Character.HumanoidRootPart.Position
								if not sameTeam and (root.Position - tpos).Magnitude <= ROCKET_AURA_RANGE then
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
-- [3] Kill Aura — 근처 플레이어에게 로켓 발사 (거리 8000 스터드)
----------------------------------------------------------------
local killAuraConn
addSectionLabel("== Rage ==")
addToggle("Kill Aura (8000 studs)", function(s)
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
					local sameTeam = LocalPlayer.Team and player.Team
						and (player.Team == LocalPlayer.Team)
					local hrp = player.Character.HumanoidRootPart
					if not sameTeam and (hrp.Position - root.Position).Magnitude <= 8000 then
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

print("[ACS Exploit v3] RPG Aura=4000 / Kill Aura=8000 / FullAuto server-safe / InfAmmo loop")
