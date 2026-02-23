local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeeService = {}
BeeService.__index = BeeService

local BEE_DEFINITIONS = {
    BasicPollinator = {
        Name = "Basic Pollinator",
        Role = "Pollinator",
        Power = 2.8,
        Speed = 11,
        Rarity = "Common",
        ModelName = "BasicPollinator",
        Color = Color3.fromRGB(255, 214, 79),
    },
    SwiftWing = {
        Name = "Swift Wing",
        Role = "Speedster",
        Power = 1.7,
        Speed = 18,
        Rarity = "Rare",
        ModelName = "SwiftWing",
        Color = Color3.fromRGB(136, 220, 255),
    },
    GroveBooster = {
        Name = "Grove Booster",
        Role = "Booster",
        Power = 1.9,
        Speed = 10,
        Rarity = "Epic",
        ModelName = "GroveBooster",
        Color = Color3.fromRGB(158, 255, 128),
    },
}

local BOOSTER_RADIUS = 14
local BOOSTER_POWER_BONUS = 0.2

local function getAssetsFolder()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local bees = assets and assets:FindFirstChild("BeeModels")
    return bees
end

local function getBuzzSoundTemplate()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        return nil
    end

    local direct = assets:FindFirstChild("BeeBuzz")
    if direct and direct:IsA("Sound") and direct.SoundId ~= "" then
        return direct
    end

    local sfxFolders = { "SFX", "Sounds", "Audio" }
    for _, folderName in ipairs(sfxFolders) do
        local folder = assets:FindFirstChild(folderName)
        local sound = folder and folder:FindFirstChild("BeeBuzz")
        if sound and sound:IsA("Sound") and sound.SoundId ~= "" then
            return sound
        end
    end

    return nil
end

local function setModelPrimaryPart(model)
    if model.PrimaryPart then
        return model.PrimaryPart
    end

    local primary = model:FindFirstChildWhichIsA("BasePart", true)
    if primary then
        model.PrimaryPart = primary
    end
    return primary
end

function BeeService.new(dataService, upgradeService, zoneService)
    local self = setmetatable({}, BeeService)
    self._dataService = dataService
    self._upgradeService = upgradeService
    self._zoneService = zoneService
    self._playerBeeStates = {}
    self._heartbeatConnection = nil
    return self
end

function BeeService:GetDefinition(beeId)
    return BEE_DEFINITIONS[beeId] or BEE_DEFINITIONS.BasicPollinator
end

function BeeService:GetDefinitions()
    return BEE_DEFINITIONS
end

function BeeService:GetEquippedBeeIds(player)
    local profile = self._dataService:GetProfile(player)
    if not profile or type(profile.EquippedBees) ~= "table" then
        return { "BasicPollinator" }
    end

    return profile.EquippedBees
end

function BeeService:SetEquippedBeeIds(player, beeIds)
    if type(beeIds) ~= "table" then
        return false, "Invalid payload"
    end

    local profile = self._dataService:GetProfile(player)
    if not profile then
        return false, "Profile missing"
    end

    local capacity = self._upgradeService:GetHiveCapacity(player)
    local valid = {}
    local seen = {}

    for _, beeId in ipairs(beeIds) do
        if type(beeId) == "string" and not seen[beeId] then
            seen[beeId] = true
            for _, ownedId in ipairs(profile.OwnedBees) do
                if ownedId == beeId then
                    table.insert(valid, beeId)
                    break
                end
            end
        end

        if #valid >= capacity then
            break
        end
    end

    if #valid == 0 then
        valid = { "BasicPollinator" }
    end

    profile.EquippedBees = valid
    self:ResetPlayerState(player)
    return true, valid
end

function BeeService:ResetPlayerState(player)
    local state = self._playerBeeStates[player]
    if not state then
        return
    end

    for _, beeState in ipairs(state.bees) do
        if beeState.visual and beeState.visual.Parent then
            beeState.visual:Destroy()
        end
    end

    self._playerBeeStates[player] = nil
end

function BeeService:CreateFallbackBeeVisual(position, beeId, index)
    local definition = self:GetDefinition(beeId)
    local part = Instance.new("Part")
    part.Name = string.format("Bee_%s_%d", beeId, index)
    part.Size = Vector3.new(0.9, 0.6, 0.9)
    part.Material = Enum.Material.Neon
    part.Color = definition.Color
    part.CanCollide = false
    part.Anchored = true
    part.Position = position
    part.Parent = workspace
    return part
end

function BeeService:CreateBeeVisual(player, beeId, index)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    local spawnPos = root.Position + Vector3.new(index, 3, -2)
    local definition = self:GetDefinition(beeId)
    local beeAssets = getAssetsFolder()
    local modelTemplate = beeAssets and beeAssets:FindFirstChild(definition.ModelName)

    local visual
    if modelTemplate and modelTemplate:IsA("Model") then
        local model = modelTemplate:Clone()
        local primary = setModelPrimaryPart(model)
        if primary then
            model:PivotTo(CFrame.new(spawnPos))
            model.Parent = workspace
            visual = model
        end
    end

    if not visual then
        visual = self:CreateFallbackBeeVisual(spawnPos, beeId, index)
    end

    local attachParent = visual:IsA("Model") and (visual.PrimaryPart or setModelPrimaryPart(visual)) or visual
    if attachParent then
        local buzzTemplate = getBuzzSoundTemplate()
        if buzzTemplate then
            local sound = buzzTemplate:Clone()
            sound.Name = "Buzz"
            sound.Looped = true
            if sound.Volume <= 0 then
                sound.Volume = 0.2
            end
            sound.Parent = attachParent
            sound:Play()
        end

        local pollen = Instance.new("ParticleEmitter")
        pollen.Name = "Pollen"
        pollen.Enabled = false
        pollen.Rate = 12
        pollen.Lifetime = NumberRange.new(0.25, 0.55)
        pollen.Speed = NumberRange.new(0.3, 1)
        pollen.SpreadAngle = Vector2.new(180, 180)
        pollen.Color = ColorSequence.new(Color3.fromRGB(255, 239, 156))
        pollen.Parent = attachParent
    end

    return visual
end

function BeeService:GetVisualPosition(visual)
    if visual:IsA("Model") then
        local primary = visual.PrimaryPart or setModelPrimaryPart(visual)
        return primary and primary.Position or nil
    end
    return visual.Position
end

function BeeService:SetVisualPosition(visual, position)
    if visual:IsA("Model") then
        local primary = visual.PrimaryPart or setModelPrimaryPart(visual)
        if primary then
            visual:PivotTo(CFrame.new(position))
        end
    else
        visual.Position = position
    end
end

function BeeService:GetVisualPollenEmitter(visual)
    if visual:IsA("Model") then
        local primary = visual.PrimaryPart or setModelPrimaryPart(visual)
        return primary and primary:FindFirstChild("Pollen") or nil
    end
    return visual:FindFirstChild("Pollen")
end

function BeeService:GetPlayerState(player)
    local state = self._playerBeeStates[player]
    if state then
        return state
    end

    local bees = {}
    for index, beeId in ipairs(self:GetEquippedBeeIds(player)) do
        table.insert(bees, {
            id = beeId,
            targetPoint = nil,
            workTimer = 0,
            visual = self:CreateBeeVisual(player, beeId, index),
        })
    end

    state = { bees = bees }
    self._playerBeeStates[player] = state
    return state
end

function BeeService:GetPlot(player)
    local plots = workspace:FindFirstChild("Plots")
    return plots and plots:FindFirstChild(player.Name) or nil
end

function BeeService:GetPollinationPoints(player)
    local plot = self:GetPlot(player)
    local pointsFolder = plot and plot:FindFirstChild("PollinationPoints")
    if not pointsFolder then
        return {}
    end

    local allPoints = pointsFolder:GetChildren()
    local unlocked = self._upgradeService:GetUnlockedFlowerCount(player)
    local result = {}

    for idx = 1, math.min(unlocked, #allPoints) do
        table.insert(result, allPoints[idx])
    end

    return result
end

function BeeService:GetBoosterMultiplier(beeState, allBees)
    local visualPosition = beeState.visual and self:GetVisualPosition(beeState.visual)
    if not visualPosition then
        return 1
    end

    local bonus = 0
    for _, candidate in ipairs(allBees) do
        if candidate ~= beeState then
            local def = self:GetDefinition(candidate.id)
            if def.Role == "Booster" and candidate.visual then
                local candidatePos = self:GetVisualPosition(candidate.visual)
                if candidatePos and (candidatePos - visualPosition).Magnitude <= BOOSTER_RADIUS then
                    bonus += BOOSTER_POWER_BONUS
                end
            end
        end
    end

    return 1 + bonus
end

function BeeService:ComputeBeeContribution(player, beeState, dt, allBees)
    local definition = self:GetDefinition(beeState.id)
    local basePower = definition.Power
    local boosterMult = self:GetBoosterMultiplier(beeState, allBees)
    local pollenMult = self._upgradeService:GetPollenMultiplier(player)

    return basePower * boosterMult * pollenMult * dt
end

function BeeService:GetIdlePosition(player, index)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    local angle = (index / 5) * (math.pi * 2)
    local y = 3.5 + math.sin(time() * 2 + index) * 0.4
    return root.Position + Vector3.new(math.cos(angle) * 3.5, y, math.sin(angle) * 3.5)
end

function BeeService:StepPlayer(player, dt)
    local state = self:GetPlayerState(player)
    local points = self:GetPollinationPoints(player)
    local zoneConfig = self._zoneService:GetCurrentZoneConfig(player)
    local contributionEvents = {}

    for index, beeState in ipairs(state.bees) do
        if not beeState.visual or not beeState.visual.Parent then
            beeState.visual = self:CreateBeeVisual(player, beeState.id, index)
        end

        local visual = beeState.visual
        local visualPos = visual and self:GetVisualPosition(visual)
        if not visual or not visualPos then
            continue
        end

        if #points == 0 then
            local idlePos = self:GetIdlePosition(player, index)
            if idlePos then
                self:SetVisualPosition(visual, visualPos:Lerp(idlePos, math.clamp(dt * 4, 0, 1)))
            end
            continue
        end

        if (not beeState.targetPoint) or (not beeState.targetPoint.Parent) then
            beeState.targetPoint = points[math.random(1, #points)]
            beeState.workTimer = 0
        end

        local targetPos = beeState.targetPoint.Position + Vector3.new(0, 2.2, 0)
        local speed = self:GetDefinition(beeState.id).Speed * (zoneConfig.speedBoost or 1)
        local alpha = math.clamp((speed * dt) / math.max((visualPos - targetPos).Magnitude, 0.15), 0, 1)
        local movedPos = visualPos:Lerp(targetPos, alpha)
        self:SetVisualPosition(visual, movedPos)

        local pollenFx = self:GetVisualPollenEmitter(visual)
        if (movedPos - targetPos).Magnitude < 1.3 then
            beeState.workTimer += dt
            if pollenFx then
                pollenFx.Enabled = true
            end

            local amount = self:ComputeBeeContribution(player, beeState, dt, state.bees)
            table.insert(contributionEvents, {
                point = beeState.targetPoint,
                amount = amount,
                beeId = beeState.id,
            })

            if beeState.workTimer >= 1.5 then
                beeState.workTimer = 0
                beeState.targetPoint = points[math.random(1, #points)]
            end
        else
            if pollenFx then
                pollenFx.Enabled = false
            end
        end
    end

    return contributionEvents
end

function BeeService:Start(pollinationService)
    if self._heartbeatConnection then
        self._heartbeatConnection:Disconnect()
    end

    self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        for player in pairs(self._playerBeeStates) do
            if not player.Parent then
                self:ResetPlayerState(player)
            else
                local events = self:StepPlayer(player, dt)
                pollinationService:ProcessBeeEvents(player, events)
            end
        end
    end)
end

return BeeService
