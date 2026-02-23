local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local DataService = require(Modules.DataService)
local EconomyService = require(Modules.EconomyService)
local UpgradeService = require(Modules.UpgradeService)
local ZoneService = require(Modules.ZoneService)
local BeeService = require(Modules.BeeService)
local PollinationService = require(Modules.PollinationService)

local dataService = DataService.new()
local economyService = EconomyService.new(dataService)
local upgradeService = UpgradeService.new(dataService, economyService)
local zoneService = ZoneService.new(dataService, economyService)
local beeService = BeeService.new(dataService, upgradeService, zoneService)
local pollinationService = PollinationService.new(economyService, dataService, upgradeService, zoneService)

local PLOT_COLUMNS = 4
local PLOT_SPACING = 56
local PLOT_START_Z = 28
local PLOT_BASE_SIZE = Vector3.new(40, 1, 40)
local UPGRADE_IDS = { "MoreFlowers", "SoilQuality", "HiveCapacity", "PollenBoost" }

local function ensureFolder(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then
        return existing
    end

    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function ensureRemote(remotesFolder, name)
    local remote = remotesFolder:FindFirstChild(name)
    if remote then
        return remote
    end

    remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = remotesFolder
    return remote
end

local function disableLegacyCashSystems()
    local keywords = { "cash", "collector", "drop", "money" }

    local function shouldDisable(scriptName)
        local lowered = string.lower(scriptName)
        for _, keyword in ipairs(keywords) do
            if string.find(lowered, keyword, 1, true) then
                return true
            end
        end
        return false
    end

    for _, item in ipairs(workspace:GetDescendants()) do
        if item:IsA("Script") and shouldDisable(item.Name) then
            item.Enabled = false
        end
    end

    for _, item in ipairs(ServerScriptService:GetChildren()) do
        if item:IsA("Script") and item ~= script and shouldDisable(item.Name) then
            item.Enabled = false
        end
    end
end

local function createFallbackForest(forestFolder)
    if #forestFolder:GetChildren() > 0 then
        return
    end

    for i = 1, 28 do
        local clusterCenter = Vector3.new(math.random(-145, 145), 0, math.random(-145, 145))
        local trunkHeight = math.random(8, 13)
        local trunkWidth = 1.1 + math.random() * 0.5

        local trunk = Instance.new("Part")
        trunk.Name = "TreeTrunk"
        trunk.Size = Vector3.new(trunkWidth, trunkHeight, trunkWidth)
        trunk.Anchored = true
        trunk.Color = Color3.fromRGB(125, 86, 56)
        trunk.Material = Enum.Material.Wood
        trunk.Position = clusterCenter + Vector3.new(0, trunkHeight * 0.5, 0)
        trunk.Parent = forestFolder

        local crownHeights = { 0.45, 0.7, 0.95 }
        for index, heightFactor in ipairs(crownHeights) do
            local crown = Instance.new("Part")
            crown.Name = string.format("TreeCrown_%d", index)
            crown.Shape = Enum.PartType.Ball
            crown.Size = Vector3.new(6.5, 5.5, 6.5) + Vector3.new(index * 0.8, index * 0.8, index * 0.8)
            crown.Anchored = true
            crown.Material = Enum.Material.Grass
            crown.Color = if index % 2 == 0
                then Color3.fromRGB(96, 173, 95)
                else Color3.fromRGB(76, 154, 82)
            crown.Position = trunk.Position + Vector3.new(0, trunkHeight * heightFactor + 1.8, 0)
            crown.Parent = forestFolder
        end

        if i % 3 == 0 then
            local stone = Instance.new("Part")
            stone.Name = "ForestStone"
            stone.Shape = Enum.PartType.Ball
            stone.Size = Vector3.new(1.4, 1, 1.4) + Vector3.new(math.random() * 0.8, 0, math.random() * 0.8)
            stone.Anchored = true
            stone.Material = Enum.Material.Slate
            stone.Color = Color3.fromRGB(124, 133, 130)
            stone.Position = clusterCenter + Vector3.new(math.random(-6, 6), 0.5, math.random(-6, 6))
            stone.Parent = forestFolder
        end
    end

    for i = 1, 34 do
        local bloom = Instance.new("Part")
        bloom.Name = "GroundBloom"
        bloom.Shape = Enum.PartType.Cylinder
        bloom.Size = Vector3.new(0.08, 0.85 + math.random() * 0.5, 0.85 + math.random() * 0.5)
        bloom.Anchored = true
        bloom.CanCollide = false
        bloom.Material = Enum.Material.Neon
        bloom.Color = if i % 2 == 0
            then Color3.fromRGB(255, 177, 211)
            else Color3.fromRGB(255, 226, 146)
        bloom.Orientation = Vector3.new(0, math.random(0, 360), 90)
        bloom.Position = Vector3.new(math.random(-145, 145), 0.12, math.random(-145, 145))
        bloom.Parent = forestFolder
    end
end

local function setupForestTheme()
    local forestFolder = ensureFolder(workspace, "ForestTheme")
    if #forestFolder:GetChildren() > 0 then
        return
    end

    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local forestModels = assets and assets:FindFirstChild("ForestModels")

    if forestModels and #forestModels:GetChildren() > 0 then
        for _, item in ipairs(forestModels:GetChildren()) do
            if item:IsA("Model") or item:IsA("BasePart") or item:IsA("Folder") then
                local clone = item:Clone()
                clone.Parent = forestFolder
            end
        end
        return
    end

    createFallbackForest(forestFolder)
end


local function setupBackgroundMusic()
    local existing = SoundService:FindFirstChild("BeeForestBackgroundMusic")
    if existing and existing:IsA("Sound") then
        if not existing.IsPlaying then
            existing:Play()
        end
        return
    end

    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local musicFolder = assets and assets:FindFirstChild("Music")
    local imported = musicFolder and musicFolder:FindFirstChild("BiernesDans")

    local musicSound
    if imported and imported:IsA("Sound") then
        musicSound = imported:Clone()
    else
        musicSound = Instance.new("Sound")
        musicSound.Name = "BeeForestBackgroundMusic"
        -- Roblox only supports uploaded audio asset IDs in production.
        -- Keep fallback silent rather than assigning an invalid URL SoundId.
        musicSound.SoundId = ""
    end

    musicSound.Name = "BeeForestBackgroundMusic"
    musicSound.Looped = true
    musicSound.Volume = 0.25
    musicSound.RollOffMaxDistance = 10000
    musicSound.Parent = SoundService
    if musicSound.SoundId ~= "" then
        musicSound:Play()
    end
end

local function getPlotCenterForSlot(slotIndex)
    local column = (slotIndex - 1) % PLOT_COLUMNS
    local row = math.floor((slotIndex - 1) / PLOT_COLUMNS)
    local startX = -((PLOT_COLUMNS - 1) * PLOT_SPACING) * 0.5

    return Vector3.new(
        startX + (column * PLOT_SPACING),
        0,
        PLOT_START_Z + (row * PLOT_SPACING)
    )
end

local function getNextPlotSlot(plotsFolder)
    local usedSlots = {}
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local slot = plot:GetAttribute("PlotSlot")
        if typeof(slot) == "number" then
            usedSlots[math.max(1, math.floor(slot))] = true
        end
    end

    local slotIndex = 1
    while usedSlots[slotIndex] do
        slotIndex += 1
    end

    return slotIndex
end

local function createPlotBase(parent, basePosition)
    local base = Instance.new("Part")
    base.Name = "Base"
    base.Size = PLOT_BASE_SIZE
    base.Anchored = true
    base.Material = Enum.Material.Grass
    base.Color = Color3.fromRGB(84, 168, 88)
    base.TopSurface = Enum.SurfaceType.Smooth
    base.BottomSurface = Enum.SurfaceType.Smooth
    base.Position = basePosition + Vector3.new(0, PLOT_BASE_SIZE.Y * 0.5, 0)
    base.Parent = parent
    return base
end

local function ensurePlotBase(plot)
    local base = plot:FindFirstChild("Base")
    if base and base:IsA("BasePart") then
        return base
    end

    local anyBasePart = plot:FindFirstChildWhichIsA("BasePart")
    if anyBasePart then
        return anyBasePart
    end

    local slot = plot:GetAttribute("PlotSlot")
    if typeof(slot) ~= "number" then
        slot = 1
        plot:SetAttribute("PlotSlot", slot)
    end

    return createPlotBase(plot, getPlotCenterForSlot(slot))
end

local function ensurePlayerPlot(player)
    local plots = ensureFolder(workspace, "Plots")
    local existing = plots:FindFirstChild(player.Name)
    if existing then
        if typeof(existing:GetAttribute("PlotSlot")) ~= "number" then
            existing:SetAttribute("PlotSlot", getNextPlotSlot(plots))
        end
        return existing
    end

    local slotIndex = getNextPlotSlot(plots)
    local plotCenter = getPlotCenterForSlot(slotIndex)

    local plot = Instance.new("Model")
    plot.Name = player.Name
    plot:SetAttribute("PlotSlot", slotIndex)
    plot.Parent = plots

    local base = createPlotBase(plot, plotCenter)

    local marker = Instance.new("BillboardGui")
    marker.Name = "PlotMarker"
    marker.Adornee = base
    marker.Size = UDim2.fromOffset(200, 40)
    marker.StudsOffset = Vector3.new(0, 4, 0)
    marker.AlwaysOnTop = true
    marker.Parent = base

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(255, 239, 148)
    label.TextStrokeTransparency = 0.6
    label.Text = string.format("%s Plot", player.Name)
    label.Parent = marker

    return plot
end

local function ensureLeaderstats(player)
    local profile = dataService:GetProfile(player)
    if not profile then
        return
    end

    local leaderstats = ensureFolder(player, "leaderstats")

    local coins = leaderstats:FindFirstChild("Coins") or Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = profile.Coins
    coins.Parent = leaderstats

    local zone = leaderstats:FindFirstChild("Zone") or Instance.new("IntValue")
    zone.Name = "Zone"
    zone.Value = profile.ZoneLevel
    zone.Parent = leaderstats
end

local function ensurePlotFolders(player)
    local plot = ensurePlayerPlot(player)
    if not plot then
        return
    end

    local points = ensureFolder(plot, "PollinationPoints")
    local spawns = ensureFolder(plot, "FlowerSpawnPoints")

    local anchorPart = ensurePlotBase(plot)
    local anchorPosition = anchorPart and anchorPart.Position or Vector3.new(0, 0, 0)
    local pointOffsets = {
        Vector3.new(-7, 2, -5),
        Vector3.new(0, 2, 6),
        Vector3.new(7, 2, -2),
    }
    local spawnOffsets = {
        Vector3.new(-8, 2, 5),
        Vector3.new(0, 2, 9),
        Vector3.new(8, 2, 5),
    }

    if #points:GetChildren() == 0 then
        for i, offset in ipairs(pointOffsets) do
            local point = Instance.new("Part")
            point.Name = string.format("PollinationPoint_%d", i)
            point.Size = Vector3.new(2, 1, 2)
            point.Shape = Enum.PartType.Ball
            point.Material = Enum.Material.Grass
            point.Color = Color3.fromRGB(241, 146, 255)
            point.Anchored = true
            point.CanCollide = false
            point.Position = anchorPosition + offset
            point.Parent = points
        end
    end

    if #spawns:GetChildren() == 0 then
        for i, offset in ipairs(spawnOffsets) do
            local spawn = Instance.new("Part")
            spawn.Name = string.format("FlowerSpawn_%d", i)
            spawn.Size = Vector3.new(1, 1, 1)
            spawn.Transparency = 1
            spawn.Anchored = true
            spawn.CanCollide = false
            spawn.Position = anchorPosition + offset
            spawn.Parent = spawns
        end
    end

    pollinationService:RegisterPlot(plot)
end

local remotes = ensureFolder(ReplicatedStorage, "Remotes")
local collectFlowerRemote = ensureRemote(remotes, "CollectFlower")
local buyUpgradeRemote = ensureRemote(remotes, "BuyUpgrade")
local equipBeeRemote = ensureRemote(remotes, "EquipBee")
local unlockZoneRemote = ensureRemote(remotes, "UnlockZone")
local syncStateRemote = ensureRemote(remotes, "SyncState")

local function getUpgradeState(player)
    local costs = {}
    local levels = {}

    for _, upgradeId in ipairs(UPGRADE_IDS) do
        levels[upgradeId] = upgradeService:GetUpgradeLevel(player, upgradeId)
        costs[upgradeId] = upgradeService:GetUpgradeCost(player, upgradeId) or 0
    end

    return levels, costs
end

local function syncPlayer(player)
    local profile = dataService:GetProfile(player)
    if not profile then
        return
    end

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local coins = leaderstats:FindFirstChild("Coins")
        local zone = leaderstats:FindFirstChild("Zone")
        if coins then
            coins.Value = profile.Coins
        end
        if zone then
            zone.Value = profile.ZoneLevel
        end
    end

    local upgradeLevels, upgradeCosts = getUpgradeState(player)

    syncStateRemote:FireClient(player, {
        coins = profile.Coins,
        zoneLevel = profile.ZoneLevel,
        upgrades = upgradeLevels,
        upgradeLevels = upgradeLevels,
        upgradeCosts = upgradeCosts,
        ownedBees = profile.OwnedBees,
        equippedBees = profile.EquippedBees,
        hiveCapacity = upgradeService:GetHiveCapacity(player),
        bloomSummary = pollinationService:GetBloomSummary(player),
    })
end

collectFlowerRemote.OnServerEvent:Connect(function(player, flower)
    local success, amount = pollinationService:TryCollectFlower(player, flower)
    syncStateRemote:FireClient(player, {
        success = success,
        action = "CollectFlower",
        payload = { amount = amount or 0 },
    })
    syncPlayer(player)
end)

pollinationService:SetFlowerCollectedHandler(function(player, amount)
    syncStateRemote:FireClient(player, {
        success = true,
        action = "CollectFlower",
        payload = { amount = amount or 0 },
    })
    syncPlayer(player)
end)

buyUpgradeRemote.OnServerEvent:Connect(function(player, upgradeId)
    local success, payload = upgradeService:BuyUpgrade(player, upgradeId)
    syncStateRemote:FireClient(player, { success = success, action = "BuyUpgrade", payload = payload })
    syncPlayer(player)
end)

equipBeeRemote.OnServerEvent:Connect(function(player, beeIds)
    local success, payload = beeService:SetEquippedBeeIds(player, beeIds)
    syncStateRemote:FireClient(player, { success = success, action = "EquipBee", payload = payload })
    syncPlayer(player)
end)

unlockZoneRemote.OnServerEvent:Connect(function(player)
    local success, payload = zoneService:TryUnlockNextZone(player)
    syncStateRemote:FireClient(player, { success = success, action = "UnlockZone", payload = payload })
    syncPlayer(player)
end)

local function onPlayerAdded(player)
    if not dataService:GetProfile(player) then
        dataService:LoadProfile(player)
    end

    ensureLeaderstats(player)
    ensurePlotFolders(player)

    player.CharacterAdded:Connect(function()
        beeService:GetPlayerState(player)
    end)

    task.defer(function()
        beeService:GetPlayerState(player)
        syncPlayer(player)
    end)
end

disableLegacyCashSystems()
setupForestTheme()
setupBackgroundMusic()
dataService:BindLifecycle()
beeService:Start(pollinationService)
task.spawn(function()
    while true do
        task.wait(1)
        for _, player in ipairs(Players:GetPlayers()) do
            syncPlayer(player)
        end
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    beeService:ResetPlayerState(player)
end)
