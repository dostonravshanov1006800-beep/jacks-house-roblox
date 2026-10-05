-- ================================================================
-- MonsterAI — монстр преследует ближайшего живого игрока.
-- Все части модели монстра должны быть заякорены (Anchored = on).
-- Управление через PivotTo — никакой физики, чистое движение.
-- ================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local GameConfig = require(script.Parent.GameConfig)

local MonsterAI = {}

local conn = nil
local monster = nil
local monsterTemplate = nil
local aggroPlayer = nil
local aggroUntil = 0
local hooks = nil -- {getTargets, onKill, isBlackout}

function MonsterAI.init(h, template)
	hooks = h
	monsterTemplate = template
end

-- Предатель "постучал" — монстр переключается на жертву
function MonsterAI.setAggro(player, seconds)
	aggroPlayer = player
	aggroUntil = os.clock() + seconds
end

function MonsterAI.spawn(cframe)
	MonsterAI.stop()
	if not monsterTemplate then
		warn("[MonsterAI] Нет шаблона монстра!")
		return
	end
	monster = monsterTemplate:Clone()
	monster.Name = "ActiveMonster"
	monster.Parent = workspace
	monster:PivotTo(cframe)

	conn = RunService.Heartbeat:Connect(function(dt)
		MonsterAI._step(dt)
	end)
end

function MonsterAI.stop()
	if conn then conn:Disconnect() conn = nil end
	if monster then monster:Destroy() monster = nil end
	aggroPlayer = nil
end

function MonsterAI.isSpawned()
	return monster ~= nil
end

function MonsterAI._step(dt)
	if not monster or not hooks then return end

	local pivot = monster:GetPivot()
	local pos = pivot.Position

	-- Цель: аггро-игрок, иначе ближайший живой
	local targetPos = nil
	local now = os.clock()

	if aggroPlayer and now < aggroUntil and aggroPlayer.Parent then
		local char = aggroPlayer.Character
		if char and char.PrimaryPart then
			targetPos = char.PrimaryPart.Position
		end
	end

	if not targetPos then
		local bestDist = math.huge
		for _, p in ipairs(hooks.getTargets()) do
			local char = p.Character
			if char and char.PrimaryPart then
				local d = char.PrimaryPart.Position - pos
				local dist = Vector2.new(d.X, d.Z).Magnitude
				if dist < bestDist then
					bestDist = dist
					targetPos = char.PrimaryPart.Position
				end
			end
		end
	end

	if not targetPos then return end

	local dx = targetPos.X - pos.X
	local dz = targetPos.Z - pos.Z
	local dist = Vector2.new(dx, dz).Magnitude

	-- Убийство
	if dist < GameConfig.KILL_RADIUS then
		for _, p in ipairs(hooks.getTargets()) do
			local char = p.Character
			if char and char.PrimaryPart then
				local d = char.PrimaryPart.Position - pos
				if Vector2.new(d.X, d.Z).Magnitude < GameConfig.KILL_RADIUS then
					hooks.onKill(p)
				end
			end
		end
	end

	-- Движение (только по горизонтали, высота монстра неизменна)
	if dist > 1 then
		local speed = hooks.isBlackout() and GameConfig.MONSTER_FAST_SPEED or GameConfig.MONSTER_SLOW_SPEED
		local step = math.min(speed * dt, dist)
		local dir = Vector2.new(dx, dz).Unit
		local newPos = Vector3.new(pos.X + dir.X * step, pos.Y, pos.Z + dir.Y * step)
		monster:PivotTo(CFrame.lookAt(newPos, Vector3.new(targetPos.X, newPos.Y, targetPos.Z)))
	end
end

return MonsterAI
