-- ================================================================
-- JACK'S HOUSE — Хэллоуин-хоррор для Roblox
-- Главный серверный скрипт. Кладётся как Script в ServerScriptService,
-- внутри папки "Halloween" рядом с папкой "Modules".
-- ================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

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

-- Проверяем, что ассеты на месте
if not ServerStorage:FindFirstChild("GameAssets") then
	warn("[Jack's House] Нет папки GameAssets в ServerStorage! Создай RoomTemplate и Monster по инструкции.")
end

local RoundManager = require(script.Parent.Modules.RoundManager)
RoundManager.start()
