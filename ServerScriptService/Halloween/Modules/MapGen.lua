-- ================================================================
-- MapGen v2 — строит дом.
-- Если в ServerStorage.GameAssets есть RoomTemplate — клонирует его.
-- Если нет — САМ строит атмосферные комнаты:
-- тёмное дерево, каменные стены, мерцающие свечи, тыквы, дверные рамы.
-- ================================================================

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local MapGen = {}

-- ---------- фабрика частей ----------
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

-- ---------- палитра ----------
local COLOR = {
	floor = Color3.fromRGB(92, 62, 42),
	wall = Color3.fromRGB(58, 56, 66),
	trim = Color3.fromRGB(40, 30, 24),
	ceiling = Color3.fromRGB(28, 22, 18),
	door = Color3.fromRGB(88, 52, 30),
	frame = Color3.fromRGB(35, 26, 20),
	pillar = Color3.fromRGB(48, 44, 54),
	candle = Color3.fromRGB(255, 240, 200),
	pumpkin = Color3.fromRGB(255, 120, 20),
	stem = Color3.fromRGB(60, 120, 40),
}

-- ================================================================
-- АВТО-ПОСТРОЙКА КРАСИВОЙ КОМНАТЫ
-- Локальная система: x = вправо, y = вверх, z: +L/2 у ВХОДА, -L/2 у ДВЕРИ
-- ================================================================
local function buildAutoRoom(config, i, origin, F, S)
	local W, L, H = config.ROOM_WIDTH, config.ROOM_LENGTH, config.WALL_HEIGHT
	local DW, DH = config.DOOR_WIDTH, config.DOOR_HEIGHT

	local model = Instance.new("Model")
	model.Name = "Room" .. i

	-- Перевод локальных координат в мировые
	local function toWorld(lx, ly, lz)
		return origin + F * (L * (i - 1)) + S * lx + Vector3.new(0, ly, 0) + F * (-lz)
	end
	local function toWorldSize(sx, sy, sz)
		if config.CORRIDOR_AXIS == "Z" then
			return Vector3.new(sx, sy, sz)
		end
		return Vector3.new(sz, sy, sx)
	end
	local function add(name, lx, ly, lz, sx, sy, sz, color, material)
		local p = part({
			Name = name,
			Size = toWorldSize(sx, sy, sz),
			Position = toWorld(lx, ly, lz),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
		})
		p.Parent = model
		return p
	end

	-- Пол и потолок
	add("Floor", 0, -0.5, 0, W, 1, L, COLOR.floor, Enum.Material.WoodPlanks)
	add("Ceiling", 0, H, 0, W, 1, L, COLOR.ceiling, Enum.Material.Wood)

	-- Балки перекрытия
	for _, bz in ipairs({ -L / 4, 0, L / 4 }) do
		add("Beam", 0, H - 1.4, bz, W, 2, 2, COLOR.trim, Enum.Material.Wood)
	end

	-- Боковые стены + тёмные панели внизу
	for _, side in ipairs({ -1, 1 }) do
		add("Wall", side * (W / 2), H / 2, 0, 1.5, H, L, COLOR.wall, Enum.Material.Slate)
		add("Wainscot", side * (W / 2 - 0.9), 3.5, 0, 0.8, 7, L, COLOR.trim, Enum.Material.Wood)
	end

	-- Задняя стена комнаты 1 (за спиной игроков)
	if i == 1 then
		add("BackWall", 0, H / 2, L / 2, W, H, 1.5, COLOR.wall, Enum.Material.Slate)
	end

	-- Дальняя стена с дверным проёмом + рама + колонны
	local frameEdge = DW / 2 + 3
	local segW = W / 2 - frameEdge
	local segCenterX = frameEdge + segW / 2
	for _, side in ipairs({ -1, 1 }) do
		add("FarWallSeg", side * segCenterX, H / 2, -L / 2, segW, H, 1.5, COLOR.wall, Enum.Material.Slate)
		add("DoorFrame", side * frameEdge, H / 2, -L / 2, 3, H, 3, COLOR.frame, Enum.Material.Wood)
		add("Pillar", side * frameEdge, H / 2, -L / 2 + 3, 4, H, 4, COLOR.pillar, Enum.Material.Slate)
	end
	add("Lintel", 0, (DH + H) / 2, -L / 2, DW + 6, H - DH, 1.5, COLOR.wall, Enum.Material.Slate)

	-- Дверь
	local door = add("Door", 0, DH / 2, -L / 2, DW, DH, 1.5, COLOR.door, Enum.Material.Wood)

	-- Ручка двери
	add("Handle", DW / 2 - 1.2, DH / 2, -L / 2 - 0.9, 0.4, 1.2, 0.4, Color3.fromRGB(20, 20, 25))

	-- Свечи на стенах (свет мерцает — см. flicker ниже)
	for _, side in ipairs({ -1, 1 }) do
		local candle = add("Candle", side * (W / 2 - 1), 14, 0, 1.2, 2.6, 1.2, COLOR.candle)
		candle.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Name = "LampLight"
		light.Color = Color3.fromRGB(255, 170, 90)
		light.Range = 22
		light.Brightness = 1.1
		light.Parent = candle
	end

	-- Тыквы у двери (светятся)
	for _, side in ipairs({ -1, 1 }) do
		local px = side * (W / 2 - 6)
		local pz = -(L / 2 - 6)
		local pumpkin = add("Pumpkin", px, 1.7, pz, 3.6, 3.2, 3.6, COLOR.pumpkin)
		pumpkin.Shape = Enum.PartType.Ball
		pumpkin.Material = Enum.Material.SmoothPlastic
		add("Stem", px, 3.5, pz, 0.6, 1.2, 0.6, COLOR.stem)
		local glow = Instance.new("PointLight")
		glow.Name = "LampLight"
		glow.Color = Color3.fromRGB(255, 140, 40)
		glow.Range = 11
		glow.Brightness = 0.9
		glow.Parent = pumpkin
	end

	-- Точка входа / детектор прогресса
	local pad = Instance.new("Part")
	pad.Name = "SpawnPad"
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanTouch = true
	pad.Transparency = 1
	pad.Size = toWorldSize(W - 8, 0.4, 12)
	pad.Position = toWorld(0, 0.2, L / 2 - 7)
	pad.Parent = model

	return model, door, pad
end

-- ================================================================
-- МЕРЦАНИЕ СВЕЧЕЙ (атмосфера)
-- ================================================================
local function startFlicker()
	task.spawn(function()
		local base = {}
		while true do
			local folder = workspace:FindFirstChild("Rooms")
			if folder then
				for _, light in ipairs(folder:GetDescendants()) do
					if light:IsA("PointLight") and light.Name == "LampLight" then
						if base[light] == nil then
							base[light] = light.Brightness
						end
						if math.random() < 0.03 then
							light.Brightness = base[light] * 0.15 -- испуганно мигнула
						else
							light.Brightness = base[light] * (0.82 + math.random() * 0.3)
						end
					end
				end
			end
			task.wait(0.13)
		end
	end)
end

-- ================================================================
-- СБОРКА ДОМА
-- ================================================================
function MapGen.build(config)
	local assets = ServerStorage:FindFirstChild("GameAssets")
	local template = assets and assets:FindFirstChild("RoomTemplate")
	local monsterTemplate = assets and assets:FindFirstChild("Monster")

	local roomsFolder = Instance.new("Folder")
	roomsFolder.Name = "Rooms"
	roomsFolder.Parent = workspace

	local rooms = {}

	-- Оси коридора: F = вперёд (к двери), S = вбок
	local F, S
	if config.CORRIDOR_AXIS == "X" then
		F = Vector3.new(config.CORRIDOR_DIRECTION, 0, 0)
		S = Vector3.new(0, 0, 1)
	else
		F = Vector3.new(0, 0, config.CORRIDOR_DIRECTION)
		S = Vector3.new(1, 0, 0)
	end

	local origin = Vector3.new(0, 0, 0)

	if template and not config.AUTO_BUILD_MAP then
		-- Режим 1: комнаты из шаблона игрока
		local size = template:GetExtentsSize()
		local length = math.max(size.X, size.Z)
		local basePivot = template:GetPivot()
		for i = 1, config.TOTAL_ROOMS do
			local room = template:Clone()
			room.Name = "Room" .. i
			local step = length * (i - 1) * config.CORRIDOR_DIRECTION
			local offset = (config.CORRIDOR_AXIS == "X")
				and Vector3.new(step, 0, 0)
				or Vector3.new(0, 0, step)
			room:PivotTo(basePivot + offset)
			room.Parent = roomsFolder
			local door = room:FindFirstChild("Door", true)
			local pad = room:FindFirstChild("SpawnPad", true)
			table.insert(rooms, { model = room, door = door, pad = pad })
		end
		template:Destroy()
	else
		-- Режим 2: авто-постройка красивых комнат
		for i = 1, config.TOTAL_ROOMS do
			local model, door, pad = buildAutoRoom(config, i, origin, F, S)
			model.Parent = roomsFolder
			table.insert(rooms, { model = model, door = door, pad = pad })
		end
	end

	startFlicker()

	if not monsterTemplate then
		warn("[MapGen] Шаблона Monster нет — MonsterAI соберёт запасного монстра сам.")
	end

	return rooms, monsterTemplate
end

return MapGen
