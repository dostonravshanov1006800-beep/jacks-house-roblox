-- ================================================================
-- CandyManager — конфеты игроков, сохраняются в DataStore
-- (нужно включить "Enable Studio Access to API Services" в настройках игры!)
-- ================================================================

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local CandyManager = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("JacksHouse_Candy_v1")
end)

local cache = {} -- [player] = количество
local dirty = {} -- [player] = true, если несохранено

function CandyManager.get(player)
	return cache[player] or 0
end

function CandyManager.add(player, amount)
	if not player then return end
	cache[player] = (cache[player] or 0) + amount
	dirty[player] = true
	if CandyManager.onChanged then
		pcall(CandyManager.onChanged, player)
	end
end

local function load(player)
	if not store then return end
	local ok, data = pcall(function()
		return store:GetAsync("candy_" .. player.UserId)
	end)
	if ok and typeof(data) == "number" then
		cache[player] = data
		if CandyManager.onChanged then
			pcall(CandyManager.onChanged, player)
		end
	end
end

local function save(player)
	if not store or not dirty[player] or cache[player] == nil then return end
	local value = cache[player]
	dirty[player] = false
	pcall(function()
		store:UpdateAsync("candy_" .. player.UserId, function()
			return value
		end)
	end)
end

Players.PlayerAdded:Connect(function(p)
	task.spawn(load, p)
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(load, p)
end

Players.PlayerRemoving:Connect(save)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		save(p)
	end
end)

return CandyManager
