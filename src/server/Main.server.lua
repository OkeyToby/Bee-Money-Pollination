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
local PLOT_START_Z = 115
local PLOT_BASE_SIZE = Vector3.new(40, 1, 40)

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

    for i = 1, 20 do
        local trunk = Instance.new("Part")
        trunk.Name = "TreeTrunk"
        trunk.Size = Vector3.new(1.4, 9, 1.4)
        trunk.Anchored = true
        trunk.Color = Color3.fromRGB(114, 78, 46)
        trunk.Material = Enum.Material.Wood
        trunk.Position = Vector3.new(math.random(-140, 140), 4.5, math.random(-140, 140))
        trunk.Parent = forestFolder

        local crown = Instance.new("Part")
        crown.Name = "TreeCrown"
        crown.Shape = Enum.PartType.Ball
        crown.Size = Vector3.new(8, 7, 8)
        crown.Anchored = true
        crown.Material = Enum.Material.Grass
        crown.Color = Color3.fromRGB(63, 133, 59)
        crown.Position = trunk.Position + Vector3.new(0, 7.5, 0)
        crown.Parent = forestFolder
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
    else
        warn("[Main] Missing background music asset. Import Sound to ReplicatedStorage/Assets/Music/BiernesDans")
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

    if #points:GetChildren() == 0 then
        for i = 1, 3 do
            local point = Instance.new("Part")
            point.Name = string.format("PollinationPoint_%d", i)
            point.Size = Vector3.new(2, 1, 2)
            point.Shape = Enum.PartType.Ball
            point.Material = Enum.Material.Grass
            point.Color = Color3.fromRGB(241, 146, 255)
            point.Anchored = true
            point.CanCollide = false
            point.Position = anchorPosition + Vector3.new(i * 4, 2, i * 3)
            point.Parent = points
        end
    end

    if #spawns:GetChildren() == 0 then
        for i = 1, 3 do
            local spawn = Instance.new("Part")
            spawn.Name = string.format("FlowerSpawn_%d", i)
            spawn.Size = Vector3.new(1, 1, 1)
            spawn.Transparency = 1
            spawn.Anchored = true
            spawn.CanCollide = false
            spawn.Position = anchorPosition + Vector3.new(-6 + (i * 4), 2, 6)
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

    syncStateRemote:FireClient(player, {
        coins = profile.Coins,
        zoneLevel = profile.ZoneLevel,
        upgrades = profile.Upgrades,
        ownedBees = profile.OwnedBees,
        equippedBees = profile.EquippedBees,
        hiveCapacity = upgradeService:GetHiveCapacity(player),
    })
end

collectFlowerRemote.OnServerEvent:Connect(function(player, flower)
    pollinationService:TryCollectFlower(player, flower)
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

for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    beeService:ResetPlayerState(player)
end)
