-- ================================================================
-- RoundManager — сердце игры: лобби -> отсчёт -> раунд -> итоги.
-- Двери, прогресс, предатель, отключение света, награды.
-- ================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local GameConfig = require(script.Parent.GameConfig)
local CandyManager = require(script.Parent.CandyManager)
local MapGen = require(script.Parent.MapGen)
local MonsterAI = require(script.Parent.MonsterAI)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateRemote = Remotes:WaitForChild("GameState")
local KnockRemote = Remotes:WaitForChild("Knock")
local SfxRemote = Remotes:WaitForChild("Sfx")

local RoundManager = {}

local rooms = nil
local round = {
	phase = "lobby",
	players = {},
	doorsOpen = 0,
	blackout = false,
	countdown = 0,
	result = nil,
}
local knockCd = {}

-- ---------- Освещение (штатное / блэкаут) ----------
local DARK = { Brightness = 0, Ambient = Color3.fromRGB(5, 5, 12), FogEnd = 60 }
local NORMAL = { Brightness = 1.5, Ambient = Color3.fromRGB(60, 60, 75), FogEnd = 100000 }

local function applyLighting(dark)
	for k, v in pairs(dark and DARK or NORMAL) do
		Lighting[k] = v
	end
end

-- ---------- Вспомогательные ----------
local function lobbyCFrame()
	local pad = workspace:FindFirstChild("LobbySpawn")
	if pad then
		return pad.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 50, 0)
end

local function aliveList()
	local list = {}
	for player, info in pairs(round.players) do
		if info.alive and not info.won and player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function sendState(player)
	if not player.Parent then return end
	local info = round.players[player]
	local payload = {
		phase = round.phase,
		doors = round.doorsOpen,
		total = GameConfig.TOTAL_ROOMS,
		candy = CandyManager.get(player),
		isTraitor = (info and info.isTraitor) or false,
		blackout = round.blackout,
		countdown = round.countdown,
		result = round.result,
		knockCd = GameConfig.KNOCK_COOLDOWN,
	}
	GameStateRemote:FireClient(player, payload)
end

local function broadcast()
	for _, player in ipairs(Players:GetPlayers()) do
		sendState(player)
	end
end

local function resetForLobby()
	round.phase = "lobby"
	round.doorsOpen = 0
	round.blackout = false
	round.countdown = 0
	round.result = nil
	round.traitor = nil
	round.players = {}
	for _, p in ipairs(Players:GetPlayers()) do
		round.players[p] = { alive = false, progress = 0, won = false, isTraitor = false }
	end
	applyLighting(false)
	MonsterAI.stop()
end

-- ---------- Убийство и победа ----------
local function killPlayer(player)
	local info = round.players[player]
	if not info or not info.alive then return end
	info.alive = false
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.Health = 0 end
	end
	-- Предателю конфеты за жертву
	if round.traitor and round.traitor ~= player and round.traitor.Parent then
		CandyManager.add(round.traitor, GameConfig.TRAITOR_KILL_BONUS)
	end
	sendState(player)
end

local function winPlayer(player)
	local info = round.players[player]
	if not info or not info.alive or info.won then return end
	info.won = true
	info.alive = false
	CandyManager.add(player, GameConfig.SURVIVE_BONUS)
	local char = player.Character
	if char then
		char:PivotTo(lobbyCFrame())
	end
	sendState(player)
end

-- ---------- Двери и пады ----------
local function setupTouch(rooms)
	for i, room in ipairs(rooms) do
		if room.door then
			room.door.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if not player or round.phase ~= "running" then return end
				local info = round.players[player]
				if not info or not info.alive then return end
				if i ~= round.doorsOpen + 1 then return end -- следующая по порядку

				if i == GameConfig.TOTAL_ROOMS then
					-- Финальная дверь = ВЫХОД
					winPlayer(player)
					return
				end

				room.door.CanCollide = false
				room.door.Transparency = 1
				round.doorsOpen = i
				broadcast()
			end)
		end

		if room.pad then
			room.pad.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if not player or round.phase ~= "running" then return end
				local info = round.players[player]
				if not info or not info.alive then return end
				if i > info.progress then
					local reward = (i - info.progress) * GameConfig.DOOR_CANDY
					info.progress = i
					CandyManager.add(player, reward)
					sendState(player)
				end
			end)
		end
	end
end

-- ---------- Способность предателя: СТУК ----------
KnockRemote.OnServerEvent:Connect(function(player)
	if round.phase ~= "running" then return end
	local info = round.players[player]
	if not info or not info.isTraitor or not info.alive then return end
	local now = os.clock()
	if (knockCd[player] or 0) > now then return end
	knockCd[player] = now + GameConfig.KNOCK_COOLDOWN

	local others = {}
	for _, other in ipairs(aliveList()) do
		if other ~= player then table.insert(others, other) end
	end
	if #others == 0 then return end

	local victim = others[math.random(#others)]
	MonsterAI.setAggro(victim, GameConfig.KNOCK_AGGRO_SECONDS)
	SfxRemote:FireAllClients({ type = "knock" })
end)

-- ---------- Старт раунда ----------
local function startRound()
	local participants = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and p.Character.PrimaryPart then
			table.insert(participants, p)
		end
	end
	if #participants == 0 then return false end

	round.phase = "running"
	round.doorsOpen = 0
	round.blackout = false
	round.result = nil
	round.startedAt = os.clock()
	round.nextBlackoutAt = os.clock() + GameConfig.BLACKOUT_INTERVAL
	round.players = {}

	for _, p in ipairs(participants) do
		round.players[p] = { alive = true, progress = 0, won = false, isTraitor = false }
	end

	-- Предатель выбирается только при 3+ игроках
	round.traitor = nil
	if #participants >= GameConfig.MIN_TRAITOR_PLAYERS then
		round.traitor = participants[math.random(#participants)]
		round.players[round.traitor].isTraitor = true
	end

	-- Все в первую комнату
	local startCF = rooms[1].pad and rooms[1].pad.CFrame or rooms[1].model:GetPivot()
	for _, p in ipairs(participants) do
		local offset = Vector3.new(math.random(-6, 6), 4, math.random(-6, 6))
		p.Character:PivotTo(startCF + offset)
	end

	broadcast()
	return true
end

-- ---------- Игроки заходят/выходят ----------
Players.PlayerAdded:Connect(function(p)
	task.wait(1)
	if round.players[p] == nil then
		round.players[p] = { alive = false, progress = 0, won = false, isTraitor = false }
	end
	sendState(p)
end)

Players.PlayerRemoving:Connect(function(p)
	round.players[p] = nil
	knockCd[p] = nil
end)

CandyManager.onChanged = function(player)
	sendState(player)
end

-- ---------- Главный цикл ----------
function RoundManager.start()
	local monsterTemplate
	rooms, monsterTemplate = MapGen.build(GameConfig)
	setupTouch(rooms)

	MonsterAI.init({
		getTargets = aliveList,
		onKill = killPlayer,
		isBlackout = function() return round.blackout end,
	}, monsterTemplate)

	applyLighting(false)

	task.spawn(function()
		while true do
			-- ЛОББИ: ждём игроков
			resetForLobby()
			broadcast()
			while #Players:GetPlayers() < GameConfig.MIN_PLAYERS do
				task.wait(2)
			end

			-- ОТСЧЁТ
			round.phase = "waiting"
			for t = GameConfig.LOBBY_WAIT, 1, -1 do
				round.countdown = t
				broadcast()
				task.wait(1)
				if #Players:GetPlayers() < GameConfig.MIN_PLAYERS then
					break
				end
			end

			if #Players:GetPlayers() < GameConfig.MIN_PLAYERS then
				round.phase = "lobby"
				broadcast()
				task.wait(2)
				continue
			end

			-- РАУНД
			if not startRound() then continue end

			while round.phase == "running" do
				task.wait(1)
				local now = os.clock()

				-- Блэкаут-таймер
				if not round.blackout and now >= round.nextBlackoutAt then
					round.blackout = true
					round.blackoutUntil = now + GameConfig.BLACKOUT_DURATION
					round.nextBlackoutAt = round.blackoutUntil + GameConfig.BLACKOUT_INTERVAL
					applyLighting(true)
					SfxRemote:FireAllClients({ type = "blackout" })
					broadcast()
				elseif round.blackout and now >= round.blackoutUntil then
					round.blackout = false
					applyLighting(false)
					broadcast()
				end

				-- Монстр просыпается после нужной двери
				if not MonsterAI.isSpawned() and round.doorsOpen >= GameConfig.MONSTER_SPAWN_AFTER_DOOR then
					local spawnRoom = rooms[math.max(1, round.doorsOpen)]
					local cf = (spawnRoom.pad and spawnRoom.pad.CFrame or spawnRoom.model:GetPivot())
						+ Vector3.new(0, 2, 0)
					MonsterAI.spawn(cf)
					SfxRemote:FireAllClients({ type = "monster" })
				end

				-- Конец раунда?
				local alive = aliveList()
				local someonePlaying = #alive > 0
				local anyAlive = false
				for _, info in pairs(round.players) do
					if info.alive or info.won then anyAlive = true end
				end

				if not anyAlive then
					round.phase = "ended"
					round.result = "all_dead"
				elseif not someonePlaying then
					round.phase = "ended"
					round.result = "escaped"
				elseif now - round.startedAt > GameConfig.ROUND_TIME then
					round.phase = "ended"
					round.result = "timeout"
					for _, p in ipairs(aliveList()) do
						-- время вышло: кто не успел — не победил
						round.players[p].alive = false
					end
				end

				if round.phase == "ended" then
					MonsterAI.stop()
					applyLighting(false)
					round.phase = "results"
					broadcast()
				end
			end

			-- ИТОГИ: 6 секунд и по новой
			task.wait(6)
		end
	end)
end

return RoundManager
