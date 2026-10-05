-- ================================================================
-- MapGen — строит дом из ОДНОГО шаблона комнаты:
-- клонирует RoomTemplate TOTAL_ROOMS раз в линию (коридор).
-- Шаблоны лежат в ServerStorage.GameAssets.
-- ================================================================

local ServerStorage = game:GetService("ServerStorage")

local MapGen = {}

function MapGen.build(config)
	local assets = ServerStorage:WaitForChild("GameAssets", 10)
	if not assets then
		error("[MapGen] ServerStorage.GameAssets не найден!")
	end

	local template = assets:WaitForChild("RoomTemplate")
	local monsterTemplate = assets:FindFirstChild("Monster")
	if not monsterTemplate then
		warn("[MapGen] Модель Monster не найдена в GameAssets — монстр не появится!")
	end

	-- Длина шаблона по длинной стороне = шаг коридора
	local size = template:GetExtentsSize()
	local length = math.max(size.X, size.Z)

	local basePivot = template:GetPivot()

	local roomsFolder = Instance.new("Folder")
	roomsFolder.Name = "Rooms"
	roomsFolder.Parent = workspace

	local rooms = {}
	for i = 1, config.TOTAL_ROOMS do
		local room = template:Clone()
		room.Name = "Room" .. i

		local step = length * (i - 1) * config.CORRIDOR_DIRECTION
		local offset
		if config.CORRIDOR_AXIS == "X" then
			offset = Vector3.new(step, 0, 0)
		else
			offset = Vector3.new(0, 0, step)
		end

		room:PivotTo(basePivot + offset)
		room.Parent = roomsFolder

		local door = room:FindFirstChild("Door", true)
		local pad = room:FindFirstChild("SpawnPad", true)
		if not door then warn("[MapGen] В Room" .. i .. " нет части с именем Door!")
		elseif not pad then warn("[MapGen] В Room" .. i .. " нет части с именем SpawnPad!") end

		table.insert(rooms, { model = room, door = door, pad = pad })
	end

	-- Сам шаблон больше не нужен — удаляем, чтобы не висил дублем
	template:Destroy()

	return rooms, monsterTemplate
end

return MapGen
