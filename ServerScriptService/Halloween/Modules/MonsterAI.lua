-- ================================================================
-- MonsterAI — монстр преследует ближайшего живого игрока.
-- Если модели Monster нет — код собирает запасного монстра сам:
-- тёмная фигура с горящими красными глазами и красным свечением.
-- Все части должны быть заякорены (Anchored = on).
-- ================================================================

local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent.GameConfig)

local MonsterAI = {}

local conn = nil
local monster = nil
local monsterTemplate = nil
local aggroPlayer = nil
local aggroUntil = 0
local hooks = nil -- {getTargets, onKill, isBlackout}

-- ---------- Запасной монстр (если нет модели из Toolbox) ----------
local function buildFallbackMonster()
	local model = Instance.new("Model")
	model.Name = "FallbackMonsterTemplate"

	local function p(name, size, pos, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Position = pos
		part.Color = color
		part.Material = material or Enum.Material.Slate
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end

	local black = Color3.fromRGB(12, 12, 16)
	local torso = p("Torso", Vector3.new(3, 7, 1.8), Vector3.new(0, 3.5, 0), black)
	p("Head", Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 8.4, 0), black)
	p("LeftArm", Vector3.new(0.9, 6.5, 0.9), Vector3.new(-2.1, 4, 0), black)
	p("RightArm", Vector3.new(0.9, 6.5, 0.9), Vector3.new(2.1, 4, 0), black)
	p("LeftLeg", Vector3.new(1.1, 3.2, 1.1), Vector3.new(-0.8, 1.6, 0), black)
	p("RightLeg", Vector3.new(1.1, 3.2, 1.1), Vector3.new(0.8, 1.6, 0), black)

	-- Горящие красные глаза (вперёд = -Z)
	local neonRed = Color3.fromRGB(255, 30, 30)
	local eyeL = p("EyeL", Vector3.new(0.5, 0.3, 0.15), Vector3.new(-0.55, 8.5, -1.25), neonRed, Enum.Material.Neon)
	local eyeR = p("EyeR", Vector3.new(0.5, 0.3, 0.15), Vector3.new(0.55, 8.5, -1.25), neonRed, Enum.Material.Neon)

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 40, 40)
	glow.Range = 14
	glow.Brightness = 0.9
	glow.Parent = torso

	model.PrimaryPart = torso
	return model
end

function MonsterAI.init(h, template)
	hooks = h
	monsterTemplate = template
	if not monsterTemplate then
		monsterTemplate = buildFallbackMonster()
		monsterTemplate.Parent = nil
	end
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
