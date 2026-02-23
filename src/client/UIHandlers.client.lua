local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local existingGui = playerGui:FindFirstChild("BeeForestUI")
if existingGui then
    existingGui:Destroy()
end

local state = {
    coins = 0,
    zoneLevel = 1,
    ownedBees = {},
    equippedBees = {},
    hiveCapacity = 2,
    upgradeLevels = {},
    upgradeCosts = {},
    bloomSummary = {
        bloomAveragePercent = 0,
        bloomBestPercent = 0,
        activeFlowers = 0,
        flowerValue = 20,
    },
}

local UPGRADE_ORDER = { "MoreFlowers", "SoilQuality", "HiveCapacity", "PollenBoost" }
local UPGRADE_DISPLAY = {
    MoreFlowers = "More Flowers",
    SoilQuality = "Soil Quality",
    HiveCapacity = "Hive Capacity",
    PollenBoost = "Pollen Boost",
}

local function formatNumber(value)
    local text = tostring(math.floor(value))
    local withCommas = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return withCommas:gsub("^,", "")
end

local function waitForRemote(remotes, remoteName)
    if not remotes then
        return nil
    end

    local remote = remotes:WaitForChild(remoteName, 10)
    if remote and remote:IsA("RemoteEvent") then
        return remote
    end

    return nil
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
local buyUpgrade = waitForRemote(remotes, "BuyUpgrade")
local equipBee = waitForRemote(remotes, "EquipBee")
local unlockZone = waitForRemote(remotes, "UnlockZone")
local syncState = waitForRemote(remotes, "SyncState")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BeeForestUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local statsPanel = Instance.new("Frame")
statsPanel.Name = "StatsPanel"
statsPanel.Position = UDim2.fromOffset(14, 12)
statsPanel.Size = UDim2.fromOffset(330, 240)
statsPanel.BackgroundColor3 = Color3.fromRGB(28, 46, 33)
statsPanel.BorderSizePixel = 0
statsPanel.Parent = screenGui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 10)
statsCorner.Parent = statsPanel

local statsPadding = Instance.new("UIPadding")
statsPadding.PaddingTop = UDim.new(0, 10)
statsPadding.PaddingBottom = UDim.new(0, 10)
statsPadding.PaddingLeft = UDim.new(0, 10)
statsPadding.PaddingRight = UDim.new(0, 10)
statsPadding.Parent = statsPanel

local statsLayout = Instance.new("UIListLayout")
statsLayout.Padding = UDim.new(0, 6)
statsLayout.FillDirection = Enum.FillDirection.Vertical
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Parent = statsPanel

local function makeInfoLabel(text, sizeY)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, sizeY)
    label.BackgroundColor3 = Color3.fromRGB(46, 73, 53)
    label.BorderSizePixel = 0
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(244, 247, 224)
    label.TextScaled = true
    label.Text = text
    label.Parent = statsPanel

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = label

    return label
end

local titleLabel = makeInfoLabel("Bee Forest Tycoon", 34)
titleLabel.BackgroundColor3 = Color3.fromRGB(58, 88, 66)
titleLabel.TextColor3 = Color3.fromRGB(255, 240, 167)

local coinsLabel = makeInfoLabel("Coins: 0", 30)
local zoneLabel = makeInfoLabel("Zone: 1", 30)
local bloomAverageLabel = makeInfoLabel("Average Bloom: 0%", 26)
local bloomBestLabel = makeInfoLabel("Best Bloom: 0%", 26)
local activeFlowersLabel = makeInfoLabel("Active Money Flowers: 0", 26)
local flowerValueLabel = makeInfoLabel("Flower Value: +20 Coins", 26)

local feedbackLabel = Instance.new("TextLabel")
feedbackLabel.Name = "Feedback"
feedbackLabel.Position = UDim2.fromOffset(14, 258)
feedbackLabel.Size = UDim2.fromOffset(580, 34)
feedbackLabel.BackgroundTransparency = 1
feedbackLabel.Font = Enum.Font.GothamBold
feedbackLabel.TextColor3 = Color3.fromRGB(255, 235, 161)
feedbackLabel.TextXAlignment = Enum.TextXAlignment.Left
feedbackLabel.TextScaled = true
feedbackLabel.Text = ""
feedbackLabel.Parent = screenGui

local actionsPanel = Instance.new("Frame")
actionsPanel.Name = "ActionsPanel"
actionsPanel.AnchorPoint = Vector2.new(1, 0)
actionsPanel.Position = UDim2.new(1, -14, 0, 12)
actionsPanel.Size = UDim2.fromOffset(310, 462)
actionsPanel.BackgroundColor3 = Color3.fromRGB(36, 37, 45)
actionsPanel.BorderSizePixel = 0
actionsPanel.Parent = screenGui

local actionsCorner = Instance.new("UICorner")
actionsCorner.CornerRadius = UDim.new(0, 10)
actionsCorner.Parent = actionsPanel

local actionsPadding = Instance.new("UIPadding")
actionsPadding.PaddingTop = UDim.new(0, 10)
actionsPadding.PaddingBottom = UDim.new(0, 10)
actionsPadding.PaddingLeft = UDim.new(0, 10)
actionsPadding.PaddingRight = UDim.new(0, 10)
actionsPadding.Parent = actionsPanel

local actionsLayout = Instance.new("UIListLayout")
actionsLayout.Padding = UDim.new(0, 7)
actionsLayout.FillDirection = Enum.FillDirection.Vertical
actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionsLayout.Parent = actionsPanel

local function makeButton(text)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 36)
    button.BackgroundColor3 = Color3.fromRGB(229, 194, 99)
    button.TextColor3 = Color3.fromRGB(38, 34, 29)
    button.Font = Enum.Font.GothamBold
    button.TextScaled = true
    button.Text = text
    button.AutoButtonColor = true
    button.Parent = actionsPanel

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    return button
end

local actionsTitle = Instance.new("TextLabel")
actionsTitle.Size = UDim2.new(1, 0, 0, 32)
actionsTitle.BackgroundColor3 = Color3.fromRGB(59, 58, 75)
actionsTitle.TextColor3 = Color3.fromRGB(255, 241, 184)
actionsTitle.BorderSizePixel = 0
actionsTitle.Font = Enum.Font.GothamBold
actionsTitle.TextScaled = true
actionsTitle.Text = "Actions & Upgrades"
actionsTitle.Parent = actionsPanel

local actionsTitleCorner = Instance.new("UICorner")
actionsTitleCorner.CornerRadius = UDim.new(0, 8)
actionsTitleCorner.Parent = actionsTitle

local unlockZoneButton = makeButton("Unlock Next Zone")
local equipBasicButton = makeButton("Equip Basic Pollinator")
local equipSpeedButton = makeButton("Equip Swift Wing")
local equipBoosterButton = makeButton("Equip Grove Booster")

local upgradeButtons = {
    MoreFlowers = makeButton(""),
    SoilQuality = makeButton(""),
    HiveCapacity = makeButton(""),
    PollenBoost = makeButton(""),
}

local function setFeedback(text, color)
    feedbackLabel.Text = text
    if color then
        feedbackLabel.TextColor3 = color
    end
end

local function showCoinPopup(amount)
    local popup = Instance.new("TextLabel")
    popup.AnchorPoint = Vector2.new(0.5, 1)
    popup.Position = UDim2.fromScale(0.5, 0.84)
    popup.Size = UDim2.fromOffset(240, 54)
    popup.BackgroundTransparency = 1
    popup.Font = Enum.Font.GothamBlack
    popup.TextScaled = true
    popup.TextStrokeTransparency = 0.5
    popup.TextColor3 = Color3.fromRGB(255, 242, 152)
    popup.Text = string.format("+%s Coins", formatNumber(amount))
    popup.Parent = screenGui

    local travelTween = TweenService:Create(
        popup,
        TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position = popup.Position - UDim2.fromOffset(0, 70),
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        }
    )
    travelTween:Play()
    travelTween.Completed:Connect(function()
        if popup and popup.Parent then
            popup:Destroy()
        end
    end)
end

local function hasOwnedBee(beeId)
    for _, ownedId in ipairs(state.ownedBees) do
        if ownedId == beeId then
            return true
        end
    end
    return false
end

local function updateInfoLabels()
    coinsLabel.Text = string.format("Coins: %s", formatNumber(state.coins))
    zoneLabel.Text = string.format("Zone: %d", state.zoneLevel)

    local bloomSummary = state.bloomSummary
    bloomAverageLabel.Text = string.format("Average Bloom: %d%%", bloomSummary.bloomAveragePercent or 0)
    bloomBestLabel.Text = string.format("Best Bloom: %d%%", bloomSummary.bloomBestPercent or 0)
    activeFlowersLabel.Text = string.format("Active Money Flowers: %d", bloomSummary.activeFlowers or 0)
    flowerValueLabel.Text = string.format("Flower Value: +%s Coins", formatNumber(bloomSummary.flowerValue or 0))
end

local function updateUpgradeButtons()
    for _, upgradeId in ipairs(UPGRADE_ORDER) do
        local button = upgradeButtons[upgradeId]
        local displayName = UPGRADE_DISPLAY[upgradeId] or upgradeId
        local level = state.upgradeLevels[upgradeId] or 0
        local cost = state.upgradeCosts[upgradeId] or 0
        button.Text = string.format("%s  Lv.%d  ($%s)", displayName, level, formatNumber(cost))
    end
end

local function tryEquipBee(beeId)
    if not hasOwnedBee(beeId) then
        setFeedback("You do not own that bee yet.", Color3.fromRGB(255, 177, 177))
        return
    end

    local equipped = table.clone(state.equippedBees)
    local exists = false

    for _, candidate in ipairs(equipped) do
        if candidate == beeId then
            exists = true
            break
        end
    end

    if not exists then
        if #equipped >= state.hiveCapacity then
            table.remove(equipped, 1)
        end
        table.insert(equipped, beeId)
    end

    equipBee:FireServer(equipped)
end

if not (buyUpgrade and equipBee and unlockZone and syncState) then
    setFeedback("Server remotes mangler. Rejoin eller check server errors.", Color3.fromRGB(255, 177, 177))
    updateInfoLabels()
    updateUpgradeButtons()
    return
end

equipBasicButton.MouseButton1Click:Connect(function()
    tryEquipBee("BasicPollinator")
end)

equipSpeedButton.MouseButton1Click:Connect(function()
    tryEquipBee("SwiftWing")
end)

equipBoosterButton.MouseButton1Click:Connect(function()
    tryEquipBee("GroveBooster")
end)

unlockZoneButton.MouseButton1Click:Connect(function()
    unlockZone:FireServer()
end)

for upgradeId, button in pairs(upgradeButtons) do
    button.MouseButton1Click:Connect(function()
        buyUpgrade:FireServer(upgradeId)
    end)
end

local leaderstats = player:WaitForChild("leaderstats", 20)
if leaderstats then
    local coinsValue = leaderstats:FindFirstChild("Coins")
    if coinsValue and coinsValue:IsA("IntValue") then
        state.coins = coinsValue.Value
        coinsValue:GetPropertyChangedSignal("Value"):Connect(function()
            state.coins = coinsValue.Value
            updateInfoLabels()
        end)
    end

    local zoneValue = leaderstats:FindFirstChild("Zone")
    if zoneValue and zoneValue:IsA("IntValue") then
        state.zoneLevel = zoneValue.Value
        zoneValue:GetPropertyChangedSignal("Value"):Connect(function()
            state.zoneLevel = zoneValue.Value
            updateInfoLabels()
        end)
    end
end

syncState.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then
        return
    end

    if payload.coins ~= nil then
        state.coins = payload.coins
    end
    if payload.zoneLevel ~= nil then
        state.zoneLevel = payload.zoneLevel
    end
    if type(payload.equippedBees) == "table" then
        state.equippedBees = payload.equippedBees
    end
    if type(payload.ownedBees) == "table" then
        state.ownedBees = payload.ownedBees
    end
    if payload.hiveCapacity ~= nil then
        state.hiveCapacity = payload.hiveCapacity
    end
    if type(payload.upgradeLevels) == "table" then
        state.upgradeLevels = payload.upgradeLevels
    elseif type(payload.upgrades) == "table" then
        state.upgradeLevels = payload.upgrades
    end
    if type(payload.upgradeCosts) == "table" then
        state.upgradeCosts = payload.upgradeCosts
    end
    if type(payload.bloomSummary) == "table" then
        state.bloomSummary = payload.bloomSummary
    end

    if payload.action == "CollectFlower" then
        local amount = payload.payload and payload.payload.amount or 0
        if payload.success then
            setFeedback(string.format("Collected +%s Coins", formatNumber(amount)), Color3.fromRGB(168, 255, 168))
            if amount > 0 then
                showCoinPopup(amount)
            end
        else
            setFeedback("Could not collect that flower.", Color3.fromRGB(255, 177, 177))
        end
    elseif payload.action == "BuyUpgrade" then
        if payload.success then
            setFeedback("Upgrade purchased.", Color3.fromRGB(168, 255, 168))
        else
            setFeedback("Upgrade failed: not enough coins or max level.", Color3.fromRGB(255, 177, 177))
        end
    elseif payload.action == "EquipBee" then
        if payload.success then
            setFeedback("Bee loadout updated.", Color3.fromRGB(168, 255, 168))
        else
            setFeedback("Could not equip bee.", Color3.fromRGB(255, 177, 177))
        end
    elseif payload.action == "UnlockZone" then
        if payload.success then
            setFeedback("Zone unlocked.", Color3.fromRGB(168, 255, 168))
        else
            setFeedback("Zone unlock failed.", Color3.fromRGB(255, 177, 177))
        end
    end

    updateInfoLabels()
    updateUpgradeButtons()
end)

updateInfoLabels()
updateUpgradeButtons()
