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

local UI_PALETTE = {
    StatsPanel = Color3.fromRGB(41, 63, 56),
    StatsCard = Color3.fromRGB(62, 88, 78),
    ActionsPanel = Color3.fromRGB(68, 62, 79),
    ActionsTitle = Color3.fromRGB(88, 80, 104),
    AccentGold = Color3.fromRGB(245, 214, 126),
    AccentHoney = Color3.fromRGB(255, 235, 168),
    AccentRose = Color3.fromRGB(255, 191, 224),
    AccentMint = Color3.fromRGB(176, 237, 201),
    TextLight = Color3.fromRGB(245, 248, 232),
    TextDark = Color3.fromRGB(42, 36, 31),
    Error = Color3.fromRGB(255, 177, 177),
}

local SUCCESS_COLOR = UI_PALETTE.AccentMint
local ERROR_COLOR = UI_PALETTE.Error

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
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(16, 23, 20)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

local backdropGradient = Instance.new("UIGradient")
backdropGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(81, 111, 100)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(58, 82, 95)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(132, 96, 108)),
})
backdropGradient.Rotation = 35
backdropGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.68),
    NumberSequenceKeypoint.new(1, 0.82),
})
backdropGradient.Parent = backdrop

local statsPanel = Instance.new("Frame")
statsPanel.Name = "StatsPanel"
statsPanel.Position = UDim2.fromOffset(14, 12)
statsPanel.Size = UDim2.fromOffset(330, 240)
statsPanel.BackgroundColor3 = UI_PALETTE.StatsPanel
statsPanel.BorderSizePixel = 0
statsPanel.BackgroundTransparency = 0.08
statsPanel.ZIndex = 2
statsPanel.Parent = screenGui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 10)
statsCorner.Parent = statsPanel

local statsStroke = Instance.new("UIStroke")
statsStroke.Color = UI_PALETTE.AccentMint
statsStroke.Transparency = 0.55
statsStroke.Thickness = 1.6
statsStroke.Parent = statsPanel

local statsGradient = Instance.new("UIGradient")
statsGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, UI_PALETTE.StatsPanel),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 52, 47)),
})
statsGradient.Rotation = 90
statsGradient.Parent = statsPanel

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
    label.BackgroundColor3 = UI_PALETTE.StatsCard
    label.BorderSizePixel = 0
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = UI_PALETTE.TextLight
    label.TextScaled = true
    label.Text = text
    label.ZIndex = 3
    label.Parent = statsPanel

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = label

    local stroke = Instance.new("UIStroke")
    stroke.Color = UI_PALETTE.AccentHoney
    stroke.Transparency = 0.75
    stroke.Thickness = 1.1
    stroke.Parent = label

    return label
end

local titleLabel = makeInfoLabel("Bee Forest Tycoon", 34)
titleLabel.BackgroundColor3 = Color3.fromRGB(78, 112, 95)
titleLabel.TextColor3 = UI_PALETTE.AccentHoney
titleLabel.Font = Enum.Font.FredokaOne

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
feedbackLabel.TextColor3 = UI_PALETTE.AccentHoney
feedbackLabel.TextXAlignment = Enum.TextXAlignment.Left
feedbackLabel.TextScaled = true
feedbackLabel.Text = ""
feedbackLabel.ZIndex = 3
feedbackLabel.Parent = screenGui

local actionsPanel = Instance.new("Frame")
actionsPanel.Name = "ActionsPanel"
actionsPanel.AnchorPoint = Vector2.new(1, 0)
actionsPanel.Position = UDim2.new(1, -14, 0, 12)
actionsPanel.Size = UDim2.fromOffset(310, 462)
actionsPanel.BackgroundColor3 = UI_PALETTE.ActionsPanel
actionsPanel.BackgroundTransparency = 0.06
actionsPanel.BorderSizePixel = 0
actionsPanel.ZIndex = 2
actionsPanel.Parent = screenGui

local actionsCorner = Instance.new("UICorner")
actionsCorner.CornerRadius = UDim.new(0, 10)
actionsCorner.Parent = actionsPanel

local actionsStroke = Instance.new("UIStroke")
actionsStroke.Color = UI_PALETTE.AccentRose
actionsStroke.Transparency = 0.58
actionsStroke.Thickness = 1.6
actionsStroke.Parent = actionsPanel

local actionsGradient = Instance.new("UIGradient")
actionsGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, UI_PALETTE.ActionsPanel),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 49, 66)),
})
actionsGradient.Rotation = 90
actionsGradient.Parent = actionsPanel

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
    button.BackgroundColor3 = UI_PALETTE.AccentGold
    button.TextColor3 = UI_PALETTE.TextDark
    button.Font = Enum.Font.GothamBold
    button.TextScaled = true
    button.Text = text
    button.AutoButtonColor = true
    button.ZIndex = 3
    button.Parent = actionsPanel

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(126, 102, 59)
    stroke.Transparency = 0.68
    stroke.Thickness = 1.1
    stroke.Parent = button

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 229, 161)),
        ColorSequenceKeypoint.new(1, UI_PALETTE.AccentGold),
    })
    gradient.Rotation = 90
    gradient.Parent = button

    return button
end

local actionsTitle = Instance.new("TextLabel")
actionsTitle.Size = UDim2.new(1, 0, 0, 32)
actionsTitle.BackgroundColor3 = UI_PALETTE.ActionsTitle
actionsTitle.TextColor3 = UI_PALETTE.AccentHoney
actionsTitle.BorderSizePixel = 0
actionsTitle.Font = Enum.Font.FredokaOne
actionsTitle.TextScaled = true
actionsTitle.Text = "Actions & Upgrades"
actionsTitle.ZIndex = 3
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
    feedbackLabel.TextColor3 = color or UI_PALETTE.AccentHoney
end

local function showCoinPopup(amount)
    local popup = Instance.new("TextLabel")
    popup.AnchorPoint = Vector2.new(0.5, 1)
    popup.Position = UDim2.fromScale(0.5, 0.84)
    popup.Size = UDim2.fromOffset(240, 54)
    popup.BackgroundTransparency = 1
    popup.Font = Enum.Font.FredokaOne
    popup.TextScaled = true
    popup.TextStrokeTransparency = 0.45
    popup.TextColor3 = UI_PALETTE.AccentHoney
    popup.Text = string.format("+%s Coins", formatNumber(amount))
    popup.ZIndex = 4
    popup.Parent = screenGui

    local travelTween = TweenService:Create(
        popup,
        TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
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

local function playIntro()
    local statsTarget = statsPanel.Position
    local actionsTarget = actionsPanel.Position
    local feedbackTarget = feedbackLabel.Position

    statsPanel.Position = statsTarget + UDim2.fromOffset(-36, 0)
    actionsPanel.Position = actionsTarget + UDim2.fromOffset(42, 0)
    feedbackLabel.Position = feedbackTarget + UDim2.fromOffset(0, 16)

    statsPanel.BackgroundTransparency = 0.55
    actionsPanel.BackgroundTransparency = 0.55
    feedbackLabel.TextTransparency = 1

    TweenService:Create(
        statsPanel,
        TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Position = statsTarget, BackgroundTransparency = 0.08 }
    ):Play()

    TweenService:Create(
        actionsPanel,
        TweenInfo.new(0.62, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Position = actionsTarget, BackgroundTransparency = 0.06 }
    ):Play()

    TweenService:Create(
        feedbackLabel,
        TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = feedbackTarget, TextTransparency = 0 }
    ):Play()
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
        setFeedback("You do not own that bee yet.", ERROR_COLOR)
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
    setFeedback("Server remotes mangler. Rejoin eller check server errors.", ERROR_COLOR)
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
            setFeedback(string.format("Collected +%s Coins", formatNumber(amount)), SUCCESS_COLOR)
            if amount > 0 then
                showCoinPopup(amount)
            end
        else
            setFeedback("Could not collect that flower.", ERROR_COLOR)
        end
    elseif payload.action == "BuyUpgrade" then
        if payload.success then
            setFeedback("Upgrade purchased.", SUCCESS_COLOR)
        else
            setFeedback("Upgrade failed: not enough coins or max level.", ERROR_COLOR)
        end
    elseif payload.action == "EquipBee" then
        if payload.success then
            setFeedback("Bee loadout updated.", SUCCESS_COLOR)
        else
            setFeedback("Could not equip bee.", ERROR_COLOR)
        end
    elseif payload.action == "UnlockZone" then
        if payload.success then
            setFeedback("Zone unlocked.", SUCCESS_COLOR)
        else
            setFeedback("Zone unlock failed.", ERROR_COLOR)
        end
    end

    updateInfoLabels()
    updateUpgradeButtons()
end)

playIntro()
updateInfoLabels()
updateUpgradeButtons()
