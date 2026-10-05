-- ================================================================
-- GameClient v2 — премиальный HUD: панель фазы с полосой прогресса,
-- виньетка, пульс "ОН РЯДОМ", скример при смерти, кнопка предателя.
-- Кладётся как LocalScript в StarterPlayer > StarterPlayerScripts.
-- ================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateRemote = Remotes:WaitForChild("GameState")
local KnockRemote = Remotes:WaitForChild("Knock")
local SfxRemote = Remotes:WaitForChild("Sfx")

local player = Players.LocalPlayer

local ORANGE = Color3.fromRGB(255, 150, 50)
local RED = Color3.fromRGB(255, 60, 60)
local DARK_BG = Color3.fromRGB(12, 9, 9)

-- ================= БАЗА GUI =================
local gui = Instance.new("ScreenGui")
gui.Name = "HalloweenHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- ---------- ВИНЕТКА (тёмные края по бокам) ----------
local function makeVignette(name, position, size, rotation)
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = position
	f.Size = size
	f.BackgroundTransparency = 0
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.ZIndex = 5
	f.Parent = gui
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	return f
end

makeVignette("VigTop", UDim2.new(0.15, 0, 0, 0), UDim2.new(0.7, 0, 0, 90), 90)
makeVignette("VigBottom", UDim2.new(0.15, 0, 1, -90), UDim2.new(0.7, 0, 0, 90), 270)
makeVignette("VigLeft", UDim2.new(0, 0, 0, 0), UDim2.new(0, 90, 1, 0), 0)
makeVignette("VigRight", UDim2.new(1, -90, 0, 0), UDim2.new(0, 90, 1, 0), 180)

-- ---------- ВЕРХНЯЯ ПАНЕЛЬ (фаза + прогресс дверей) ----------
local topPanel = Instance.new("Frame")
topPanel.Name = "TopPanel"
topPanel.Size = UDim2.new(0, 320, 0, 92)
topPanel.Position = UDim2.new(0.5, -160, 0, 14)
topPanel.BackgroundColor3 = DARK_BG
topPanel.BackgroundTransparency = 0.35
topPanel.BorderSizePixel = 0
topPanel.Parent = gui
Instance.new("UICorner", topPanel).CornerRadius = UDim.new(0, 16)
local topStroke = Instance.new("UIStroke", topPanel)
topStroke.Color = ORANGE
topStroke.Thickness = 1.5
topStroke.Transparency = 0.4

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "Phase"
phaseLabel.Size = UDim2.new(1, -20, 0, 34)
phaseLabel.Position = UDim2.new(0, 10, 0, 8)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Font = Enum.Font.GothamBlack
phaseLabel.TextColor3 = ORANGE
phaseLabel.TextSize = 20
phaseLabel.TextStrokeTransparency = 0.6
phaseLabel.Text = ""
phaseLabel.Parent = topPanel

local barBg = Instance.new("Frame")
barBg.Name = "BarBg"
barBg.Size = UDim2.new(1, -40, 0, 10)
barBg.Position = UDim2.new(0, 20, 0, 50)
barBg.BackgroundColor3 = Color3.fromRGB(30, 22, 18)
barBg.BorderSizePixel = 0
barBg.Parent = topPanel
Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = ORANGE
barFill.BorderSizePixel = 0
barFill.Parent = barBg
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
local barGradient = Instance.new("UIGradient", barFill)
barGradient.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), ORANGE)

local doorsLabel = Instance.new("TextLabel")
doorsLabel.Name = "Doors"
doorsLabel.Size = UDim2.new(1, -20, 0, 24)
doorsLabel.Position = UDim2.new(0, 10, 0, 62)
doorsLabel.BackgroundTransparency = 1
doorsLabel.Font = Enum.Font.GothamBold
doorsLabel.TextColor3 = Color3.fromRGB(255, 225, 180)
doorsLabel.TextSize = 14
doorsLabel.Text = ""
doorsLabel.Parent = topPanel

-- ---------- КОНФЕТЫ (пилюля справа сверху) ----------
local candyPanel = Instance.new("Frame")
candyPanel.Name = "CandyPanel"
candyPanel.Size = UDim2.new(0, 130, 0, 44)
candyPanel.Position = UDim2.new(1, -150, 0, 16)
candyPanel.BackgroundColor3 = DARK_BG
candyPanel.BackgroundTransparency = 0.35
candyPanel.BorderSizePixel = 0
candyPanel.Parent = gui
Instance.new("UICorner", candyPanel).CornerRadius = UDim.new(1, 0)
local candyStroke = Instance.new("UIStroke", candyPanel)
candyStroke.Color = Color3.fromRGB(255, 90, 90)
candyStroke.Thickness = 1.5
candyStroke.Transparency = 0.4

local candyLabel = Instance.new("TextLabel")
candyLabel.Size = UDim2.new(1, 0, 1, 0)
candyLabel.BackgroundTransparency = 1
candyLabel.Font = Enum.Font.GothamBlack
candyLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
candyLabel.TextSize = 18
candyLabel.Text = "🍬 0"
candyLabel.Parent = candyPanel

-- ---------- ОТСЧЁТ (большой, по центру) ----------
local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "Countdown"
countdownLabel.Size = UDim2.new(0, 200, 0, 100)
countdownLabel.Position = UDim2.new(0.5, -100, 0.35, 0)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Font = Enum.Font.GothamBlack
countdownLabel.TextColor3 = ORANGE
countdownLabel.TextSize = 72
countdownLabel.TextStrokeTransparency = 0.3
countdownLabel.Visible = false
countdownLabel.Parent = gui

-- ---------- СООБЩЕНИЯ (по центру) ----------
local msgLabel = Instance.new("TextLabel")
msgLabel.Name = "Msg"
msgLabel.Size = UDim2.new(0.7, 0, 0, 44)
msgLabel.Position = UDim2.new(0.15, 0, 0.3, 0)
msgLabel.BackgroundTransparency = 1
msgLabel.Font = Enum.Font.GothamBlack
msgLabel.TextColor3 = RED
msgLabel.TextSize = 26
msgLabel.TextStrokeTransparency = 0.4
msgLabel.Text = ""
msgLabel.Parent = gui

local function showMessage(text)
	msgLabel.Text = text
	msgLabel.TextTransparency = 0
	msgLabel.TextStrokeTransparency = 0.4
	task.spawn(function()
		task.wait(2.2)
		for i = 1, 20 do
			msgLabel.TextTransparency = i / 20
			msgLabel.TextStrokeTransparency = 0.4 + i / 20 * 0.6
			task.wait(0.06)
		end
		msgLabel.Text = ""
	end)
end

-- ---------- "ОН РЯДОМ" (пульсирующий) ----------
local proxLabel = Instance.new("TextLabel")
proxLabel.Name = "Prox"
proxLabel.Size = UDim2.new(0.5, 0, 0, 36)
proxLabel.Position = UDim2.new(0.25, 0, 0.18, 0)
proxLabel.BackgroundTransparency = 1
proxLabel.Font = Enum.Font.GothamBlack
proxLabel.TextColor3 = RED
proxLabel.TextSize = 24
proxLabel.TextStrokeTransparency = 0.3
proxLabel.Text = "⚠ ОН РЯДОМ ⚠"
proxLabel.Visible = false
proxLabel.Parent = gui

task.spawn(function()
	while true do
		if proxLabel.Visible then
			local t = os.clock() * 6
			proxLabel.TextTransparency = 0.25 + math.abs(math.sin(t)) * 0.55
		end
		task.wait(0.05)
	end
end)

-- ---------- СКРИМЕР ПРИ СМЕРТИ ----------
local deathOverlay = Instance.new("Frame")
deathOverlay.Name = "DeathOverlay"
deathOverlay.Size = UDim2.new(1, 0, 1, 0)
deathOverlay.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
deathOverlay.BackgroundTransparency = 0.45
deathOverlay.Visible = false
deathOverlay.ZIndex = 20
deathOverlay.Parent = gui

local deathLabel = Instance.new("TextLabel")
deathLabel.Size = UDim2.new(1, 0, 0, 90)
deathLabel.Position = UDim2.new(0, 0, 0.4, 0)
deathLabel.BackgroundTransparency = 1
deathLabel.Font = Enum.Font.GothamBlack
deathLabel.TextColor3 = RED
deathLabel.TextSize = 54
deathLabel.TextStrokeTransparency = 0.2
deathLabel.Text = "💀 ТЫ МЕРТВ"
deathLabel.ZIndex = 21
deathLabel.Parent = deathOverlay

-- ---------- КНОПКА ПРЕДАТЕЛЯ ----------
local traitorBtn = Instance.new("TextButton")
traitorBtn.Name = "TraitorBtn"
traitorBtn.Size = UDim2.new(0, 280, 0, 58)
traitorBtn.Position = UDim2.new(0.5, -140, 1, -86)
traitorBtn.BackgroundColor3 = DARK_BG
traitorBtn.BackgroundTransparency = 0.2
traitorBtn.TextColor3 = ORANGE
traitorBtn.Font = Enum.Font.GothamBlack
traitorBtn.TextSize = 17
traitorBtn.Text = "🔊 СТУК — приманить монстра"
traitorBtn.Visible = false
traitorBtn.Parent = gui
Instance.new("UICorner", traitorBtn).CornerRadius = UDim.new(0, 14)
local traitorStroke = Instance.new("UIStroke", traitorBtn)
traitorStroke.Color = ORANGE
traitorStroke.Thickness = 2

-- ---------- КНОПКА ФОНАРИКА ----------
local torchBtn = Instance.new("TextButton")
torchBtn.Name = "TorchBtn"
torchBtn.Size = UDim2.new(0, 64, 0, 64)
torchBtn.Position = UDim2.new(1, -84, 1, -170)
torchBtn.BackgroundColor3 = DARK_BG
torchBtn.BackgroundTransparency = 0.2
torchBtn.TextColor3 = Color3.fromRGB(255, 220, 120)
torchBtn.Font = Enum.Font.GothamBlack
torchBtn.TextSize = 26
torchBtn.Text = "🔦"
torchBtn.Parent = gui
Instance.new("UICorner", torchBtn).CornerRadius = UDim.new(1, 0)
local torchStroke = Instance.new("UIStroke", torchBtn)
torchStroke.Color = Color3.fromRGB(255, 210, 120)
torchStroke.Thickness = 1.5

-- ================= ФОНАРИК =================
local torch = nil
local torchOn = false

local function attachTorch(char)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then return end
	torch = Instance.new("PointLight")
	torch.Name = "TorchLight"
	torch.Range = 14
	torch.Brightness = 1.3
	torch.Color = Color3.fromRGB(255, 210, 140)
	torch.Enabled = false
	torch.Parent = root
	torchOn = false
end

local function toggleTorch()
	if torch then
		torchOn = not torchOn
		torch.Enabled = torchOn
	end
end

torchBtn.MouseButton1Click:Connect(toggleTorch)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F then
		toggleTorch()
	end
end)

-- ================= СМЕРТЬ -> СКРИМЕР =================
local function hookCharacter(char)
	attachTorch(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			deathOverlay.Visible = true
			task.wait(2.5)
			deathOverlay.Visible = false
		end)
	end
end

player.CharacterAdded:Connect(hookCharacter)
if player.Character then
	hookCharacter(player.Character)
end

-- ================= ПРЕДАТЕЛЬ =================
local knockCooldown = 20
local traitorCd = false

traitorBtn.MouseButton1Click:Connect(function()
	if traitorBtn.Visible and not traitorCd then
		KnockRemote:FireServer()
		traitorCd = true
		local original = traitorBtn.Text
		traitorBtn.Text = "⏳ перезарядка..."
		task.spawn(function()
			task.wait(knockCooldown)
			traitorCd = false
			traitorBtn.Text = original
		end)
	end
end)

-- ================= СОСТОЯНИЕ ИГРЫ =================
local wasBlackout = false
local monsterProximity = 50

GameStateRemote.OnClientEvent:Connect(function(state)
	knockCooldown = state.knockCd or 20
	monsterProximity = state.monsterProximity or 50

	local phaseText = ""
	if state.phase == "lobby" then
		phaseText = "🎃 Ждём игроков..."
	elseif state.phase == "waiting" then
		phaseText = "⏳ Раунд вот-вот начнётся"
	elseif state.phase == "running" then
		if state.blackout then
			phaseText = "🕯 СВЕТ ПОГАС — ОН БЫСТРЕЕ"
		else
			phaseText = "🏠 Беги к выходу!"
		end
	elseif state.phase == "results" then
		if state.result == "all_dead" then
			phaseText = "💀 Дом забрал всех..."
		elseif state.result == "escaped" then
			phaseText = "🏁 Выжившие сбежали!"
		else
			phaseText = "⏰ Время вышло..."
		end
	end
	phaseLabel.Text = phaseText

	-- Прогресс дверей
	local pct = math.clamp(state.doors / math.max(1, state.total), 0, 1)
	local fillTween = TweenService:Create(barFill, TweenInfo.new(0.5), { Size = UDim2.new(pct, 0, 1, 0) })
	fillTween:Play()
	doorsLabel.Text = "🚪 Двери: " .. tostring(state.doors) .. " / " .. tostring(state.total)

	candyLabel.Text = "🍬 " .. tostring(state.candy)

	-- Отсчёт
	if state.phase == "waiting" and state.countdown > 0 then
		countdownLabel.Visible = true
		countdownLabel.Text = tostring(state.countdown)
	else
		countdownLabel.Visible = false
	end

	-- Кнопка предателя
	traitorBtn.Visible = state.isTraitor and state.phase == "running"

	if state.blackout and not wasBlackout then
		showMessage("СВЕТ ПОГАС... НЕ ОСТАНАВЛИВАЙСЯ")
	end
	wasBlackout = state.blackout
end)

-- ================= "ОН РЯДОМ": следим за монстром =================
task.spawn(function()
	while true do
		task.wait(0.25)
		local monster = workspace:FindFirstChild("ActiveMonster")
		local char = player.Character
		local show = false
		if monster and monster.PrimaryPart and char and char.PrimaryPart then
			local d = (monster.PrimaryPart.Position - char.PrimaryPart.Position).Magnitude
			show = d < monsterProximity
		end
		proxLabel.Visible = show
	end
end)

-- ================= СОБЫТИЯ =================
SfxRemote.OnClientEvent:Connect(function(event)
	if event.type == "knock" then
		showMessage("СТУК-СТУК... кто-то стучит по стене!")
	elseif event.type == "monster" then
		showMessage("ОН ПРОСНУЛСЯ. БЕГИ.")
	elseif event.type == "blackout" then
		-- сообщение придёт через состояние
	end
end)
