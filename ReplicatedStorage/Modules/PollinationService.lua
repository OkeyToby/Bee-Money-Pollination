local Debris = game:GetService("Debris")

local PollinationService = {}
PollinationService.__index = PollinationService

local FLOWER_LIFETIME_SECONDS = 60

function PollinationService.new(economyService, dataService, upgradeService, zoneService)
    local self = setmetatable({}, PollinationService)
    self._economyService = economyService
    self._dataService = dataService
    self._upgradeService = upgradeService
    self._zoneService = zoneService
    self._flowerFolder = workspace:FindFirstChild("MoneyFlowers") or Instance.new("Folder")
    self._flowerFolder.Name = "MoneyFlowers"
    self._flowerFolder.Parent = workspace
    self._flowerOwners = {}
    return self
end

function PollinationService:EnsurePoint(point)
    local bloom = point:FindFirstChild("Bloom") or Instance.new("NumberValue")
    bloom.Name = "Bloom"
    bloom.Value = math.clamp(bloom.Value, 0, 100)
    bloom.Parent = point

    local multiplier = point:FindFirstChild("BloomRateMultiplier") or Instance.new("NumberValue")
    multiplier.Name = "BloomRateMultiplier"
    multiplier.Value = multiplier.Value > 0 and multiplier.Value or 1
    multiplier.Parent = point
end

function PollinationService:RegisterPlot(plot)
    local pointsFolder = plot:FindFirstChild("PollinationPoints")
    if not pointsFolder then
        return
    end

    for _, point in ipairs(pointsFolder:GetChildren()) do
        self:EnsurePoint(point)
    end
end

function PollinationService:GetFlowerValue(player)
    local baseValue = 20
    local soilMult = self._upgradeService:GetSoilMultiplier(player)
    local zoneMult = self._zoneService:GetCurrentZoneConfig(player).flowerValueMultiplier or 1
    return math.floor(baseValue * soilMult * zoneMult)
end

function PollinationService:GetSpawnPart(plot, point)
    local spawnFolder = plot and plot:FindFirstChild("FlowerSpawnPoints")
    if spawnFolder and #spawnFolder:GetChildren() > 0 then
        local options = spawnFolder:GetChildren()
        return options[math.random(1, #options)]
    end

    return point
end

function PollinationService:SpawnMoneyFlower(player, point)
    local plots = workspace:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(player.Name)
    local spawnPart = self:GetSpawnPart(plot, point)

    local flower = Instance.new("Part")
    flower.Name = "MoneyFlower"
    flower.Shape = Enum.PartType.Ball
    flower.Size = Vector3.new(1.8, 1.8, 1.8)
    flower.Material = Enum.Material.Grass
    flower.Color = Color3.fromRGB(255, 228, 94)
    flower.Anchored = true
    flower.CanCollide = false
    flower.CFrame = spawnPart.CFrame + Vector3.new(0, 2, 0)
    flower.Parent = self._flowerFolder

    local valueObj = Instance.new("IntValue")
    valueObj.Name = "Value"
    valueObj.Value = self:GetFlowerValue(player)
    valueObj.Parent = flower

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "Collect"
    prompt.ActionText = "Collect"
    prompt.ObjectText = "Money Flower"
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = flower

    self._flowerOwners[flower] = player.UserId

    prompt.Triggered:Connect(function(triggeringPlayer)
        self:TryCollectFlower(triggeringPlayer, flower)
    end)

    Debris:AddItem(flower, FLOWER_LIFETIME_SECONDS)
end

function PollinationService:IncrementBloom(player, point, amount)
    if typeof(point) ~= "Instance" or not point:IsDescendantOf(workspace) then
        return
    end

    self:EnsurePoint(point)

    local bloom = point:FindFirstChild("Bloom")
    local multiplier = point:FindFirstChild("BloomRateMultiplier")

    bloom.Value += amount * multiplier.Value
    if bloom.Value >= 100 then
        bloom.Value = 0
        self:SpawnMoneyFlower(player, point)
    end
end

function PollinationService:ProcessBeeEvents(player, events)
    local profile = self._dataService:GetProfile(player)
    if not profile then
        return
    end

    for _, event in ipairs(events) do
        self:IncrementBloom(player, event.point, event.amount)
        profile.LifetimePollination += math.floor(event.amount)
    end
end

function PollinationService:TryCollectFlower(player, flower)
    if typeof(flower) ~= "Instance" or flower.Name ~= "MoneyFlower" then
        return false
    end

    if not flower:IsDescendantOf(self._flowerFolder) then
        return false
    end

    local ownerId = self._flowerOwners[flower]
    if ownerId and ownerId ~= player.UserId then
        return false
    end

    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end

    if (root.Position - flower.Position).Magnitude > 15 then
        return false
    end

    local valueObj = flower:FindFirstChild("Value")
    local amount = valueObj and valueObj.Value or 0

    if amount > 0 then
        self._economyService:AddCoins(player, amount, "MoneyFlower")
    end

    self._flowerOwners[flower] = nil
    flower:Destroy()
    return true
end

return PollinationService
