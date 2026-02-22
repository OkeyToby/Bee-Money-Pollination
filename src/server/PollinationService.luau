local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PollinationConfig = require(Shared:WaitForChild("PollinationConfig"))

local PollinationService = {}
PollinationService.__index = PollinationService

type Flower = {
	model: Model,
	stem: Part,
	bloom: Part,
	nectar: number,
	maxNectar: number,
	regenRate: number,
	pollinations: number,
}

type Bee = {
	index: number,
	part: Part,
	state: string,
	sourceFlower: Flower?,
	targetFlower: Flower?,
	pollen: number,
	gatherAmount: number,
	speed: number,
	cooldown: number,
}

type PlayerRuntime = {
	slotIndex: number,
	hiveModel: Model,
	hivePart: Part,
	honeyValue: IntValue,
	pollinationsValue: IntValue,
	bees: { Bee },
}

local function lerpColor(colorA: Color3, colorB: Color3, alpha: number): Color3
	return Color3.new(
		colorA.R + (colorB.R - colorA.R) * alpha,
		colorA.G + (colorB.G - colorA.G) * alpha,
		colorA.B + (colorB.B - colorA.B) * alpha
	)
end

local function formatFlowerName(index: number): string
	return string.format("Flower_%03d", index)
end

function PollinationService.new()
	local self = setmetatable({}, PollinationService)

	self.random = Random.new()
	self.worldFolder = nil :: Folder?
	self.flowersFolder = nil :: Folder?
	self.hivesFolder = nil :: Folder?

	self.flowers = {} :: { Flower }
	self.playerData = {} :: { [Player]: PlayerRuntime }
	self.occupiedSlots = {} :: { [number]: boolean }

	self.totalPollinations = 0
	self.visualTimer = 0

	return self
end

function PollinationService:Start()
	self:_createWorld()

	Players.PlayerAdded:Connect(function(player)
		self:_addPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_removePlayer(player)
	end)

	for _, player in Players:GetPlayers() do
		self:_addPlayer(player)
	end

	RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
end

function PollinationService:_createWorld()
	local existingForest = workspace:FindFirstChild("BeeForest")
	if existingForest then
		existingForest:Destroy()
	end

	local worldFolder = Instance.new("Folder")
	worldFolder.Name = "BeeForest"
	worldFolder:SetAttribute("TotalPollinations", 0)
	worldFolder.Parent = workspace
	self.worldFolder = worldFolder

	local flowersFolder = Instance.new("Folder")
	flowersFolder.Name = "Flowers"
	flowersFolder.Parent = worldFolder
	self.flowersFolder = flowersFolder

	local hivesFolder = Instance.new("Folder")
	hivesFolder.Name = "Hives"
	hivesFolder.Parent = worldFolder
	self.hivesFolder = hivesFolder

	self.flowers = {}
	self.totalPollinations = 0
	self.visualTimer = 0

	local positions = self:_generateFlowerPositions(PollinationConfig.FlowerCount)
	for index, position in ipairs(positions) do
		table.insert(self.flowers, self:_createFlower(index, position))
	end
end

function PollinationService:_generateFlowerPositions(count: number): { Vector3 }
	local positions = {} :: { Vector3 }
	local maxAttempts = count * 35
	local attempts = 0

	while #positions < count and attempts < maxAttempts do
		attempts += 1

		local angle = self.random:NextNumber(0, math.pi * 2)
		local radiusRange = PollinationConfig.ForestRadius - PollinationConfig.ForestInnerRadius
		local radius = PollinationConfig.ForestInnerRadius + math.sqrt(self.random:NextNumber()) * radiusRange
		local candidate = PollinationConfig.ForestCenter + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		local tooClose = false
		for _, existing in ipairs(positions) do
			if (existing - candidate).Magnitude < PollinationConfig.MinFlowerSpacing then
				tooClose = true
				break
			end
		end

		if not tooClose then
			table.insert(positions, candidate)
		end
	end

	return positions
end

function PollinationService:_createFlower(index: number, worldPosition: Vector3): Flower
	local flowerModel = Instance.new("Model")
	flowerModel.Name = formatFlowerName(index)
	flowerModel.Parent = self.flowersFolder

	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Anchored = true
	stem.CanCollide = false
	stem.Material = Enum.Material.Grass
	stem.Color = Color3.fromRGB(79, 163, 68)
	stem.Size = Vector3.new(0.4, PollinationConfig.FlowerStemHeight, 0.4)
	stem.Position = worldPosition + Vector3.new(0, PollinationConfig.FlowerStemHeight * 0.5, 0)
	stem.Parent = flowerModel

	local bloom = Instance.new("Part")
	bloom.Name = "Bloom"
	bloom.Shape = Enum.PartType.Ball
	bloom.Anchored = true
	bloom.CanCollide = false
	bloom.Material = Enum.Material.SmoothPlastic
	bloom.Color = Color3.fromRGB(199, 142, 70)
	bloom.Size = Vector3.new(
		PollinationConfig.FlowerBloomBaseSize,
		PollinationConfig.FlowerBloomBaseSize,
		PollinationConfig.FlowerBloomBaseSize
	)
	bloom.Position = worldPosition + Vector3.new(0, PollinationConfig.FlowerStemHeight, 0)
	bloom.Parent = flowerModel

	local maxNectar = self.random:NextNumber(PollinationConfig.FlowerNectarMin, PollinationConfig.FlowerNectarMax)
	local flower = {
		model = flowerModel,
		stem = stem,
		bloom = bloom,
		nectar = maxNectar,
		maxNectar = maxNectar,
		regenRate = self.random:NextNumber(
			PollinationConfig.FlowerRegenPerSecondMin,
			PollinationConfig.FlowerRegenPerSecondMax
		),
		pollinations = 0,
	}

	self:_refreshFlowerVisual(flower)

	return flower
end

function PollinationService:_addPlayer(player: Player)
	if self.playerData[player] then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local honeyValue = leaderstats:FindFirstChild("Honey") :: IntValue?
	if not honeyValue then
		honeyValue = Instance.new("IntValue")
		honeyValue.Name = "Honey"
		honeyValue.Parent = leaderstats
	end
	honeyValue.Value = 0

	local pollinationsValue = leaderstats:FindFirstChild("Pollinations") :: IntValue?
	if not pollinationsValue then
		pollinationsValue = Instance.new("IntValue")
		pollinationsValue.Name = "Pollinations"
		pollinationsValue.Parent = leaderstats
	end
	pollinationsValue.Value = 0

	local slotIndex = self:_acquireSlot()
	local hivePosition = self:_calculateHivePosition(slotIndex)
	local hiveModel, hivePart = self:_createHive(player.Name, hivePosition)
	local bees = self:_createBees(hiveModel, hivePart)

	self.playerData[player] = {
		slotIndex = slotIndex,
		hiveModel = hiveModel,
		hivePart = hivePart,
		honeyValue = honeyValue,
		pollinationsValue = pollinationsValue,
		bees = bees,
	}
end

function PollinationService:_removePlayer(player: Player)
	local data = self.playerData[player]
	if not data then
		return
	end

	if data.hiveModel and data.hiveModel.Parent then
		data.hiveModel:Destroy()
	end

	self.occupiedSlots[data.slotIndex] = nil
	self.playerData[player] = nil
end

function PollinationService:_acquireSlot(): number
	local slotIndex = 1
	while self.occupiedSlots[slotIndex] do
		slotIndex += 1
	end

	self.occupiedSlots[slotIndex] = true
	return slotIndex
end

function PollinationService:_calculateHivePosition(slotIndex: number): Vector3
	local ringIndex = math.floor((slotIndex - 1) / PollinationConfig.HiveSlotsPerRing)
	local slotInRing = (slotIndex - 1) % PollinationConfig.HiveSlotsPerRing

	local angle = (slotInRing / PollinationConfig.HiveSlotsPerRing) * math.pi * 2
	local radius = PollinationConfig.HiveRingRadius + ringIndex * PollinationConfig.HiveRingSpacing

	return PollinationConfig.ForestCenter + Vector3.new(math.cos(angle) * radius, PollinationConfig.HiveSize.Y * 0.5, math.sin(angle) * radius)
end

function PollinationService:_createHive(ownerName: string, position: Vector3): (Model, Part)
	local hiveModel = Instance.new("Model")
	hiveModel.Name = string.format("%s_Hive", ownerName)
	hiveModel.Parent = self.hivesFolder

	local hivePart = Instance.new("Part")
	hivePart.Name = "Hive"
	hivePart.Anchored = true
	hivePart.Material = Enum.Material.WoodPlanks
	hivePart.Color = Color3.fromRGB(212, 170, 89)
	hivePart.Size = PollinationConfig.HiveSize
	hivePart.Position = position
	hivePart.TopSurface = Enum.SurfaceType.Smooth
	hivePart.BottomSurface = Enum.SurfaceType.Smooth
	hivePart.Parent = hiveModel

	local marker = Instance.new("BillboardGui")
	marker.Name = "OwnerMarker"
	marker.Adornee = hivePart
	marker.Size = UDim2.fromOffset(180, 40)
	marker.StudsOffset = Vector3.new(0, 4, 0)
	marker.AlwaysOnTop = true
	marker.Parent = hivePart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = string.format("%s's Apiary", ownerName)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 231, 146)
	label.TextStrokeTransparency = 0.6
	label.TextScaled = true
	label.Parent = marker

	return hiveModel, hivePart
end

function PollinationService:_createBees(hiveModel: Model, hivePart: Part): { Bee }
	local bees = {} :: { Bee }
	local beesFolder = Instance.new("Folder")
	beesFolder.Name = "Bees"
	beesFolder.Parent = hiveModel

	for beeIndex = 1, PollinationConfig.BeesPerPlayer do
		local beePart = Instance.new("Part")
		beePart.Name = string.format("Bee_%02d", beeIndex)
		beePart.Shape = Enum.PartType.Ball
		beePart.Anchored = true
		beePart.CanCollide = false
		beePart.Material = Enum.Material.Neon
		beePart.Color = Color3.fromRGB(255, 206, 69)
		beePart.Size = Vector3.new(0.8, 0.8, 0.8)
		beePart.Position = hivePart.Position
			+ Vector3.new(
				self.random:NextNumber(-2, 2),
				PollinationConfig.BeeFlightHeight + self.random:NextNumber(0, 2),
				self.random:NextNumber(-2, 2)
			)
		beePart.Parent = beesFolder

		table.insert(bees, {
			index = beeIndex,
			part = beePart,
			state = "Idle",
			sourceFlower = nil,
			targetFlower = nil,
			pollen = 0,
			gatherAmount = self.random:NextNumber(PollinationConfig.BeeGatherMin, PollinationConfig.BeeGatherMax),
			speed = self.random:NextNumber(PollinationConfig.BeeSpeedMin, PollinationConfig.BeeSpeedMax),
			cooldown = self.random:NextNumber(PollinationConfig.BeeIdleCooldownMin, PollinationConfig.BeeIdleCooldownMax),
		})
	end

	return bees
end

function PollinationService:_step(dt: number)
	if dt <= 0 then
		return
	end

	self:_regenFlowers(dt)

	for _, data in pairs(self.playerData) do
		for _, bee in ipairs(data.bees) do
			self:_stepBee(data, bee, dt)
		end
	end

	self.visualTimer += dt
	if self.visualTimer >= PollinationConfig.VisualUpdateInterval then
		self.visualTimer = 0
		for _, flower in ipairs(self.flowers) do
			self:_refreshFlowerVisual(flower)
		end
	end
end

function PollinationService:_regenFlowers(dt: number)
	for _, flower in ipairs(self.flowers) do
		flower.nectar = math.clamp(flower.nectar + flower.regenRate * dt, 0, flower.maxNectar)
	end
end

function PollinationService:_stepBee(data: PlayerRuntime, bee: Bee, dt: number)
	if bee.state == "Idle" then
		bee.cooldown -= dt
		if bee.cooldown > 0 then
			return
		end

		local sourceFlower = self:_pickFlower(nil, bee.gatherAmount)
		if sourceFlower then
			bee.sourceFlower = sourceFlower
			bee.targetFlower = nil
			bee.state = "ToSource"
		else
			bee.cooldown = PollinationConfig.BeeSearchCooldown
		end
		return
	end

	if bee.state == "ToSource" then
		local sourceFlower = bee.sourceFlower
		if not sourceFlower then
			self:_sendBeeHome(bee)
			return
		end

		local reachedFlower = self:_movePartToward(
			bee.part,
			sourceFlower.bloom.Position + Vector3.new(0, PollinationConfig.BeeFlightHeight, 0),
			bee.speed,
			dt
		)

		if reachedFlower then
			local gathered = math.min(bee.gatherAmount, sourceFlower.nectar)
			if gathered <= 0 then
				self:_sendBeeHome(bee)
				return
			end

			sourceFlower.nectar -= gathered
			bee.pollen = gathered

			local targetFlower = self:_pickFlower(sourceFlower, PollinationConfig.TargetFlowerMinNectar)
			if targetFlower then
				bee.targetFlower = targetFlower
				bee.state = "ToTarget"
			else
				self:_sendBeeHome(bee)
			end
		end

		return
	end

	if bee.state == "ToTarget" then
		local sourceFlower = bee.sourceFlower
		local targetFlower = bee.targetFlower

		if not sourceFlower or not targetFlower or bee.pollen <= 0 then
			self:_sendBeeHome(bee)
			return
		end

		local reachedTarget = self:_movePartToward(
			bee.part,
			targetFlower.bloom.Position + Vector3.new(0, PollinationConfig.BeeFlightHeight, 0),
			bee.speed,
			dt
		)

		if reachedTarget then
			self:_completePollination(data, sourceFlower, targetFlower, bee.pollen)
			bee.pollen = 0
			self:_sendBeeHome(bee)
		end

		return
	end

	if bee.state == "Returning" then
		local hiveHome = data.hivePart.Position
			+ Vector3.new(
				math.cos(bee.index * 1.7) * 2,
				PollinationConfig.BeeFlightHeight + 1 + math.sin(bee.index * 0.7),
				math.sin(bee.index * 1.7) * 2
			)
		local reachedHive = self:_movePartToward(bee.part, hiveHome, bee.speed, dt)
		if reachedHive then
			bee.state = "Idle"
			bee.cooldown = self.random:NextNumber(PollinationConfig.BeeIdleCooldownMin, PollinationConfig.BeeIdleCooldownMax)
		end
	end
end

function PollinationService:_movePartToward(part: Part, target: Vector3, speed: number, dt: number): boolean
	local offset = target - part.Position
	local distance = offset.Magnitude
	if distance < 0.001 then
		return true
	end

	local maxStep = speed * dt
	local direction = offset / distance
	local nextPosition = if distance <= maxStep then target else part.Position + direction * maxStep
	part.CFrame = CFrame.lookAt(nextPosition, nextPosition + direction)

	return distance <= maxStep
end

function PollinationService:_sendBeeHome(bee: Bee)
	bee.state = "Returning"
	bee.sourceFlower = nil
	bee.targetFlower = nil
	bee.pollen = 0
end

function PollinationService:_pickFlower(excludedFlower: Flower?, minNectar: number): Flower?
	local flowerCount = #self.flowers
	if flowerCount == 0 then
		return nil
	end

	local startIndex = self.random:NextInteger(1, flowerCount)
	for offset = 0, flowerCount - 1 do
		local index = ((startIndex + offset - 1) % flowerCount) + 1
		local flower = self.flowers[index]
		if flower ~= excludedFlower and flower.nectar >= minNectar then
			return flower
		end
	end

	return nil
end

function PollinationService:_completePollination(data: PlayerRuntime, sourceFlower: Flower, targetFlower: Flower, pollenAmount: number)
	sourceFlower.pollinations += 1
	targetFlower.pollinations += 1
	targetFlower.nectar = math.clamp(
		targetFlower.nectar + PollinationConfig.NectarBoostOnPollination,
		0,
		targetFlower.maxNectar
	)

	local honeyEarned = math.max(1, math.floor(pollenAmount * PollinationConfig.HoneyPerPollen))
	data.honeyValue.Value += honeyEarned
	data.pollinationsValue.Value += 1

	self.totalPollinations += 1
	if self.worldFolder then
		self.worldFolder:SetAttribute("TotalPollinations", self.totalPollinations)
	end
end

function PollinationService:_refreshFlowerVisual(flower: Flower)
	local nectarRatio = if flower.maxNectar > 0 then flower.nectar / flower.maxNectar else 0
	local bloomRatio = math.clamp(flower.pollinations / PollinationConfig.PollinationBloomForMax, 0, 1)

	local dryColor = Color3.fromRGB(154, 94, 56)
	local nectarColor = Color3.fromRGB(255, 223, 92)
	local pollinatedColor = Color3.fromRGB(255, 128, 171)

	local baseColor = lerpColor(dryColor, nectarColor, nectarRatio)
	flower.bloom.Color = lerpColor(baseColor, pollinatedColor, bloomRatio * 0.45)

	local bloomSize = PollinationConfig.FlowerBloomBaseSize + PollinationConfig.FlowerBloomMaxBonus * bloomRatio
	flower.bloom.Size = Vector3.new(bloomSize, bloomSize, bloomSize)

	flower.model:SetAttribute("Nectar", math.round(flower.nectar * 100) / 100)
	flower.model:SetAttribute("Pollinations", flower.pollinations)
end

return PollinationService
