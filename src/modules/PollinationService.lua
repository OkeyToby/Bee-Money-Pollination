local Debris = game:GetService("Debris")

local PollinationService = {}
PollinationService.__index = PollinationService

local FLOWER_LIFETIME_SECONDS = 60
local BLOOM_TARGET = 60
local MAX_ACTIVE_FLOWERS_PER_PLAYER = 6
local POINT_BASE_COLOR = Color3.fromRGB(186, 110, 220)
local POINT_READY_COLOR = Color3.fromRGB(255, 222, 96)

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
    self._onFlowerCollected = nil
    return self
end

function PollinationService:SetFlowerCollectedHandler(handler)
    self._onFlowerCollected = handler
end

function PollinationService:GetBloomSummary(player)
    local plots = workspace:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(player.Name)
    local pointsFolder = plot and plot:FindFirstChild("PollinationPoints")

    local totalBloom = 0
    local highestBloom = 0
    local pointCount = 0
    if pointsFolder then
        for _, point in ipairs(pointsFolder:GetChildren()) do
            local bloom = point:FindFirstChild("Bloom")
            if bloom and bloom:IsA("NumberValue") then
                totalBloom += bloom.Value
                highestBloom = math.max(highestBloom, bloom.Value)
                pointCount += 1
            end
        end
    end

    local averageBloom = pointCount > 0 and (totalBloom / pointCount) or 0
    return {
        bloomAveragePercent = math.floor((averageBloom / BLOOM_TARGET) * 100 + 0.5),
        bloomBestPercent = math.floor((highestBloom / BLOOM_TARGET) * 100 + 0.5),
        activeFlowers = self:GetActiveFlowerCount(player),
        bloomTarget = BLOOM_TARGET,
        flowerValue = self:GetFlowerValue(player),
    }
end

function PollinationService:GetActiveFlowerCount(player)
    local count = 0
    for _, flower in ipairs(self._flowerFolder:GetChildren()) do
        if flower:GetAttribute("OwnerUserId") == player.UserId then
            count += 1
        end
    end
    return count
end

function PollinationService:UpdatePointVisual(point)
    if not point:IsA("BasePart") then
        return
    end

    local bloom = point:FindFirstChild("Bloom")
    if not bloom or not bloom:IsA("NumberValue") then
        return
    end

    local ratio = math.clamp(bloom.Value / BLOOM_TARGET, 0, 1)
    point.Color = POINT_BASE_COLOR:Lerp(POINT_READY_COLOR, ratio)
    point.Size = Vector3.new(2, 1, 2):Lerp(Vector3.new(2.6, 1.4, 2.6), ratio)
    point.Material = ratio >= 0.95 and Enum.Material.Neon or Enum.Material.Grass

    local billboard = point:FindFirstChild("BloomStatus")
    if not billboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "BloomStatus"
        billboard.Size = UDim2.fromOffset(120, 26)
        billboard.StudsOffset = Vector3.new(0, 2.3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = point

        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "Text"
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.BackgroundTransparency = 1
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextScaled = true
        textLabel.TextStrokeTransparency = 0.6
        textLabel.Parent = billboard
    end

    local textLabel = billboard:FindFirstChild("Text")
    if textLabel and textLabel:IsA("TextLabel") then
        local percent = math.floor((bloom.Value / BLOOM_TARGET) * 100 + 0.5)
        textLabel.Text = string.format("Bloom %d%%", percent)
        textLabel.TextColor3 = POINT_BASE_COLOR:Lerp(POINT_READY_COLOR, ratio)
    end
end

function PollinationService:EnsurePoint(point)
    local bloom = point:FindFirstChild("Bloom") or Instance.new("NumberValue")
    bloom.Name = "Bloom"
    bloom.Value = math.clamp(bloom.Value, 0, BLOOM_TARGET)
    bloom.Parent = point

    local multiplier = point:FindFirstChild("BloomRateMultiplier") or Instance.new("NumberValue")
    multiplier.Name = "BloomRateMultiplier"
    multiplier.Value = multiplier.Value > 0 and multiplier.Value or 1
    multiplier.Parent = point

    if point:IsA("BasePart") then
        point.Anchored = true
        point.CanCollide = false
        point.Shape = Enum.PartType.Ball
    end

    self:UpdatePointVisual(point)
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
    if self:GetActiveFlowerCount(player) >= MAX_ACTIVE_FLOWERS_PER_PLAYER then
        return
    end

    local plots = workspace:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(player.Name)
    local spawnPart = self:GetSpawnPart(plot, point)

    local flower = Instance.new("Part")
    flower.Name = "MoneyFlower"
    flower.Shape = Enum.PartType.Ball
    flower.Size = Vector3.new(1.8, 1.8, 1.8)
    flower.Material = Enum.Material.Neon
    flower.Color = Color3.fromRGB(255, 212, 90)
    flower.Anchored = true
    flower.CanCollide = false
    flower.CFrame = spawnPart.CFrame + Vector3.new(0, 2, 0)
    flower.Parent = self._flowerFolder

    local valueObj = Instance.new("IntValue")
    valueObj.Name = "Value"
    valueObj.Value = self:GetFlowerValue(player)
    valueObj.Parent = flower

    local sparkles = Instance.new("ParticleEmitter")
    sparkles.Name = "CoinGlow"
    sparkles.Rate = 8
    sparkles.Lifetime = NumberRange.new(0.4, 0.8)
    sparkles.Speed = NumberRange.new(0.2, 0.8)
    sparkles.SpreadAngle = Vector2.new(360, 360)
    sparkles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 235, 150))
    sparkles.Parent = flower

    local valueBillboard = Instance.new("BillboardGui")
    valueBillboard.Name = "ValueBillboard"
    valueBillboard.Size = UDim2.fromOffset(120, 30)
    valueBillboard.StudsOffset = Vector3.new(0, 2.1, 0)
    valueBillboard.AlwaysOnTop = true
    valueBillboard.Parent = flower

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.fromScale(1, 1)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextScaled = true
    valueLabel.TextColor3 = Color3.fromRGB(255, 244, 170)
    valueLabel.TextStrokeTransparency = 0.6
    valueLabel.Text = string.format("+%d Coins", valueObj.Value)
    valueLabel.Parent = valueBillboard

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "Collect"
    prompt.ActionText = "Collect"
    prompt.ObjectText = "Money Flower"
    prompt.HoldDuration = 0.15
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = flower

    self._flowerOwners[flower] = player.UserId
    flower:SetAttribute("OwnerUserId", player.UserId)

    prompt.Triggered:Connect(function(triggeringPlayer)
        local success, amount = self:TryCollectFlower(triggeringPlayer, flower)
        if success and self._onFlowerCollected then
            self._onFlowerCollected(triggeringPlayer, amount)
        end
    end)

    flower.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self._flowerOwners[flower] = nil
        end
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
    if bloom.Value >= BLOOM_TARGET then
        bloom.Value -= BLOOM_TARGET
        self:SpawnMoneyFlower(player, point)
    end

    bloom.Value = math.clamp(bloom.Value, 0, BLOOM_TARGET)
    self:UpdatePointVisual(point)
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
        return false, 0
    end

    if not flower:IsDescendantOf(self._flowerFolder) then
        return false, 0
    end

    local ownerId = self._flowerOwners[flower]
    if ownerId and ownerId ~= player.UserId then
        return false, 0
    end

    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false, 0
    end

    if (root.Position - flower.Position).Magnitude > 15 then
        return false, 0
    end

    local valueObj = flower:FindFirstChild("Value")
    local amount = valueObj and valueObj.Value or 0

    if amount > 0 then
        self._economyService:AddCoins(player, amount, "MoneyFlower")
    end

    self._flowerOwners[flower] = nil
    flower:Destroy()
    return true, amount
end

return PollinationService
