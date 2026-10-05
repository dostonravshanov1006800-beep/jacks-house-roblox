-- ================================================================
-- GameClient — HUD игрока, фонарик, кнопка предателя.
-- Кладётся как LocalScript в StarterPlayer > StarterPlayerScripts.
-- ================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateRemote = Remotes:WaitForChild("GameState")
local KnockRemote = Remotes:WaitForChild("Knock")
local SfxRemote = Remotes:WaitForChild("Sfx")

local player = Players.LocalPlayer

-- ================= GUI =================
local gui = Instance.new("ScreenGui")
gui.Name = "HalloweenHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(name, size, position, textSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.fromRGB(255, 150, 50)
	l.TextSize = textSize
	l.TextStrokeTransparency = 0.5
	l.Text = ""
	l.Parent = gui
	return l
end

local phaseLabel = makeLabel("Phase", UDim2.new(0.5, 0, 0, 42), UDim2.new(0.25, 0, 0, 18), 26)
local doorsLabel = makeLabel("Doors", UDim2.new(0.5, 0, 0, 32), UDim2.new(0.25, 0, 0, 58), 20)
local candyLabel = makeLabel("Candy", UDim2.new(0, 160, 0, 34), UDim2.new(1, -170, 0, 16), 22)
candyLabel.TextColor3 = Color3.fromRGB(255, 90, 90)

local msgLabel = makeLabel("Msg", UDim2.new(0.6, 0, 0, 40), UDim2.new(0.2, 0, 0.35, 0), 28)
msgLabel.TextColor3 = Color3.fromRGB(255, 60, 60)

local function showMessage(text)
	msgLabel.Text = text
	msgLabel.TextTransparency = 0
	task.spawn(function()
		for i = 1, 30 do
			msgLabel.TextTransparency = i / 30
			task.wait(0.1)
		end
		msgLabel.Text = ""
	end)
end

-- Кнопка предателя
local traitorBtn = Instance.new("TextButton")
traitorBtn.Name = "TraitorBtn"
traitorBtn.Size = UDim2.new(0, 240, 0, 56)
traitorBtn.Position = UDim2.new(0.5, -120, 1, -80)
traitorBtn.BackgroundColor3 = Color3.fromRGB(20, 15, 15)
traitorBtn.TextColor3 = Color3.fromRGB(255, 150, 50)
traitorBtn.Font = Enum.Font.GothamBlack
traitorBtn.TextSize = 18
traitorBtn.Text = "🔊 СТУК — приманить монстра"
traitorBtn.Visible = false
traitorBtn.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = traitorBtn

-- Кнопка фонарика (для телефона)
local torchBtn = Instance.new("TextButton")
torchBtn.Name = "TorchBtn"
torchBtn.Size = UDim2.new(0, 64, 0, 64)
torchBtn.Position = UDim2.new(1, -80, 1, -160)
torchBtn.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
torchBtn.TextColor3 = Color3.fromRGB(255, 220, 120)
torchBtn.Font = Enum.Font.GothamBlack
torchBtn.TextSize = 26
torchBtn.Text = "🔦"
torchBtn.Parent = gui

local corner2 = Instance.new("UICorner")
corner2.CornerRadius = UDim.new(0, 32)
corner2.Parent = torchBtn

-- ================= Фонарик =================
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

player.CharacterAdded:Connect(attachTorch)
if player.Character then
	attachTorch(player.Character)
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

-- ================= Предатель =================
local knockCooldown = 20

traitorBtn.MouseButton1Click:Connect(function()
	if traitorBtn.Visible then
		KnockRemote:FireServer()
		traitorBtn.Visible = false
		task.wait(knockCooldown)
		traitorBtn.Visible = true
	end
end)

-- ================= Состояние игры =================
local wasBlackout = false

GameStateRemote.OnClientEvent:Connect(function(state)
	knockCooldown = state.knockCd or 20

	local phaseText = ""
	if state.phase == "lobby" then
		phaseText = "🎃 Ждём игроков..."
	elseif state.phase == "waiting" then
		phaseText = "⏳ Раунд начнётся через " .. tostring(state.countdown) .. "..."
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

	doorsLabel.Text = "🚪 Двери: " .. tostring(state.doors) .. " / " .. tostring(state.total)
	candyLabel.Text = "🍬 " .. tostring(state.candy)

	traitorBtn.Visible = state.isTraitor and state.phase == "running"

	if state.blackout and not wasBlackout then
		showMessage("СВЕТ ПОГАС... НЕ ОСТАНАВЛИВАЙСЯ")
	end
	wasBlackout = state.blackout
end)

-- ================= События =================
SfxRemote.OnClientEvent:Connect(function(event)
	if event.type == "knock" then
		showMessage("СТУК-СТУК... кто-то стучит по стене!")
	elseif event.type == "monster" then
		showMessage("ОН ПРОСНУЛСЯ. БЕГИ.")
	elseif event.type == "blackout" then
		-- сообщение придёт через состояние
	end
end)
