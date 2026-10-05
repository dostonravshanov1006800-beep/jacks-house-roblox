-- ================================================================
-- JACK'S HOUSE — Хэллоуин-хоррор для Roblox
-- Главный серверный скрипт. Кладётся как Script в ServerScriptService,
-- внутри папки "Halloween" рядом с папкой "Modules".
-- ================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

-- Создаём ремоуты (клиент и сервер общаются через них)
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end

ensureRemote("GameState") -- сервер -> клиент: состояние игры
ensureRemote("Knock")     -- клиент (предатель) -> сервер: способность "Стук"
ensureRemote("Sfx")       -- сервер -> клиент: события (стук, монстр)

-- ================================================================
-- ЛОББИ — строится кодом, ничего вручную строить не нужно.
-- Стоит в 300 стадах от начала дома (дом идёт от (0,0,0) в -Z).
-- ================================================================
local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function buildLobby()
	if workspace:FindFirstChild("LobbySpawn") then return end

	local model = Instance.new("Model")
	model.Name = "GameLobby"

	local O = Vector3.new(300, 0, 0) -- центр лобби

	-- Пол
	part({
		Name = "LobbyFloor",
		Size = Vector3.new(140, 1, 140),
		Position = O + Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(45, 40, 48),
		Material = Enum.Material.Slate,
		Parent = model,
	})

	-- Борта по периметру
	for _, d in ipairs({ { 0, -70 }, { 0, 70 }, { -70, 0 }, { 70, 0 } }) do
		local along = (d[1] ~= 0) and Vector3.new(1, 140, 4) or Vector3.new(4, 1, 140)
		part({
			Name = "LobbyRim",
			Size = Vector3.new(along.X, 4, along.Z),
			Position = O + Vector3.new(d[1], 1.5, d[2]),
			Color = Color3.fromRGB(30, 25, 22),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end

	-- Табличка "JACK'S HOUSE"
	local sign = part({
		Name = "LobbySign",
		Size = Vector3.new(24, 8, 1),
		Position = O + Vector3.new(0, 14, -60),
		Color = Color3.fromRGB(20, 15, 12),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = Color3.fromRGB(255, 150, 50)
	text.TextScaled = true
	text.Text = "🎃 JACK'S HOUSE"
	text.Parent = gui
	part({
		Name = "SignPostL",
		Size = Vector3.new(2, 10, 2),
		Position = O + Vector3.new(-9, 5, -60),
		Color = Color3.fromRGB(35, 26, 20),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	part({
		Name = "SignPostR",
		Size = Vector3.new(2, 10, 2),
		Position = O + Vector3.new(9, 5, -60),
		Color = Color3.fromRGB(35, 26, 20),
		Material = Enum.Material.Wood,
		Parent = model,
	})

	-- Факелы-столбы по углам
	for _, c in ipairs({ { -60, -60 }, { 60, -60 }, { -60, 60 }, { 60, 60 } }) do
		part({
			Name = "TorchPole",
			Size = Vector3.new(2, 16, 2),
			Position = O + Vector3.new(c[1], 7.5, c[2]),
			Color = Color3.fromRGB(35, 30, 26),
			Material = Enum.Material.Wood,
			Parent = model,
		})
		local flame = part({
			Name = "LobbyFlame",
			Size = Vector3.new(2.2, 3, 2.2),
			Position = O + Vector3.new(c[1], 17, c[2]),
			Color = Color3.fromRGB(255, 170, 60),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 90)
		light.Range = 26
		light.Brightness = 1.2
		light.Parent = flame
	end

	-- Тыквы у входа
	for _, x in ipairs({ -14, 14 }) do
		local pumpkin = part({
			Name = "LobbyPumpkin",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.6, 3.2, 3.6),
			Position = O + Vector3.new(x, 1.7, -64),
			Color = Color3.fromRGB(255, 120, 20),
			Parent = model,
		})
		part({
			Name = "LobbyStem",
			Size = Vector3.new(0.6, 1.2, 0.6),
			Position = O + Vector3.new(x, 3.5, -64),
			Color = Color3.fromRGB(60, 120, 40),
			Parent = model,
		})
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 140, 40)
		glow.Range = 11
		glow.Brightness = 0.9
		glow.Parent = pumpkin
	end

	-- Точка возврата после раунда
	part({
		Name = "LobbySpawn",
		Size = Vector3.new(20, 0.4, 10),
		Position = O + Vector3.new(0, 0.2, 20),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})

	-- Спавн игроков
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "LobbySpawnLocation"
	spawnLoc.Size = Vector3.new(24, 1, 24)
	spawnLoc.Position = O + Vector3.new(0, 0.5, 40)
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Color = Color3.fromRGB(50, 44, 54)
	spawnLoc.Material = Enum.Material.Slate
	spawnLoc.Parent = model

	model.Parent = workspace
end

buildLobby()

-- Ночь
Lighting.ClockTime = 0

-- Проверяем, что ассеты на месте (опционально)
if not ServerStorage:FindFirstChild("GameAssets") then
	-- Это нормально: комнаты и монстр строятся кодом автоматически
	print("[Jack's House] Ассетов нет — используем авто-постройку комнат и встроенного монстра")
end

local RoundManager = require(script.Parent.Modules.RoundManager)
RoundManager.start()
